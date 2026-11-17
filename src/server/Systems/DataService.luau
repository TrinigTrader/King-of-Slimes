--!strict
-- Player profiles: load with a session lock, autosave, save on leave and on
-- shutdown, schema migrations, and state replication to the owning client.
--
-- Session lock: the saved record holds { lock = { jobId, time } }. A server
-- only loads a profile when no other live server holds the lock (or the lock
-- is older than SESSION_LOCK_TIMEOUT), and only writes while it holds it.
-- This prevents two servers overwriting each other's progress.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Game = require(Shared.Config.Game)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)

local Modules = script.Parent.Parent.Modules
local Stats = require(Modules.Stats)
local PlayerState = require(Modules.PlayerState)
local RateLimit = require(Modules.RateLimit)

type Lock = { jobId: string, time: number }
type Record = { data: Types.Profile?, lock: Lock? }

local DataService = {}

DataService.ProfileLoaded = Signal.new() -- (player, profile)
DataService.ProfileReleasing = Signal.new() -- (player, profile)

local profiles: { [Player]: Types.Profile } = {}
local dirty: { [Player]: boolean } = {}
local saving: { [Player]: boolean } = {}
local temporary = false -- true when DataStores are unavailable (Studio without API access)

local store: DataStore? = nil
local stateRemote: RemoteEvent
local notifyRemote: RemoteEvent

local MAX_ATTEMPTS = 6

local function jobId(): string
	return if game.JobId ~= "" then game.JobId else "studio"
end

local function newProfile(): Types.Profile
	return {
		version = Game.PROFILE_VERSION,
		coins = 0,
		gems = 0,
		upgrades = { Backpack = 1, Shoes = 1, Pen = 1, Incubators = 1 },
		slimes = {
			["1"] = { species = "Pudding", level = 1, xp = 0, shiny = false },
		},
		partnerUid = "1",
		nextUid = 2,
		backpackCount = 0,
		backpackValue = 0,
		incubating = {},
		stats = { orbsCollected = 0, eggsHatched = 0, timesCaught = 0 },
		lastOnline = os.time(),
	}
end

-- Bring an older or partial profile up to the current shape. Never removes
-- data; fills missing fields from the template.
local function migrate(data: any): Types.Profile
	local template = newProfile()
	if typeof(data) ~= "table" then
		return template
	end
	for key, value in template :: any do
		if data[key] == nil then
			data[key] = value
		end
	end
	for key, value in template.upgrades do
		if typeof(data.upgrades[key]) ~= "number" then
			data.upgrades[key] = value
		end
	end
	for key, value in template.stats :: any do
		if typeof(data.stats[key]) ~= "number" then
			data.stats[key] = value
		end
	end
	-- version 1 is the first schema; future steps go here:
	-- if data.version < 2 then ... data.version = 2 end
	data.version = Game.PROFILE_VERSION
	return data :: Types.Profile
end

local function isStudioAccessError(message: string): boolean
	return string.find(message, "StudioAccessToApisNotAllowed", 1, true) ~= nil
		or string.find(message, "403", 1, true) ~= nil
end

local function key(player: Player): string
	return `player_{player.UserId}`
end

-- Returns (profile, errorMessage).
local function loadFromStore(player: Player): (Types.Profile?, string?)
	local dataStore = store
	if not dataStore then
		return nil, "no datastore"
	end
	local lastError: string? = nil
	for attempt = 1, MAX_ATTEMPTS do
		local lockedElsewhere = false
		local loaded: Types.Profile? = nil
		local ok, err = pcall(function()
			dataStore:UpdateAsync(key(player), function(old: Record?): Record?
				local record: Record = old or {}
				local lock = record.lock
				local stale = lock == nil or os.time() - lock.time > Game.SESSION_LOCK_TIMEOUT
				-- On the last attempt, take over a lock that a crashed server left.
				if lock and lock.jobId ~= jobId() and not stale and attempt < MAX_ATTEMPTS then
					lockedElsewhere = true
					return nil -- cancel the write
				end
				record.data = migrate(record.data)
				record.lock = { jobId = jobId(), time = os.time() }
				loaded = record.data
				return record
			end)
		end)
		if ok and loaded then
			return loaded, nil
		end
		if not ok then
			lastError = tostring(err)
			if isStudioAccessError(lastError :: string) then
				return nil, lastError
			end
		end
		if not player.Parent then
			return nil, "player left"
		end
		task.wait(if lockedElsewhere then 5 else 2 ^ attempt)
	end
	return nil, lastError or "session locked"
end

-- Writes the profile if this server still holds the lock.
local function saveToStore(player: Player, profile: Types.Profile, release: boolean): boolean
	local dataStore = store
	if temporary or not dataStore then
		return true
	end
	profile.lastOnline = os.time()
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			dataStore:UpdateAsync(key(player), function(old: Record?): Record?
				local record: Record = old or {}
				if record.lock and record.lock.jobId ~= jobId() then
					warn(`[DataService] {player.Name}: lock owned by another server, not saving`)
					return nil
				end
				record.data = profile
				record.lock = if release then nil else { jobId = jobId(), time = os.time() }
				return record
			end)
		end)
		if ok then
			return true
		end
		warn(`[DataService] save failed for {player.Name} (attempt {attempt}): {err}`)
		task.wait(2 ^ attempt)
	end
	return false
end

local function buildSnapshot(player: Player, profile: Types.Profile): Types.Snapshot
	local state = PlayerState.get(player)
	return {
		coins = profile.coins,
		gems = profile.gems,
		backpackCount = profile.backpackCount,
		backpackValue = profile.backpackValue,
		backpackCapacity = Stats.backpackCapacity(profile),
		walkSpeed = Stats.walkSpeed(profile),
		upgrades = profile.upgrades,
		slimes = profile.slimes,
		partnerUid = profile.partnerUid,
		incubating = profile.incubating,
		incubatorCapacity = Stats.incubatorCapacity(profile),
		penCapacity = Stats.penCapacity(profile),
		carryingEgg = state.carryingEgg,
		pvpShieldUntil = 0,
		serverTime = os.time(),
	}
end

function DataService.getProfile(player: Player): Types.Profile?
	return profiles[player]
end

function DataService.allProfiles(): { [Player]: Types.Profile }
	return profiles
end

-- Call after changing a profile (or PlayerState) so the client gets the new state.
function DataService.changed(player: Player)
	if profiles[player] then
		dirty[player] = true
	end
end

function DataService.notify(player: Player, message: string)
	notifyRemote:FireClient(player, message)
end

function DataService.isTemporary(): boolean
	return temporary
end

local function onPlayerAdded(player: Player)
	local profile: Types.Profile? = nil
	if store and not temporary then
		local loaded, err = loadFromStore(player)
		if loaded then
			profile = loaded
		elseif err and isStudioAccessError(err) then
			temporary = true
			warn(
				"[DataService] DataStores unavailable (enable Studio API access in Game Settings > Security). Progress will NOT save."
			)
		elseif player.Parent then
			if RunService:IsStudio() then
				temporary = true
				warn(`[DataService] load failed in Studio ({err}); using a temporary profile`)
			else
				player:Kick("We couldn't load your data. Please rejoin in a moment.")
				return
			end
		end
	end
	if not player.Parent then
		return
	end
	if not profile then
		profile = newProfile()
	end
	local loadedProfile = profile :: Types.Profile
	profiles[player] = loadedProfile
	if temporary then
		DataService.notify(player, "Studio test mode: progress will not save.")
	end
	DataService.ProfileLoaded:Fire(player, loadedProfile)
	DataService.changed(player)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		DataService.ProfileReleasing:Fire(player, profile)
		saving[player] = true
		saveToStore(player, profile, true)
		saving[player] = nil
		profiles[player] = nil
		dirty[player] = nil
	end
	PlayerState.clear(player)
	RateLimit.clear(player)
end

function DataService.init()
	stateRemote = Remotes.get("StateChanged")
	notifyRemote = Remotes.get("Notify")
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Game.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		temporary = true
		warn(`[DataService] GetDataStore failed: {result}`)
	end
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Replicate changed state at most 10 times a second.
	task.spawn(function()
		while true do
			task.wait(0.1)
			for player in dirty do
				dirty[player] = nil
				local profile = profiles[player]
				if profile and player.Parent then
					stateRemote:FireClient(player, buildSnapshot(player, profile))
				end
			end
		end
	end)

	-- Autosave.
	task.spawn(function()
		while true do
			task.wait(Game.AUTOSAVE_INTERVAL)
			for player, profile in profiles do
				if not saving[player] then
					task.spawn(saveToStore, player, profile, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			if not saving[player] then
				pending += 1
				task.spawn(function()
					saveToStore(player, profile, true)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService

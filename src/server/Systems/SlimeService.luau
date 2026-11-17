--!strict
-- Owned slimes: the partner that follows you, the rest wandering in your pen,
-- feeding, levelling, releasing, and passive Coin income from your pen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)
local Game = require(Shared.Config.Game)
local Slimes = require(Shared.Config.Slimes)
local Rarities = require(Shared.Config.Rarities)

local Modules = script.Parent.Parent.Modules
local World = require(Modules.World)
local Stats = require(Modules.Stats)
local PlayerState = require(Modules.PlayerState)
local RateLimit = require(Modules.RateLimit)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

type Visual = {
	part: BasePart,
	uid: string,
	target: Vector3,
	nextWander: number,
}

local SlimeService = {}

local visuals: { [Player]: { [string]: Visual } } = {}
local folder: Folder
local rng = Random.new()

local function slimeLabel(slime: Types.SlimeData): string
	local def = Slimes[slime.species]
	local name = if def then def.name else slime.species
	return `{if slime.shiny then "Shiny " else ""}{name}  Lv {slime.level}`
end

local function makeVisual(
	player: Player,
	uid: string,
	slime: Types.SlimeData,
	position: Vector3
): Visual
	local def = Slimes[slime.species]
	local size = Formulas.slimeSize(slime.level)
	local part = Instance.new("Part")
	part.Name = `{player.Name}_{uid}`
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size * 0.8, size)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = if slime.shiny then Enum.Material.Neon else Enum.Material.Glass
	part.Transparency = if slime.shiny then 0 else 0.25
	part.Color = if def then def.color else Color3.new(1, 1, 1)
	part.Position = position

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 28)
	gui.StudsOffset = Vector3.new(0, size * 0.5 + 1, 0)
	gui.MaxDistance = 60
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.TextStrokeTransparency = 0.4
	text.TextColor3 = if def then Rarities[def.rarity].color else Color3.new(1, 1, 1)
	text.Text = slimeLabel(slime)
	text.Parent = gui
	gui.Parent = part

	part.Parent = folder
	return { part = part, uid = uid, target = position, nextWander = 0 }
end

-- Rebuild the player's slime visuals to match their profile.
local function refreshVisuals(player: Player)
	local profile = DataService.getProfile(player)
	local plot = PlotService.getPlot(player)
	local current: { [string]: Visual } = visuals[player] or {}
	visuals[player] = current
	if not profile or not plot then
		return
	end
	local keepPositions: { [string]: Vector3 } = {}
	for uid, visual in current do
		local slime = profile.slimes[uid]
		local wantedSize = slime and Formulas.slimeSize(slime.level)
		if not slime or math.abs(visual.part.Size.X - (wantedSize :: number)) > 0.01 then
			keepPositions[uid] = visual.part.Position
			visual.part:Destroy()
			current[uid] = nil
		else
			local label = visual.part:FindFirstChildWhichIsA("BillboardGui")
			local text = label and label:FindFirstChildWhichIsA("TextLabel")
			if text then
				text.Text = slimeLabel(slime)
			end
		end
	end
	for uid, slime in profile.slimes do
		if not current[uid] then
			current[uid] = makeVisual(player, uid, slime, keepPositions[uid] or plot.penCenter)
		end
	end
end

local function clearVisuals(player: Player)
	local current = visuals[player]
	if current then
		for _, visual in current do
			visual.part:Destroy()
		end
	end
	visuals[player] = nil
end

-- Adds a slime to the player's collection. Returns its uid, or nil if the pen is full.
function SlimeService.grant(player: Player, species: string, shiny: boolean): string?
	local profile = DataService.getProfile(player)
	if not profile or not Slimes[species] then
		return nil
	end
	if Stats.slimeCount(profile) >= Stats.penCapacity(profile) then
		return nil
	end
	local uid = tostring(profile.nextUid)
	profile.nextUid += 1
	profile.slimes[uid] = { species = species, level = 1, xp = 0, shiny = shiny }
	if not profile.partnerUid then
		profile.partnerUid = uid
	end
	DataService.changed(player)
	refreshVisuals(player)
	return uid
end

local function feed(player: Player)
	local profile = DataService.getProfile(player)
	local plot = PlotService.getPlot(player)
	if not profile or not plot then
		return
	end
	local uid = profile.partnerUid
	local slime = uid and profile.slimes[uid]
	if not slime then
		DataService.notify(player, "Pick a partner slime first (Slimes menu).")
		return
	end
	if profile.backpackCount <= 0 then
		DataService.notify(player, "Your backpack is empty. Collect orbs to feed your slime!")
		return
	end
	local xp = Formulas.feedXp(profile.backpackValue, Game.FEED_XP_PER_VALUE)
	local level, leftover, gained = Formulas.addXp(slime.level, slime.xp, xp, Game.MAX_SLIME_LEVEL)
	local oldStage = Formulas.stage(slime.level)
	slime.level = level
	slime.xp = leftover
	profile.backpackCount = 0
	profile.backpackValue = 0
	DataService.changed(player)
	refreshVisuals(player)

	local def = Slimes[slime.species]
	if gained > 0 then
		local newStage = Formulas.stage(level)
		local stageText = if newStage ~= oldStage then ` It grew into a {newStage}!` else ""
		DataService.notify(player, `{def.name} reached level {level}!{stageText}`)
	else
		DataService.notify(player, `{def.name} gained {xp} XP.`)
	end
end

local function setPartner(player: Player, uid: unknown)
	if not RateLimit.allow(player, "SetPartner", 0.5) or typeof(uid) ~= "string" then
		return
	end
	local profile = DataService.getProfile(player)
	if not profile or not profile.slimes[uid] then
		return
	end
	profile.partnerUid = uid
	DataService.changed(player)
	refreshVisuals(player)
end

local function release(player: Player, uid: unknown)
	if not RateLimit.allow(player, "ReleaseSlime", 0.5) or typeof(uid) ~= "string" then
		return
	end
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	local slime = profile.slimes[uid]
	if not slime then
		return
	end
	if Stats.slimeCount(profile) <= 1 then
		DataService.notify(player, "You can't release your last slime.")
		return
	end
	local def = Slimes[slime.species]
	local coins = Rarities[def.rarity].releaseValue * slime.level
	profile.slimes[uid] = nil
	if profile.partnerUid == uid then
		profile.partnerUid = next(profile.slimes)
	end
	profile.coins += coins
	DataService.changed(player)
	refreshVisuals(player)
	DataService.notify(player, `Released {def.name} for {coins} Coins.`)
end

local function payIncome()
	for player, profile in DataService.allProfiles() do
		local total = 0
		for uid, slime in profile.slimes do
			if uid ~= profile.partnerUid then
				local def = Slimes[slime.species]
				if def then
					total += Formulas.passiveIncome(Rarities[def.rarity].incomePerTick, slime.level)
				end
			end
		end
		if total > 0 then
			profile.coins += total
			DataService.changed(player)
		end
	end
end

-- Moves partner slimes behind their owners and pen slimes around the pen.
local function step(dt: number)
	local now = os.clock()
	for player, byUid in visuals do
		local profile = DataService.getProfile(player)
		local plot = PlotService.getPlot(player)
		if not profile or not plot then
			continue
		end
		local root = PlayerState.rootPart(player)
		for uid, visual in byUid do
			local height = visual.part.Size.Y / 2 + 1
			local target: Vector3
			local speed: number
			if uid == profile.partnerUid and root then
				local behind = root.CFrame * CFrame.new(2.5, 0, 4)
				target = Vector3.new(behind.X, root.Position.Y - 3 + height, behind.Z)
				speed = 60
			else
				if now >= visual.nextWander then
					visual.nextWander = now + rng:NextNumber(2, 5)
					local spread = 11
					visual.target = plot.penCenter
						+ Vector3.new(
							rng:NextNumber(-spread, spread),
							0,
							rng:NextNumber(-spread, spread)
						)
				end
				target = Vector3.new(visual.target.X, plot.penCenter.Y + height, visual.target.Z)
				speed = 6
			end
			local position = visual.part.Position
			local delta = target - position
			local distance = delta.Magnitude
			if distance > 80 then
				visual.part.Position = target -- teleport if far (e.g. owner respawned)
			elseif distance > 0.05 then
				local move = math.min(distance, speed * dt * math.max(1, distance / 6))
				local bounce = math.abs(math.sin(now * 6 + #uid)) * 0.4
				visual.part.Position = position
					+ delta.Unit * move
					+ Vector3.new(0, bounce * dt * 4, 0)
			end
		end
	end
end

function SlimeService.init()
	folder = Instance.new("Folder")
	folder.Name = "Slimes"
	folder.Parent = World.get().effects

	for _, plot in World.get().plots do
		plot.feedPrompt.Triggered:Connect(function(player)
			if PlotService.ownsPlot(player, plot) then
				feed(player)
			else
				DataService.notify(player, "This isn't your plot.")
			end
		end)
	end

	Remotes.get("SetPartner").OnServerEvent:Connect(setPartner)
	Remotes.get("ReleaseSlime").OnServerEvent:Connect(release)

	DataService.ProfileLoaded:Connect(function(player: Player)
		task.defer(refreshVisuals, player)
	end)
	DataService.ProfileReleasing:Connect(clearVisuals)
end

function SlimeService.start()
	Players.PlayerRemoving:Connect(clearVisuals)
	RunService.Heartbeat:Connect(step)
	task.spawn(function()
		while true do
			task.wait(Game.PASSIVE_INCOME_INTERVAL)
			payIncome()
		end
	end)
end

return SlimeService

--!strict
-- Spawns floating orbs in each zone and collects them for nearby players.
-- Pickup is decided on the server from character positions, so there is no
-- client "I collected this" remote to exploit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Layout)
local Game = require(Shared.Config.Game)
local Zones = require(Shared.Config.Zones)

local Modules = script.Parent.Parent.Modules
local World = require(Modules.World)
local Stats = require(Modules.Stats)
local PlayerState = require(Modules.PlayerState)

local DataService = require(script.Parent.DataService)

type Orb = {
	part: BasePart,
	zone: number,
	slots: number,
	value: number,
	dropped: boolean,
	expiresAt: number,
}

local OrbService = {}

local orbs: { Orb } = {}
local naturalCount: { [number]: number } = {}
local folder: Folder
local rng = Random.new()
local fullWarned: { [Player]: number } = {}

local ORB_HEIGHT = 2.5

local function makePart(position: Vector3, color: Color3, size: number): BasePart
	local part = Instance.new("Part")
	part.Name = "Orb"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Position = position
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 6
	light.Brightness = 1
	light.Parent = part
	part.Parent = folder
	return part
end

local function spawnNatural(zoneIndex: number)
	local zone = Zones[zoneIndex]
	local point = Layout.randomZonePoint(zoneIndex, rng, 6)
	table.insert(orbs, {
		part = makePart(point + Vector3.new(0, ORB_HEIGHT, 0), zone.orbColor, 1.2),
		zone = zoneIndex,
		slots = 1,
		value = zone.orbValue,
		dropped = false,
		expiresAt = math.huge,
	})
	naturalCount[zoneIndex] = (naturalCount[zoneIndex] or 0) + 1
end

local function removeAt(index: number)
	local orb = orbs[index]
	orb.part:Destroy()
	if not orb.dropped then
		naturalCount[orb.zone] -= 1
	end
	-- swap-remove: order does not matter
	orbs[index] = orbs[#orbs]
	orbs[#orbs] = nil
end

-- Drops `slots` orbs worth `value` in total around a position (used when a
-- monster catches a player). Anyone can pick them up.
function OrbService.drop(zoneIndex: number, position: Vector3, slots: number, value: number)
	if slots <= 0 then
		return
	end
	local zone = Zones[zoneIndex]
	local pieces = math.min(slots, 8)
	local slotsLeft, valueLeft = slots, value
	for piece = 1, pieces do
		local remainingPieces = pieces - piece + 1
		local pieceSlots = math.ceil(slotsLeft / remainingPieces)
		local pieceValue = math.floor(valueLeft / remainingPieces)
		slotsLeft -= pieceSlots
		valueLeft -= pieceValue
		local offset = Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
		local point = Layout.clampToZone(zoneIndex, position + offset, 4)
		table.insert(orbs, {
			part = makePart(
				Vector3.new(point.X, ORB_HEIGHT, point.Z),
				zone.orbColor:Lerp(Color3.new(1, 1, 1), 0.4),
				1.6
			),
			zone = zoneIndex,
			slots = pieceSlots,
			value = pieceValue,
			dropped = true,
			expiresAt = os.clock() + Game.DROPPED_ORB_LIFETIME,
		})
	end
end

local function collectFor(player: Player)
	local profile = DataService.getProfile(player)
	local root = PlayerState.rootPart(player)
	if not profile or not root then
		return
	end
	local zoneIndex = Layout.zoneAt(root.Position, #Zones)
	if not zoneIndex then
		return
	end
	local capacity = Stats.backpackCapacity(profile)
	local radius = Stats.pickupRadius(profile)
	local position = root.Position
	local collected = false
	local blockedByFull = false

	local index = #orbs
	while index >= 1 do
		local orb = orbs[index]
		if orb.zone == zoneIndex and (orb.part.Position - position).Magnitude <= radius then
			if profile.backpackCount + orb.slots <= capacity then
				profile.backpackCount += orb.slots
				profile.backpackValue += orb.value
				profile.stats.orbsCollected += orb.slots
				removeAt(index)
				collected = true
			else
				blockedByFull = true
			end
		end
		index -= 1
	end

	if collected then
		DataService.changed(player)
	end
	if blockedByFull and os.clock() - (fullWarned[player] or 0) > 5 then
		fullWarned[player] = os.clock()
		DataService.notify(player, "Backpack full! Head home to sell or feed your slime.")
	end
end

function OrbService.init()
	folder = Instance.new("Folder")
	folder.Name = "Orbs"
	folder.Parent = World.get().effects
	for zoneIndex = 1, #Zones do
		naturalCount[zoneIndex] = 0
	end
end

function OrbService.start()
	Players.PlayerRemoving:Connect(function(player)
		fullWarned[player] = nil
	end)

	-- Fill zones at start, then top up over time.
	for zoneIndex, zone in Zones do
		for _ = 1, zone.maxOrbs do
			spawnNatural(zoneIndex)
		end
	end

	task.spawn(function()
		while true do
			task.wait(1)
			for zoneIndex, zone in Zones do
				-- Respawn a few per second so a cleared zone refills in ~10s.
				for _ = 1, 4 do
					if naturalCount[zoneIndex] < zone.maxOrbs then
						spawnNatural(zoneIndex)
					end
				end
			end
			local now = os.clock()
			local index = #orbs
			while index >= 1 do
				if orbs[index].expiresAt < now then
					removeAt(index)
				end
				index -= 1
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.1)
			for player in DataService.allProfiles() do
				collectFor(player)
			end
		end
	end)
end

return OrbService

--!strict
-- One monster per zone. It chases the nearest player outside the safe gate.
-- It can't be killed, only escaped: reach the zone's recommended speed.
-- Getting caught drops 30% of your backpack and any carried egg, and sends
-- you back to the zone gate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Layout = require(Shared.Layout)
local Game = require(Shared.Config.Game)
local Zones = require(Shared.Config.Zones)

local Modules = script.Parent.Parent.Modules
local World = require(Modules.World)
local Stats = require(Modules.Stats)
local PlayerState = require(Modules.PlayerState)

local DataService = require(script.Parent.DataService)
local OrbService = require(script.Parent.OrbService)
local EggService = require(script.Parent.EggService)

type Monster = {
	zone: number,
	body: BasePart,
	target: Player?,
	wanderPoint: Vector3,
	nextWander: number,
}

local MonsterService = {}

local monsters: { Monster } = {}
local rng = Random.new()

local BODY_SIZE = 7
local WANDER_SPEED_FACTOR = 0.4
local LOSE_INTEREST_DISTANCE = 120

local function buildMonster(zoneIndex: number, parent: Instance): Monster
	local zone = Zones[zoneIndex]
	local body = Instance.new("Part")
	body.Name = zone.monsterName
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.one * BODY_SIZE
	body.Color = zone.monsterColor
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false

	-- Two glowing eyes so it reads as a creature.
	for _, side in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * 1.3
		eye.Color = Color3.fromRGB(255, 40, 40)
		eye.Material = Enum.Material.Neon
		eye.Anchored = false
		eye.Massless = true
		eye.CanCollide = false
		eye.CFrame = body.CFrame * CFrame.new(side * 1.5, 1, -BODY_SIZE / 2 + 0.4)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
		eye.Parent = body
	end

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, BODY_SIZE / 2 + 2, 0)
	gui.MaxDistance = 120
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.TextColor3 = Color3.fromRGB(255, 90, 90)
	text.TextStrokeTransparency = 0.2
	text.Text = `{zone.monsterName} (speed {zone.monsterSpeed})`
	text.Parent = gui
	gui.Parent = body

	local start = Layout.zoneCenter(zoneIndex)
	body.CFrame = CFrame.new(start + Vector3.new(0, BODY_SIZE / 2, 0))
	body.Parent = parent

	return { zone = zoneIndex, body = body, target = nil, wanderPoint = start, nextWander = 0 }
end

local function catch(monster: Monster, player: Player)
	local profile = DataService.getProfile(player)
	local root = PlayerState.rootPart(player)
	if not profile or not root then
		return
	end
	local state = PlayerState.get(player)
	state.graceUntil = os.clock() + Game.CATCH_GRACE_SECONDS

	local dropCount, dropValue =
		Formulas.catchDrop(profile.backpackCount, profile.backpackValue, Game.CATCH_DROP_FRACTION)
	profile.backpackCount -= dropCount
	profile.backpackValue -= dropValue
	profile.stats.timesCaught += 1
	OrbService.drop(monster.zone, root.Position, dropCount, dropValue)
	local lostEgg = EggService.dropCarried(player)

	PlayerState.teleport(player, Layout.zoneGate(monster.zone))
	DataService.changed(player)

	local zone = Zones[monster.zone]
	local message = `The {zone.monsterName} caught you! You dropped {dropCount} orbs`
	if lostEgg then
		message ..= " and your egg"
	end
	DataService.notify(player, `{message}. Try reaching speed {zone.recommendedSpeed}.`)
	monster.target = nil
end

-- Picks the closest valid player in this monster's zone.
local function findTarget(monster: Monster): (Player?, BasePart?)
	local bestPlayer: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = math.huge
	local now = os.clock()
	for player in DataService.allProfiles() do
		local root = PlayerState.rootPart(player)
		if not root or PlayerState.get(player).graceUntil > now then
			continue
		end
		local zoneIndex, safe = Layout.zoneAt(root.Position, #Zones)
		if zoneIndex ~= monster.zone or safe then
			continue
		end
		local distance = (root.Position - monster.body.Position).Magnitude
		if distance < bestDistance and distance < LOSE_INTEREST_DISTANCE then
			bestPlayer, bestRoot, bestDistance = player, root, distance
		end
	end
	return bestPlayer, bestRoot
end

local function stepMonster(monster: Monster, dt: number)
	local zone = Zones[monster.zone]
	local position = monster.body.Position
	local player, root = findTarget(monster)
	monster.target = player

	local goal: Vector3
	local speed: number
	if player and root then
		goal = root.Position
		local profile = DataService.getProfile(player)
		local slow = if profile then Stats.monsterSlow(profile) else 0
		speed = zone.monsterSpeed * (1 - slow)
	else
		local now = os.clock()
		if now >= monster.nextWander then
			monster.nextWander = now + rng:NextNumber(3, 6)
			monster.wanderPoint = Layout.randomZonePoint(monster.zone, rng, 10)
		end
		goal = monster.wanderPoint
		speed = zone.monsterSpeed * WANDER_SPEED_FACTOR
	end

	local flat = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z)
	local distance = flat.Magnitude
	local nextPosition = position
	if distance > 0.1 then
		nextPosition = position + flat.Unit * math.min(distance, speed * dt)
	end
	nextPosition = Layout.clampToZone(monster.zone, nextPosition, BODY_SIZE / 2)
	local bob = math.abs(math.sin(os.clock() * 8)) * 0.6
	nextPosition = Vector3.new(nextPosition.X, BODY_SIZE / 2 + bob, nextPosition.Z)
	local facing = if distance > 0.1 then flat.Unit else monster.body.CFrame.LookVector
	monster.body.CFrame = CFrame.lookAt(nextPosition, nextPosition + facing)

	if player and root then
		local gap =
			Vector3.new(root.Position.X - nextPosition.X, 0, root.Position.Z - nextPosition.Z)
		if gap.Magnitude <= Game.MONSTER_CATCH_RADIUS + BODY_SIZE / 2 - 1 then
			catch(monster, player)
		end
	end
end

function MonsterService.init()
	local folder = Instance.new("Folder")
	folder.Name = "Monsters"
	folder.Parent = World.get().effects
	for zoneIndex = 1, #Zones do
		table.insert(monsters, buildMonster(zoneIndex, folder))
	end
end

function MonsterService.start()
	RunService.Heartbeat:Connect(function(dt)
		for _, monster in monsters do
			stepMonster(monster, dt)
		end
	end)
end

return MonsterService

--!strict
-- Wild eggs spawn in each zone (rarer eggs further out). Players carry one
-- egg home (the monster can make them drop it), place it in their incubator,
-- and hatch it once the timer is done.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Layout = require(Shared.Layout)
local Game = require(Shared.Config.Game)
local Zones = require(Shared.Config.Zones)
local Eggs = require(Shared.Config.Eggs)
local Slimes = require(Shared.Config.Slimes)

local Modules = script.Parent.Parent.Modules
local World = require(Modules.World)
local Stats = require(Modules.Stats)
local PlayerState = require(Modules.PlayerState)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local SlimeService = require(script.Parent.SlimeService)

local EggService = {}

local folder: Folder
local rng = Random.new()
local carriedVisuals: { [Player]: BasePart } = {}

local function eggPart(eggId: string): Part
	local def = Eggs[eggId]
	local part = Instance.new("Part")
	part.Name = def.name
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(2.4, 3.2, 2.4)
	part.Color = def.color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = true
	part.CanTouch = false
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = def.color
	sparkle.Parent = part
	return part
end

local function spawnWildEgg(zoneIndex: number)
	local zone = Zones[zoneIndex]
	local def = Eggs[zone.eggId]
	local part = eggPart(zone.eggId)
	part.Anchored = true
	part.Position = Layout.randomZonePoint(zoneIndex, rng, 15) + Vector3.new(0, 1.6, 0)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = def.name
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	local taken = false
	prompt.Triggered:Connect(function(player)
		if taken then
			return
		end
		local state = PlayerState.get(player)
		if state.carryingEgg then
			DataService.notify(player, "You're already carrying an egg. Take it home first!")
			return
		end
		taken = true
		part:Destroy()
		EggService.setCarrying(player, zone.eggId)
		DataService.notify(player, `Got a {def.name}! Bring it to your incubator.`)
		task.delay(Game.EGG_RESPAWN_SECONDS, spawnWildEgg, zoneIndex)
	end)

	part.Parent = folder
end

function EggService.setCarrying(player: Player, eggId: string?)
	PlayerState.get(player).carryingEgg = eggId
	local old = carriedVisuals[player]
	if old then
		old:Destroy()
		carriedVisuals[player] = nil
	end
	local root = PlayerState.rootPart(player)
	if eggId and root then
		local part = eggPart(eggId)
		part.Anchored = false
		part.Massless = true
		part.CanQuery = false
		part.Size = Vector3.new(1.6, 2.1, 1.6)
		part.CFrame = root.CFrame * CFrame.new(0, 3.5, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = root.Parent
		carriedVisuals[player] = part
	end
	DataService.changed(player)
end

-- Called when a monster catches the player. Returns true if an egg was lost.
function EggService.dropCarried(player: Player): boolean
	if PlayerState.get(player).carryingEgg then
		EggService.setCarrying(player, nil)
		return true
	end
	return false
end

local function hatch(player: Player, eggId: string): boolean
	local def = Eggs[eggId]
	if not def then
		return true -- unknown egg (removed from config); discard it
	end
	local species = Formulas.weightedPick(def.odds, rng:NextNumber())
	local shiny = rng:NextNumber() < Game.SHINY_CHANCE
	local uid = SlimeService.grant(player, species, shiny)
	if not uid then
		return false
	end
	local slimeDef = Slimes[species]
	DataService.notify(
		player,
		`You hatched a {if shiny then "SHINY " else ""}{slimeDef.rarity} {slimeDef.name}!`
	)
	local profile = DataService.getProfile(player)
	if profile then
		profile.stats.eggsHatched += 1
	end
	return true
end

-- Incubator prompt: hatch any ready eggs, then place the carried egg.
local function useIncubator(player: Player)
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	local now = os.time()
	local hatchedAny = false
	local penFull = false
	local index = 1
	while index <= #profile.incubating do
		local slot = profile.incubating[index]
		if slot.readyAt <= now then
			if hatch(player, slot.eggId) then
				table.remove(profile.incubating, index)
				hatchedAny = true
				continue
			else
				penFull = true
			end
		end
		index += 1
	end
	if penFull then
		DataService.notify(player, "Your pen is full! Upgrade it in the shop or release a slime.")
	end

	local state = PlayerState.get(player)
	local carrying = state.carryingEgg
	if carrying then
		if #profile.incubating >= Stats.incubatorCapacity(profile) then
			DataService.notify(player, "All incubators are busy. Buy more in the shop!")
		else
			table.insert(
				profile.incubating,
				{ eggId = carrying, readyAt = now + Eggs[carrying].hatchSeconds }
			)
			EggService.setCarrying(player, nil)
			DataService.notify(player, `{Eggs[carrying].name} is incubating!`)
		end
	elseif not hatchedAny and not penFull then
		if #profile.incubating > 0 then
			DataService.notify(player, "Your egg isn't ready yet.")
		else
			DataService.notify(player, "Find a wild egg in a zone and bring it here.")
		end
	end
	DataService.changed(player)
end

local function formatTime(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Updates the countdown labels and pods on every owned plot.
local function updateIncubatorLabels()
	local now = os.time()
	for player, profile in DataService.allProfiles() do
		local plot = PlotService.getPlot(player)
		if not plot then
			continue
		end
		local capacity = Stats.incubatorCapacity(profile)
		for slotIndex, labelText in plot.incubatorLabels do
			local pod = plot.incubatorParts[slotIndex]
			local slot = profile.incubating[slotIndex]
			pod.Transparency = if slotIndex <= capacity then 0.4 else 0.9
			if slot then
				local remaining = slot.readyAt - now
				labelText.Text = if remaining <= 0 then "READY!" else formatTime(remaining)
				pod.Color = Eggs[slot.eggId] and Eggs[slot.eggId].color or pod.Color
			else
				labelText.Text = if slotIndex <= capacity then "Empty" else "Locked"
				pod.Color = Color3.fromRGB(180, 240, 255)
			end
		end
	end
end

local function clearPlotLabels(player: Player)
	local plot = PlotService.getPlot(player)
	if plot then
		for _, labelText in plot.incubatorLabels do
			labelText.Text = ""
		end
	end
end

function EggService.init()
	folder = Instance.new("Folder")
	folder.Name = "Eggs"
	folder.Parent = World.get().effects

	for _, plot in World.get().plots do
		plot.incubatorPrompt.Triggered:Connect(function(player)
			if PlotService.ownsPlot(player, plot) then
				useIncubator(player)
			else
				DataService.notify(player, "This isn't your plot.")
			end
		end)
	end
	DataService.ProfileReleasing:Connect(clearPlotLabels)
end

function EggService.start()
	for zoneIndex, zone in Zones do
		for _ = 1, zone.eggSpawns do
			spawnWildEgg(zoneIndex)
		end
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			-- Dying or respawning loses the carried egg.
			if PlayerState.get(player).carryingEgg then
				EggService.setCarrying(player, nil)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local part = carriedVisuals[player]
		if part then
			part:Destroy()
			carriedVisuals[player] = nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			updateIncubatorLabels()
		end
	end)
end

return EggService

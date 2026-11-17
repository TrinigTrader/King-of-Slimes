--!strict
-- Gives each player one of the 6 fenced plots and spawns them there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)

local Modules = script.Parent.Parent.Modules
local World = require(Modules.World)
local PlayerState = require(Modules.PlayerState)

local DataService = require(script.Parent.DataService)

local PlotService = {}

local owners: { [number]: Player } = {}

function PlotService.getPlot(player: Player): World.PlotRefs?
	local index = PlayerState.get(player).plotIndex
	if not index then
		return nil
	end
	return World.get().plots[index]
end

function PlotService.ownsPlot(player: Player, plot: World.PlotRefs): boolean
	return owners[plot.index] == player
end

local function sendHome(player: Player)
	local plot = PlotService.getPlot(player)
	if plot then
		PlayerState.teleport(player, plot.spawn)
	end
end

local function assign(player: Player, _profile: Types.Profile)
	local plots = World.get().plots
	for index = 1, #plots do
		if not owners[index] then
			owners[index] = player
			PlayerState.get(player).plotIndex = index
			plots[index].ownerLabel.Text = `{player.DisplayName}'s Plot`
			if player.Character then
				task.defer(sendHome, player)
			end
			return
		end
	end
	warn(`[PlotService] no free plot for {player.Name}`)
end

local function release(player: Player)
	local index = PlayerState.get(player).plotIndex
	if index and owners[index] == player then
		owners[index] = nil
		World.get().plots[index].ownerLabel.Text = "Empty plot"
	end
end

function PlotService.init()
	World.get()
	DataService.ProfileLoaded:Connect(assign)
	DataService.ProfileReleasing:Connect(function(player: Player)
		release(player)
	end)
end

function PlotService.start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			task.wait() -- let the default spawn finish before moving
			sendHome(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(release)
end

return PlotService

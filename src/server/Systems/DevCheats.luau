--!strict
-- Studio-only test commands, typed in chat. Never active in a live server.
--   /coins 5000      give Coins
--   /maxupgrades     max every upgrade
--   /egg Canyon      carry an egg (Meadow, Cavern, Canyon)
--   /hatchnow        finish all incubating eggs

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Upgrades = require(Shared.Config.Upgrades)
local Eggs = require(Shared.Config.Eggs)

local DataService = require(script.Parent.DataService)
local EggService = require(script.Parent.EggService)

local DevCheats = {}

local function command(alias: string, handler: (Player, { string }) -> ())
	local cmd = Instance.new("TextChatCommand")
	cmd.Name = `Dev_{alias}`
	cmd.PrimaryAlias = `/{alias}`
	cmd.Triggered:Connect(function(source: TextSource, text: string)
		local player = Players:GetPlayerByUserId(source.UserId)
		if not player or not DataService.getProfile(player) then
			return
		end
		local args = string.split(text, " ")
		table.remove(args, 1)
		handler(player, args)
		DataService.changed(player)
	end)
	cmd.Parent = TextChatService
end

function DevCheats.init()
	if not RunService:IsStudio() then
		return
	end
	command("coins", function(player, args)
		local profile = DataService.getProfile(player)
		if profile then
			profile.coins += tonumber(args[1]) or 1000
		end
	end)
	command("maxupgrades", function(player)
		local profile = DataService.getProfile(player)
		if profile then
			for id, def in Upgrades do
				profile.upgrades[id] = #def.tiers
			end
		end
	end)
	command("egg", function(player, args)
		local eggId = args[1] or "Meadow"
		if Eggs[eggId] then
			EggService.setCarrying(player, eggId)
		end
	end)
	command("hatchnow", function(player)
		local profile = DataService.getProfile(player)
		if profile then
			for _, slot in profile.incubating do
				slot.readyAt = 0
			end
		end
	end)
	print("[DevCheats] Studio test commands enabled: /coins, /maxupgrades, /egg, /hatchnow")
end

return DevCheats

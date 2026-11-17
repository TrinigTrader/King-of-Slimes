--!strict
-- Selling orbs at the hub and buying upgrades in the shop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)
local Upgrades = require(Shared.Config.Upgrades)

local Modules = script.Parent.Parent.Modules
local World = require(Modules.World)
local Stats = require(Modules.Stats)
local RateLimit = require(Modules.RateLimit)

local DataService = require(script.Parent.DataService)

local EconomyService = {}

local function sell(player: Player)
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	if profile.backpackCount <= 0 then
		DataService.notify(player, "Your backpack is empty. Go collect orbs!")
		return
	end
	local coins = Formulas.sellCoins(profile.backpackValue, Stats.sellBonus(profile))
	profile.coins += coins
	profile.backpackCount = 0
	profile.backpackValue = 0
	DataService.changed(player)
	DataService.notify(player, `Sold for {coins} Coins!`)
end

local function buyUpgrade(player: Player, upgradeId: unknown)
	if not RateLimit.allow(player, "BuyUpgrade", 0.25) then
		return
	end
	if typeof(upgradeId) ~= "string" then
		return
	end
	local def = Upgrades[upgradeId]
	if not def then
		return
	end
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	local current = profile.upgrades[upgradeId] or 1
	local nextTier = def.tiers[current + 1]
	if not nextTier then
		DataService.notify(player, `{def.name} is already maxed!`)
		return
	end
	if profile.coins < nextTier.cost then
		DataService.notify(player, `You need {nextTier.cost - profile.coins} more Coins.`)
		return
	end
	profile.coins -= nextTier.cost
	profile.upgrades[upgradeId] = current + 1
	DataService.changed(player)
	DataService.notify(player, `{def.name} upgraded to {nextTier.value} {def.unit}!`)
end

function EconomyService.init()
	local world = World.get()
	world.sellPrompt.Triggered:Connect(sell)
	local openUI = Remotes.get("OpenUI")
	world.shopPrompt.Triggered:Connect(function(player)
		openUI:FireClient(player, "Shop")
	end)
	Remotes.get("BuyUpgrade").OnServerEvent:Connect(buyUpgrade)
end

function EconomyService.start() end

return EconomyService

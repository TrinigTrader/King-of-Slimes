--!strict
-- Upgrade shop panel plus egg odds. Buying sends only the upgrade id; the
-- server checks the price and the player's Coins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Remotes = require(Shared.Remotes)
local Formulas = require(Shared.Formulas)
local Upgrades = require(Shared.Config.Upgrades)
local Eggs = require(Shared.Config.Eggs)
local Slimes = require(Shared.Config.Slimes)

local UI = require(script.Parent.Parent.UI)
local StateController = require(script.Parent.StateController)
local HudController = require(script.Parent.HudController)

local ShopController = {}

local ORDER: { Types.UpgradeId } = { "Shoes" :: Types.UpgradeId, "Backpack", "Pen", "Incubators" }

local panel: Frame
local rows: { [string]: { info: TextLabel, buy: TextButton } } = {}

local function render(state: Types.Snapshot)
	for _, id in ORDER do
		local def = Upgrades[id]
		local row = rows[id]
		local level = state.upgrades[id] or 1
		local current = def.tiers[level]
		local nextTier = def.tiers[level + 1]
		if nextTier then
			row.info.Text = `{def.name}: {current.value} -> {nextTier.value} {def.unit}`
			row.buy.Text = `{UI.formatNumber(nextTier.cost)} Coins`
			row.buy.BackgroundColor3 = if state.coins >= nextTier.cost
				then UI.Colors.Good
				else UI.Colors.Muted
			row.buy.Active = true
		else
			row.info.Text = `{def.name}: {current.value} {def.unit} (MAX)`
			row.buy.Text = "Maxed"
			row.buy.BackgroundColor3 = UI.Colors.Muted
			row.buy.Active = false
		end
	end
end

local function buildOdds(body: Instance)
	local order = 100
	for _, eggId in { "Meadow", "Cavern", "Canyon" } do
		local def = Eggs[eggId]
		local odds = Formulas.oddsPercent(def.odds)
		local parts = {}
		for _, option in def.odds do
			table.insert(
				parts,
				`{Slimes[option.species].name} {string.format("%.1f", odds[option.species])}%`
			)
		end
		local label = UI.text({
			text = `{def.name} ({def.hatchSeconds}s): {table.concat(parts, ", ")}`,
			size = UDim2.new(1, -8, 0, 40),
			color = UI.Colors.Muted,
			parent = body,
		})
		label.TextScaled = false
		label.TextSize = 15
		label.TextWrapped = true
		label.LayoutOrder = order
		order += 1
	end
end

function ShopController.init()
	local body
	panel, body = UI.panel("Shop", "Upgrade Shop")
	for index, id in ORDER do
		local row = UI.frame({
			name = id,
			size = UDim2.new(1, -8, 0, 56),
			position = UDim2.new(),
			color = UI.Colors.PanelLight,
			parent = body,
		})
		row.LayoutOrder = index
		local info = UI.text({
			text = id,
			size = UDim2.new(0.6, -12, 0, 30),
			position = UDim2.new(0, 12, 0.5, -15),
			parent = row,
		})
		local buy = UI.button({
			text = "Buy",
			size = UDim2.new(0.35, 0, 0, 40),
			position = UDim2.new(0.63, 0, 0.5, -20),
			parent = row,
			onClick = function()
				Remotes.get("BuyUpgrade"):FireServer(id)
			end,
		})
		rows[id] = { info = info, buy = buy }
	end
	local oddsTitle = UI.text({
		text = "Egg odds",
		size = UDim2.new(1, -8, 0, 28),
		color = UI.Colors.Gold,
		parent = body,
	})
	oddsTitle.LayoutOrder = 99
	buildOdds(body)
end

function ShopController.start()
	StateController.Changed:Connect(render)
	StateController.OpenRequested:Connect(function(name: string)
		if name == "Shop" then
			UI.toggle(panel, true)
		end
	end)
	local button = HudController.ShopButton
	if button then
		button.Activated:Connect(function()
			UI.toggle(panel)
		end)
	end
	local state = StateController.get()
	if state then
		render(state)
	end
end

return ShopController

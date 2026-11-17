--!strict
-- Coins, backpack and speed readout, the zone banner with recommended speed,
-- menu buttons, and toast notifications.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Layout = require(Shared.Layout)
local Zones = require(Shared.Config.Zones)
local Eggs = require(Shared.Config.Eggs)

local UI = require(script.Parent.Parent.UI)
local StateController = require(script.Parent.StateController)

local HudController = {}

local coinsLabel: TextLabel
local backpackLabel: TextLabel
local backpackFill: Frame
local speedLabel: TextLabel
local eggLabel: TextLabel
local zoneBanner: TextLabel
local toastHolder: Frame

-- Buttons that other controllers hook into.
HudController.ShopButton = nil :: TextButton?
HudController.SlimesButton = nil :: TextButton?

local function toast(message: string)
	local label = UI.text({
		text = message,
		size = UDim2.new(1, 0, 0, 34),
		align = Enum.TextXAlignment.Center,
		parent = toastHolder,
	})
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = UI.Colors.Panel
	UI.corner(label, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = label
	UI.pop(label)
	task.delay(3.5, function()
		local tween = TweenService:Create(
			label,
			TweenInfo.new(0.4),
			{ TextTransparency = 1, BackgroundTransparency = 1 }
		)
		tween:Play()
		tween.Completed:Wait()
		label:Destroy()
	end)
end

local function render(state: Types.Snapshot)
	coinsLabel.Text = `Coins: {UI.formatNumber(state.coins)}`
	backpackLabel.Text =
		`Backpack {state.backpackCount}/{state.backpackCapacity}  ({UI.formatNumber(
			state.backpackValue
		)} value)`
	local fill = if state.backpackCapacity > 0
		then state.backpackCount / state.backpackCapacity
		else 0
	backpackFill.Size = UDim2.fromScale(math.clamp(fill, 0, 1), 1)
	backpackFill.BackgroundColor3 = if fill >= 1 then UI.Colors.Bad else UI.Colors.Good
	speedLabel.Text = `Speed: {math.floor(state.walkSpeed * 10) / 10}`
	local carrying = state.carryingEgg
	eggLabel.Visible = carrying ~= nil
	if carrying then
		local def = Eggs[carrying]
		eggLabel.Text = `Carrying {if def then def.name else "an egg"}: take it to your incubator!`
	end
end

local lastZone: number? = -1
local function updateZoneBanner()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local zoneIndex = Layout.zoneAt(root.Position, #Zones)
	if zoneIndex == lastZone then
		return
	end
	lastZone = zoneIndex
	if not zoneIndex then
		zoneBanner.Visible = false
		return
	end
	local zone = Zones[zoneIndex]
	local state = StateController.get()
	local speed = if state then state.walkSpeed else 16
	local fastEnough = speed >= zone.recommendedSpeed
	zoneBanner.Visible = true
	zoneBanner.Text =
		`{zone.name}  |  Recommended speed {zone.recommendedSpeed} (you: {math.floor(speed)})`
	zoneBanner.TextColor3 = if fastEnough then UI.Colors.Good else UI.Colors.Bad
end

function HudController.init()
	local screen = UI.screen()

	local stats = UI.frame({
		name = "Stats",
		size = UDim2.new(0.28, 0, 0, 132),
		position = UDim2.fromOffset(12, 12),
		parent = screen,
	})
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(240, 0)
	constraint.MaxSize = Vector2.new(380, math.huge)
	constraint.Parent = stats

	coinsLabel = UI.text({
		text = "Coins: 0",
		size = UDim2.new(1, -20, 0, 30),
		position = UDim2.fromOffset(10, 8),
		color = UI.Colors.Gold,
		parent = stats,
	})
	backpackLabel = UI.text({
		text = "Backpack",
		size = UDim2.new(1, -20, 0, 22),
		position = UDim2.fromOffset(10, 42),
		parent = stats,
	})
	local bar = UI.frame({
		name = "BackpackBar",
		size = UDim2.new(1, -20, 0, 12),
		position = UDim2.fromOffset(10, 68),
		color = UI.Colors.PanelLight,
		transparency = 0,
		parent = stats,
	})
	backpackFill = UI.frame({
		name = "Fill",
		size = UDim2.fromScale(0, 1),
		position = UDim2.new(),
		color = UI.Colors.Good,
		transparency = 0,
		parent = bar,
	})
	speedLabel = UI.text({
		text = "Speed: 16",
		size = UDim2.new(1, -20, 0, 24),
		position = UDim2.fromOffset(10, 90),
		color = UI.Colors.Accent,
		parent = stats,
	})

	eggLabel = UI.text({
		text = "",
		size = UDim2.new(0.5, 0, 0, 30),
		position = UDim2.new(0.5, 0, 0, 60),
		align = Enum.TextXAlignment.Center,
		color = UI.Colors.Gold,
		parent = screen,
	})
	eggLabel.AnchorPoint = Vector2.new(0.5, 0)
	eggLabel.Visible = false

	zoneBanner = UI.text({
		text = "",
		size = UDim2.new(0.6, 0, 0, 34),
		position = UDim2.new(0.5, 0, 0, 16),
		align = Enum.TextXAlignment.Center,
		parent = screen,
	})
	zoneBanner.AnchorPoint = Vector2.new(0.5, 0)
	zoneBanner.TextStrokeTransparency = 0.3
	zoneBanner.Visible = false

	toastHolder = Instance.new("Frame")
	toastHolder.Name = "Toasts"
	toastHolder.BackgroundTransparency = 1
	toastHolder.Size = UDim2.fromScale(0.45, 0.4)
	toastHolder.Position = UDim2.fromScale(0.5, 0.55)
	toastHolder.AnchorPoint = Vector2.new(0.5, 0)
	toastHolder.Parent = screen
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = toastHolder

	local buttons = Instance.new("Frame")
	buttons.Name = "MenuButtons"
	buttons.BackgroundTransparency = 1
	buttons.Size = UDim2.fromOffset(130, 110)
	buttons.Position = UDim2.new(0, 12, 0.5, 0)
	buttons.AnchorPoint = Vector2.new(0, 0.5)
	buttons.Parent = screen
	local buttonList = Instance.new("UIListLayout")
	buttonList.Padding = UDim.new(0, 8)
	buttonList.Parent = buttons
	HudController.ShopButton = UI.button({
		text = "Shop",
		size = UDim2.new(1, 0, 0, 48),
		color = UI.Colors.Gold,
		parent = buttons,
		onClick = function() end,
	})
	HudController.SlimesButton = UI.button({
		text = "Slimes",
		size = UDim2.new(1, 0, 0, 48),
		color = UI.Colors.Accent,
		parent = buttons,
		onClick = function() end,
	})
end

function HudController.start()
	StateController.Changed:Connect(function(state: Types.Snapshot)
		render(state)
		lastZone = -1 -- re-evaluate banner colour with the new speed
	end)
	StateController.Notified:Connect(toast)
	local existing = StateController.get()
	if existing then
		render(existing)
	end
	RunService.Heartbeat:Connect(updateZoneBanner)
end

return HudController

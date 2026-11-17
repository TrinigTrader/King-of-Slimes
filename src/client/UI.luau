--!strict
-- Small helpers for building UI from code. Sizes use Scale so the UI works on
-- phones and desktops; UISizeConstraint keeps panels readable on big screens.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UI = {}

UI.Colors = table.freeze({
	Panel = Color3.fromRGB(30, 34, 52),
	PanelLight = Color3.fromRGB(48, 54, 80),
	Accent = Color3.fromRGB(120, 220, 255),
	Good = Color3.fromRGB(90, 210, 110),
	Bad = Color3.fromRGB(230, 80, 80),
	Gold = Color3.fromRGB(255, 205, 60),
	Text = Color3.fromRGB(245, 245, 255),
	Muted = Color3.fromRGB(170, 175, 200),
})

local screen: ScreenGui? = nil

function UI.screen(): ScreenGui
	if screen then
		return screen
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "KingOfSlimesUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui.Parent = playerGui
	screen = gui
	return gui
end

function UI.corner(parent: GuiObject, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
end

function UI.frame(props: {
	name: string,
	size: UDim2,
	position: UDim2,
	anchor: Vector2?,
	color: Color3?,
	transparency: number?,
	parent: Instance,
}): Frame
	local f = Instance.new("Frame")
	f.Name = props.name
	f.Size = props.size
	f.Position = props.position
	f.AnchorPoint = props.anchor or Vector2.zero
	f.BackgroundColor3 = props.color or UI.Colors.Panel
	f.BackgroundTransparency = props.transparency or 0.1
	f.BorderSizePixel = 0
	f.Parent = props.parent
	UI.corner(f)
	return f
end

function UI.text(props: {
	name: string?,
	text: string,
	size: UDim2,
	position: UDim2?,
	color: Color3?,
	align: Enum.TextXAlignment?,
	parent: Instance,
}): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = props.name or "Label"
	t.Text = props.text
	t.Size = props.size
	t.Position = props.position or UDim2.new()
	t.BackgroundTransparency = 1
	t.TextColor3 = props.color or UI.Colors.Text
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextXAlignment = props.align or Enum.TextXAlignment.Left
	t.Parent = props.parent
	return t
end

function UI.button(props: {
	name: string?,
	text: string,
	size: UDim2,
	position: UDim2?,
	color: Color3?,
	parent: Instance,
	onClick: () -> (),
}): TextButton
	local b = Instance.new("TextButton")
	b.Name = props.name or "Button"
	b.Text = props.text
	b.Size = props.size
	b.Position = props.position or UDim2.new()
	b.BackgroundColor3 = props.color or UI.Colors.Accent
	b.TextColor3 = Color3.fromRGB(20, 20, 30)
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.AutoButtonColor = true
	b.BorderSizePixel = 0
	b.Parent = props.parent
	UI.corner(b, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.15, 0)
	padding.PaddingBottom = UDim.new(0.15, 0)
	padding.Parent = b
	b.Activated:Connect(props.onClick)
	return b
end

-- Centered modal panel with a title and close button. Returns (panel, body).
function UI.panel(name: string, title: string): (Frame, Frame)
	local panel = UI.frame({
		name = name,
		size = UDim2.fromScale(0.5, 0.65),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		parent = UI.screen(),
	})
	panel.Visible = false
	panel:SetAttribute("Modal", true)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(320, 300)
	constraint.MaxSize = Vector2.new(640, 560)
	constraint.Parent = panel

	UI.text({
		text = title,
		size = UDim2.new(1, -70, 0, 40),
		position = UDim2.fromOffset(16, 10),
		parent = panel,
	})
	UI.button({
		text = "X",
		size = UDim2.fromOffset(40, 40),
		position = UDim2.new(1, -50, 0, 10),
		color = UI.Colors.Bad,
		parent = panel,
		onClick = function()
			panel.Visible = false
		end,
	})

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Size = UDim2.new(1, -24, 1, -70)
	body.Position = UDim2.fromOffset(12, 60)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body

	return panel, body :: any
end

function UI.pop(object: GuiObject)
	local scale = object:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = object
	scale.Scale = 0.85
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- Close every other panel and toggle this one.
function UI.toggle(panel: GuiObject, forceOpen: boolean?)
	local open = if forceOpen ~= nil then forceOpen else not panel.Visible
	for _, child in UI.screen():GetChildren() do
		if child:IsA("Frame") and child:GetAttribute("Modal") and child ~= panel then
			child.Visible = false
		end
	end
	panel.Visible = open
	if open then
		UI.pop(panel)
	end
end

function UI.formatNumber(n: number): string
	local formatted = tostring(math.floor(n))
	while true do
		local replaced, count = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = replaced
		if count == 0 then
			break
		end
	end
	return formatted
end

return UI

--!strict
-- "Slimes" panel: your collection, choose a partner, release slimes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Remotes = require(Shared.Remotes)
local Formulas = require(Shared.Formulas)
local Slimes = require(Shared.Config.Slimes)
local Rarities = require(Shared.Config.Rarities)

local UI = require(script.Parent.Parent.UI)
local StateController = require(script.Parent.StateController)
local HudController = require(script.Parent.HudController)

local SlimesController = {}

local panel: Frame
local body: Frame
local header: TextLabel

local PASSIVE_TEXT: { [Types.PassiveKind]: (number) -> string } = {
	PickupRange = function(v: number)
		return `+{math.floor(v * 100)}% orb pickup range`
	end,
	BackpackBonus = function(v: number)
		return `+{math.floor(v * 100)}% backpack space`
	end,
	SellBonus = function(v: number)
		return `+{math.floor(v * 100)}% Coins when selling`
	end,
	MonsterSlow = function(v: number)
		return `Monsters {math.floor(v * 100)}% slower chasing you`
	end,
	SpeedBonus = function(v: number)
		return `+{math.floor(v * 10) / 10} speed`
	end,
}

local function render(state: Types.Snapshot)
	for _, child in body:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local count = 0
	local entries: { { uid: string, slime: Types.SlimeData } } = {}
	for uid, slime in state.slimes do
		count += 1
		table.insert(entries, { uid = uid, slime = slime })
	end
	header.Text =
		`Pen: {count}/{state.penCapacity} slimes. Your partner follows you and gives its bonus.`
	table.sort(entries, function(a, b)
		if a.uid == state.partnerUid then
			return true
		elseif b.uid == state.partnerUid then
			return false
		end
		local ra = Rarities[Slimes[a.slime.species].rarity].order
		local rb = Rarities[Slimes[b.slime.species].rarity].order
		if ra ~= rb then
			return ra > rb
		end
		return a.slime.level > b.slime.level
	end)

	for index, entry in entries do
		local slime = entry.slime
		local def = Slimes[slime.species]
		if not def then
			continue
		end
		local isPartner = entry.uid == state.partnerUid
		local row = UI.frame({
			name = entry.uid,
			size = UDim2.new(1, -8, 0, 74),
			position = UDim2.new(),
			color = if isPartner then Color3.fromRGB(40, 80, 90) else UI.Colors.PanelLight,
			parent = body,
		})
		row.LayoutOrder = index + 1
		local swatch = UI.frame({
			name = "Swatch",
			size = UDim2.fromOffset(46, 46),
			position = UDim2.new(0, 10, 0.5, -23),
			color = def.color,
			transparency = 0,
			parent = row,
		})
		UI.corner(swatch, 23)
		local need = Formulas.xpToNext(slime.level)
		UI.text({
			text = `{if slime.shiny then "Shiny " else ""}{def.name}  Lv {slime.level} ({Formulas.stage(
				slime.level
			)})`,
			size = UDim2.new(0.55, -70, 0, 26),
			position = UDim2.fromOffset(66, 8),
			color = Rarities[def.rarity].color,
			parent = row,
		})
		UI.text({
			text = `{def.rarity} {def.element} | {PASSIVE_TEXT[def.passive](
				Formulas.passiveValue(def.passiveAmount, slime.level)
			)} | XP {slime.xp}/{need}`,
			size = UDim2.new(0.55, -70, 0, 30),
			position = UDim2.fromOffset(66, 38),
			color = UI.Colors.Muted,
			parent = row,
		})
		if isPartner then
			UI.text({
				text = "PARTNER",
				size = UDim2.new(0.4, -12, 0, 30),
				position = UDim2.new(0.6, 0, 0.5, -15),
				align = Enum.TextXAlignment.Center,
				color = UI.Colors.Accent,
				parent = row,
			})
		else
			UI.button({
				text = "Partner",
				size = UDim2.new(0.19, 0, 0, 36),
				position = UDim2.new(0.6, 0, 0.5, -18),
				parent = row,
				onClick = function()
					Remotes.get("SetPartner"):FireServer(entry.uid)
				end,
			})
			local releaseButton: TextButton
			local armedAt = 0
			releaseButton = UI.button({
				text = "Release",
				size = UDim2.new(0.19, 0, 0, 36),
				position = UDim2.new(0.8, 0, 0.5, -18),
				color = UI.Colors.Bad,
				parent = row,
				onClick = function()
					-- Two clicks within 3 seconds, so a slime is never released by accident.
					if os.clock() - armedAt < 3 then
						Remotes.get("ReleaseSlime"):FireServer(entry.uid)
					else
						armedAt = os.clock()
						releaseButton.Text = "Sure?"
						task.delay(3, function()
							if releaseButton.Parent then
								releaseButton.Text = "Release"
							end
						end)
					end
				end,
			})
		end
	end
end

function SlimesController.init()
	panel, body = UI.panel("Slimes", "My Slimes")
	header = UI.text({
		text = "",
		size = UDim2.new(1, -8, 0, 24),
		color = UI.Colors.Muted,
		parent = body,
	})
	header.LayoutOrder = 0
end

function SlimesController.start()
	StateController.Changed:Connect(function(state: Types.Snapshot)
		if panel.Visible then
			render(state)
		end
	end)
	local button = HudController.SlimesButton
	if button then
		button.Activated:Connect(function()
			UI.toggle(panel)
			local state = StateController.get()
			if panel.Visible and state then
				render(state)
			end
		end)
	end
end

return SlimesController

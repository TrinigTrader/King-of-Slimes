--!strict
-- Builds the blockout map from code on first use: hub, 6 fenced plots and the
-- zones. Art can later replace these parts; systems only rely on the refs
-- returned here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Layout)
local Game = require(Shared.Config.Game)
local Zones = require(Shared.Config.Zones)

export type PlotRefs = {
	index: number,
	model: Model,
	center: Vector3,
	spawn: Vector3,
	penCenter: Vector3,
	ownerLabel: TextLabel,
	feedPrompt: ProximityPrompt,
	incubatorPrompt: ProximityPrompt,
	incubatorLabels: { TextLabel },
	incubatorParts: { BasePart },
}

export type WorldRefs = {
	root: Folder,
	sellPrompt: ProximityPrompt,
	shopPrompt: ProximityPrompt,
	plots: { PlotRefs },
	effects: Folder, -- orbs, eggs, monsters and slimes are parented here
}

local World = {}

local built: WorldRefs? = nil

local function part(props: {
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	canCollide: boolean?,
	shape: Enum.PartType?,
	parent: Instance,
}): Part
	local p = Instance.new("Part")
	p.Name = props.name
	p.Anchored = true
	p.Size = props.size
	p.Position = props.position
	p.Color = props.color
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Transparency = props.transparency or 0
	p.CanCollide = if props.canCollide == nil then true else props.canCollide
	p.Shape = props.shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = props.parent
	return p
end

local function label(parent: BasePart, text: string, offsetY: number, size: UDim2): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 150
	gui.Parent = parent
	local text_ = Instance.new("TextLabel")
	text_.Size = UDim2.fromScale(1, 1)
	text_.BackgroundTransparency = 1
	text_.TextScaled = true
	text_.Font = Enum.Font.FredokaOne
	text_.TextColor3 = Color3.new(1, 1, 1)
	text_.TextStrokeTransparency = 0.3
	text_.Text = text
	text_.Parent = gui
	return text_
end

local function prompt(
	parent: BasePart,
	action: string,
	objectText: string,
	hold: number?
): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = objectText
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

local function buildHub(root: Folder): (ProximityPrompt, ProximityPrompt)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = root

	local hubDepth = Layout.HUB_MAX_Z - Layout.HUB_MIN_Z
	part({
		name = "Floor",
		size = Vector3.new(Layout.HUB_HALF_X * 2, 2, hubDepth),
		position = Vector3.new(0, -1, (Layout.HUB_MIN_Z + Layout.HUB_MAX_Z) / 2),
		color = Color3.fromRGB(235, 225, 200),
		material = Enum.Material.Sand,
		parent = hub,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Layout.SPAWN - Vector3.new(0, 2.5, 0)
	spawn.Color = Color3.fromRGB(120, 220, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local sellPad = part({
		name = "SellPad",
		size = Vector3.new(12, 1, 12),
		position = Layout.SELL_PAD + Vector3.new(0, 0.5, 0),
		color = Color3.fromRGB(255, 210, 60),
		material = Enum.Material.Neon,
		parent = hub,
	})
	label(sellPad, "SELL ORBS", 5, UDim2.fromOffset(200, 50))
	local sellPrompt = prompt(sellPad, "Sell orbs", "Orb Trader")

	local shop = part({
		name = "ShopStand",
		size = Vector3.new(12, 6, 6),
		position = Layout.SHOP_STAND + Vector3.new(0, 3, 0),
		color = Color3.fromRGB(90, 160, 255),
		parent = hub,
	})
	label(shop, "UPGRADE SHOP", 6, UDim2.fromOffset(240, 50))
	local shopPrompt = prompt(shop, "Open shop", "Upgrades")

	-- Low walls around the hub sides and back.
	local wallColor = Color3.fromRGB(180, 160, 130)
	part({
		name = "WallBack",
		size = Vector3.new(Layout.HUB_HALF_X * 2, 12, 2),
		position = Vector3.new(0, 6, Layout.HUB_MIN_Z),
		color = wallColor,
		parent = hub,
	})
	for _, side in { -1, 1 } do
		part({
			name = "WallSide",
			size = Vector3.new(2, 12, hubDepth),
			position = Vector3.new(
				side * Layout.HUB_HALF_X,
				6,
				(Layout.HUB_MIN_Z + Layout.HUB_MAX_Z) / 2
			),
			color = wallColor,
			parent = hub,
		})
	end

	return sellPrompt, shopPrompt
end

local function buildPlot(root: Folder, index: number): PlotRefs
	local model = Instance.new("Model")
	model.Name = `Plot{index}`
	model.Parent = root

	local center = Layout.plotCenter(index)
	local size = Layout.PLOT_SIZE
	local fenceColor = Color3.fromRGB(150, 100, 60)

	part({
		name = "Floor",
		size = Vector3.new(size, 1, size),
		position = center + Vector3.new(0, 0.5, 0),
		color = Color3.fromRGB(150, 210, 120),
		material = Enum.Material.Grass,
		parent = model,
	})

	-- Fence on three sides plus two halves at the front, leaving a gate.
	local half = size / 2
	local fenceHeight = 4
	part({
		name = "FenceBack",
		size = Vector3.new(size, fenceHeight, 1),
		position = center + Vector3.new(0, fenceHeight / 2 + 1, -half),
		color = fenceColor,
		material = Enum.Material.Wood,
		parent = model,
	})
	for _, side in { -1, 1 } do
		part({
			name = "FenceSide",
			size = Vector3.new(1, fenceHeight, size),
			position = center + Vector3.new(side * half, fenceHeight / 2 + 1, 0),
			color = fenceColor,
			material = Enum.Material.Wood,
			parent = model,
		})
		part({
			name = "FenceFront",
			size = Vector3.new(half - 4, fenceHeight, 1),
			position = center + Vector3.new(side * (half / 2 + 2), fenceHeight / 2 + 1, half),
			color = fenceColor,
			material = Enum.Material.Wood,
			parent = model,
		})
	end

	local sign = part({
		name = "Sign",
		size = Vector3.new(10, 3, 0.5),
		position = center + Vector3.new(0, 8, half),
		color = Color3.fromRGB(110, 70, 40),
		material = Enum.Material.Wood,
		parent = model,
	})
	local ownerLabel = label(sign, "Empty plot", 0, UDim2.fromOffset(220, 50))

	local feedPad = part({
		name = "FeedBowl",
		size = Vector3.new(1, 5, 5),
		position = center + Vector3.new(-half + 6, 1.5, half - 6),
		color = Color3.fromRGB(255, 120, 200),
		shape = Enum.PartType.Cylinder,
		parent = model,
	})
	feedPad.Orientation = Vector3.new(0, 0, 90)
	label(feedPad, "FEED", 3, UDim2.fromOffset(120, 36))
	local feedPrompt = prompt(feedPad, "Feed partner", "Slime Bowl")

	local incubatorBase = part({
		name = "IncubatorBase",
		size = Vector3.new(10, 1, 4),
		position = center + Vector3.new(half - 8, 1.5, half - 6),
		color = Color3.fromRGB(200, 200, 220),
		material = Enum.Material.Metal,
		parent = model,
	})
	local incubatorPrompt = prompt(incubatorBase, "Use incubator", "Incubator")

	local incubatorParts: { BasePart } = {}
	local incubatorLabels: { TextLabel } = {}
	for slot = 1, 3 do
		local pod = part({
			name = `Incubator{slot}`,
			size = Vector3.new(2.4, 3, 2.4),
			position = incubatorBase.Position + Vector3.new((slot - 2) * 3.2, 2, 0),
			color = Color3.fromRGB(180, 240, 255),
			material = Enum.Material.Glass,
			transparency = 0.4,
			parent = model,
		})
		table.insert(incubatorParts, pod)
		table.insert(incubatorLabels, label(pod, "", 3, UDim2.fromOffset(110, 30)))
	end

	return {
		index = index,
		model = model,
		center = center,
		spawn = center + Vector3.new(0, 3, half + 6),
		penCenter = center + Vector3.new(0, 1, -4),
		ownerLabel = ownerLabel,
		feedPrompt = feedPrompt,
		incubatorPrompt = incubatorPrompt,
		incubatorLabels = incubatorLabels,
		incubatorParts = incubatorParts,
	}
end

local function buildZone(root: Folder, index: number)
	local zone = Zones[index]
	local folder = Instance.new("Folder")
	folder.Name = `Zone{index}_{zone.name}`
	folder.Parent = root

	local minZ = Layout.zoneMinZ(index)
	local center = Layout.zoneCenter(index)
	part({
		name = "Floor",
		size = Vector3.new(Layout.ZONE_HALF_X * 2, 2, Layout.ZONE_LENGTH),
		position = center - Vector3.new(0, 1, 0),
		color = zone.floorColor,
		material = zone.floorMaterial,
		parent = folder,
	})

	-- Safe gate strip at the zone entrance.
	part({
		name = "SafeGate",
		size = Vector3.new(Layout.ZONE_HALF_X * 2, 0.2, Layout.SAFE_DEPTH),
		position = Vector3.new(0, 0.1, minZ + Layout.SAFE_DEPTH / 2),
		color = Color3.fromRGB(120, 220, 255),
		material = Enum.Material.Neon,
		transparency = 0.6,
		canCollide = false,
		parent = folder,
	})
	local arch = part({
		name = "GateSign",
		size = Vector3.new(30, 6, 1),
		position = Vector3.new(0, 14, minZ),
		color = Color3.fromRGB(40, 40, 60),
		parent = folder,
	})
	label(
		arch,
		`{zone.name}\nRecommended speed: {zone.recommendedSpeed}`,
		0,
		UDim2.fromOffset(360, 80)
	)
	for _, side in { -1, 1 } do
		part({
			name = "GatePillar",
			size = Vector3.new(2, 14, 2),
			position = Vector3.new(side * 16, 7, minZ),
			color = Color3.fromRGB(40, 40, 60),
			parent = folder,
		})
		part({
			name = "Wall",
			size = Vector3.new(2, 20, Layout.ZONE_LENGTH),
			position = Vector3.new(side * (Layout.ZONE_HALF_X + 1), 10, center.Z),
			color = zone.floorColor:Lerp(Color3.new(0, 0, 0), 0.4),
			transparency = 0.2,
			parent = folder,
		})
	end

	-- A few rocks so zones are not empty planes.
	local rng = Random.new(index * 1000)
	for _ = 1, 10 do
		local point = Layout.randomZonePoint(index, rng, 10)
		local s = rng:NextNumber(4, 10)
		part({
			name = "Rock",
			size = Vector3.new(s, s * 0.6, s),
			position = point + Vector3.new(0, s * 0.3, 0),
			color = zone.floorColor:Lerp(Color3.new(0.3, 0.3, 0.3), 0.6),
			material = Enum.Material.Rock,
			parent = folder,
		})
	end
end

function World.get(): WorldRefs
	if built then
		return built
	end

	local root = Instance.new("Folder")
	root.Name = "World"

	local sellPrompt, shopPrompt = buildHub(root)
	local plots: { PlotRefs } = {}
	for index = 1, Game.PLOT_COUNT do
		table.insert(plots, buildPlot(root, index))
	end
	for index = 1, #Zones do
		buildZone(root, index)
	end

	-- End wall behind the last zone.
	part({
		name = "EndWall",
		size = Vector3.new(Layout.ZONE_HALF_X * 2, 20, 2),
		position = Vector3.new(0, 10, Layout.zoneMinZ(#Zones + 1)),
		color = Color3.fromRGB(30, 30, 40),
		parent = root,
	})

	local effects = Instance.new("Folder")
	effects.Name = "Dynamic"
	effects.Parent = root

	root.Parent = Workspace

	local refs: WorldRefs = {
		root = root,
		sellPrompt = sellPrompt,
		shopPrompt = shopPrompt,
		plots = plots,
		effects = effects,
	}
	built = refs
	return refs
end

return World

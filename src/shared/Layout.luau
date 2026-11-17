--!strict
-- World layout shared by the server (which builds it) and the client (which
-- uses it for the zone banner). The hub sits at the origin; zones run along +Z.
--
--   z = -110 ......... hub (plots along the back) ......... z = 110
--   z = 110 + (i-1) * ZONE_LENGTH: zone i, first SAFE_DEPTH studs are a safe gate

local Layout = {}

Layout.HUB_HALF_X = 130
Layout.HUB_MIN_Z = -110
Layout.HUB_MAX_Z = 110

Layout.ZONE_HALF_X = 120
Layout.ZONE_LENGTH = 200
Layout.SAFE_DEPTH = 24

Layout.PLOT_SIZE = 36
Layout.PLOT_Z = -82
Layout.PLOT_SPACING = 42

Layout.SPAWN = Vector3.new(0, 3, 40)
Layout.SELL_PAD = Vector3.new(-30, 0, 30)
Layout.SHOP_STAND = Vector3.new(30, 0, 30)

function Layout.plotCenter(index: number): Vector3
	local x = (index - 3.5) * Layout.PLOT_SPACING
	return Vector3.new(x, 0, Layout.PLOT_Z)
end

function Layout.zoneMinZ(index: number): number
	return Layout.HUB_MAX_Z + (index - 1) * Layout.ZONE_LENGTH
end

function Layout.zoneCenter(index: number): Vector3
	return Vector3.new(0, 0, Layout.zoneMinZ(index) + Layout.ZONE_LENGTH / 2)
end

-- Returns the zone index at a position (nil in the hub) and whether the
-- position is inside that zone's safe gate.
function Layout.zoneAt(position: Vector3, zoneCount: number): (number?, boolean)
	if position.Z < Layout.HUB_MAX_Z then
		return nil, true
	end
	local index = math.floor((position.Z - Layout.HUB_MAX_Z) / Layout.ZONE_LENGTH) + 1
	if index > zoneCount then
		return nil, true
	end
	local depth = position.Z - Layout.zoneMinZ(index)
	return index, depth < Layout.SAFE_DEPTH
end

-- Random point in the zone's monster area (outside the safe gate).
function Layout.randomZonePoint(index: number, rng: Random, margin: number): Vector3
	local minZ = Layout.zoneMinZ(index) + Layout.SAFE_DEPTH + margin
	local maxZ = Layout.zoneMinZ(index) + Layout.ZONE_LENGTH - margin
	local x = rng:NextNumber(-Layout.ZONE_HALF_X + margin, Layout.ZONE_HALF_X - margin)
	return Vector3.new(x, 0, rng:NextNumber(minZ, maxZ))
end

-- Clamp a point to the zone's monster area.
function Layout.clampToZone(index: number, position: Vector3, margin: number): Vector3
	local minZ = Layout.zoneMinZ(index) + Layout.SAFE_DEPTH + margin
	local maxZ = Layout.zoneMinZ(index) + Layout.ZONE_LENGTH - margin
	return Vector3.new(
		math.clamp(position.X, -Layout.ZONE_HALF_X + margin, Layout.ZONE_HALF_X - margin),
		position.Y,
		math.clamp(position.Z, minZ, maxZ)
	)
end

-- Where a caught player is sent: the zone's safe gate.
function Layout.zoneGate(index: number): Vector3
	return Vector3.new(0, 3, Layout.zoneMinZ(index) + Layout.SAFE_DEPTH / 2)
end

return Layout

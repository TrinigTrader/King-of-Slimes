--!strict
-- Zones in order from the hub outward. Monsters run slightly slower than the
-- recommended speed, so reaching it means you can outrun them.

export type ZoneDef = {
	name: string,
	monsterName: string,
	monsterSpeed: number,
	recommendedSpeed: number,
	orbValue: number,
	maxOrbs: number,
	eggId: string,
	eggSpawns: number,
	floorColor: Color3,
	floorMaterial: Enum.Material,
	orbColor: Color3,
	monsterColor: Color3,
}

local Zones: { ZoneDef } = {
	{
		name = "Dewdrop Meadow",
		monsterName = "Bramble Hound",
		monsterSpeed = 14,
		recommendedSpeed = 16,
		orbValue = 1,
		maxOrbs = 40,
		eggId = "Meadow",
		eggSpawns = 2,
		floorColor = Color3.fromRGB(110, 190, 90),
		floorMaterial = Enum.Material.Grass,
		orbColor = Color3.fromRGB(130, 255, 160),
		monsterColor = Color3.fromRGB(90, 60, 30),
	},
	{
		name = "Glowmoss Caverns",
		monsterName = "Cave Lurker",
		monsterSpeed = 20,
		recommendedSpeed = 22,
		orbValue = 3,
		maxOrbs = 40,
		eggId = "Cavern",
		eggSpawns = 2,
		floorColor = Color3.fromRGB(60, 70, 90),
		floorMaterial = Enum.Material.Slate,
		orbColor = Color3.fromRGB(90, 255, 230),
		monsterColor = Color3.fromRGB(40, 30, 60),
	},
	{
		name = "Cinder Canyon",
		monsterName = "Magma Brute",
		monsterSpeed = 26,
		recommendedSpeed = 28,
		orbValue = 8,
		maxOrbs = 40,
		eggId = "Canyon",
		eggSpawns = 2,
		floorColor = Color3.fromRGB(150, 80, 50),
		floorMaterial = Enum.Material.Basalt,
		orbColor = Color3.fromRGB(255, 160, 60),
		monsterColor = Color3.fromRGB(120, 20, 10),
	},
}

return table.freeze(Zones)

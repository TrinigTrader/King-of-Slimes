--!strict
-- Slime species. MVP roster: 8 slimes across 5 elements, Common to Epic.
-- passiveAmount: fraction for PickupRange/BackpackBonus/SellBonus/MonsterSlow,
-- studs per second for SpeedBonus. Scales up with level (see Formulas).
local Types = require(script.Parent.Parent.Types)

export type SlimeDef = {
	name: string,
	element: Types.Element,
	rarity: Types.Rarity,
	color: Color3,
	passive: Types.PassiveKind,
	passiveAmount: number,
}

local Slimes: { [string]: SlimeDef } = {
	Pudding = {
		name = "Pudding Slime",
		element = "Goo",
		rarity = "Common",
		color = Color3.fromRGB(120, 220, 255),
		passive = "PickupRange",
		passiveAmount = 0.10,
	},
	Mossy = {
		name = "Mossy Slime",
		element = "Earth",
		rarity = "Common",
		color = Color3.fromRGB(110, 170, 70),
		passive = "BackpackBonus",
		passiveAmount = 0.05,
	},
	Ember = {
		name = "Ember Slime",
		element = "Fire",
		rarity = "Uncommon",
		color = Color3.fromRGB(255, 120, 40),
		passive = "SellBonus",
		passiveAmount = 0.10,
	},
	Frost = {
		name = "Frost Slime",
		element = "Ice",
		rarity = "Uncommon",
		color = Color3.fromRGB(170, 230, 255),
		passive = "MonsterSlow",
		passiveAmount = 0.08,
	},
	Pebble = {
		name = "Pebble Slime",
		element = "Earth",
		rarity = "Rare",
		color = Color3.fromRGB(140, 120, 100),
		passive = "BackpackBonus",
		passiveAmount = 0.15,
	},
	Volt = {
		name = "Volt Slime",
		element = "Electric",
		rarity = "Rare",
		color = Color3.fromRGB(255, 235, 60),
		passive = "SpeedBonus",
		passiveAmount = 2,
	},
	Magma = {
		name = "Magma Slime",
		element = "Fire",
		rarity = "Epic",
		color = Color3.fromRGB(200, 40, 20),
		passive = "SellBonus",
		passiveAmount = 0.25,
	},
	Glacier = {
		name = "Glacier Slime",
		element = "Ice",
		rarity = "Epic",
		color = Color3.fromRGB(80, 160, 255),
		passive = "MonsterSlow",
		passiveAmount = 0.18,
	},
}

return table.freeze(Slimes)

--!strict
-- Upgrade tiers. Level 1 is what every player starts with (cost 0).
-- value: Backpack = orb slots, Shoes = WalkSpeed, Pen = slime slots,
-- Incubators = eggs hatching at once.

export type Tier = { value: number, cost: number }
export type UpgradeDef = { name: string, unit: string, tiers: { Tier } }

local Upgrades: { [string]: UpgradeDef } = {
	Backpack = {
		name = "Backpack",
		unit = "orbs",
		tiers = {
			{ value = 25, cost = 0 },
			{ value = 50, cost = 100 },
			{ value = 100, cost = 450 },
			{ value = 200, cost = 1800 },
			{ value = 400, cost = 6000 },
			{ value = 800, cost = 20000 },
		},
	},
	Shoes = {
		name = "Shoes",
		unit = "speed",
		tiers = {
			{ value = 16, cost = 0 },
			{ value = 18, cost = 150 },
			{ value = 22, cost = 600 },
			{ value = 25, cost = 1500 },
			{ value = 28, cost = 3000 },
			{ value = 34, cost = 12000 },
		},
	},
	Pen = {
		name = "Pen Size",
		unit = "slimes",
		tiers = {
			{ value = 3, cost = 0 },
			{ value = 5, cost = 500 },
			{ value = 8, cost = 3000 },
			{ value = 12, cost = 12000 },
		},
	},
	Incubators = {
		name = "Incubators",
		unit = "eggs",
		tiers = {
			{ value = 1, cost = 0 },
			{ value = 2, cost = 1000 },
			{ value = 3, cost = 6000 },
		},
	},
}

return table.freeze(Upgrades)

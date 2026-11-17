--!strict
-- Egg odds are weights, not percentages. Odds are shown to players in the UI
-- (required by Roblox once eggs can be bought with Robux).

export type EggDef = {
	name: string,
	hatchSeconds: number,
	color: Color3,
	odds: { { species: string, weight: number } },
}

local Eggs: { [string]: EggDef } = {
	Meadow = {
		name = "Meadow Egg",
		hatchSeconds = 20,
		color = Color3.fromRGB(240, 240, 200),
		odds = {
			{ species = "Pudding", weight = 60 },
			{ species = "Mossy", weight = 30 },
			{ species = "Ember", weight = 7 },
			{ species = "Frost", weight = 3 },
		},
	},
	Cavern = {
		name = "Cavern Egg",
		hatchSeconds = 45,
		color = Color3.fromRGB(120, 255, 200),
		odds = {
			{ species = "Mossy", weight = 30 },
			{ species = "Ember", weight = 30 },
			{ species = "Frost", weight = 25 },
			{ species = "Pebble", weight = 10 },
			{ species = "Volt", weight = 5 },
		},
	},
	Canyon = {
		name = "Canyon Egg",
		hatchSeconds = 90,
		color = Color3.fromRGB(255, 140, 60),
		odds = {
			{ species = "Ember", weight = 25 },
			{ species = "Frost", weight = 25 },
			{ species = "Pebble", weight = 25 },
			{ species = "Volt", weight = 17 },
			{ species = "Magma", weight = 5 },
			{ species = "Glacier", weight = 3 },
		},
	},
}

return table.freeze(Eggs)

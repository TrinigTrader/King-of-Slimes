--!strict
local Types = require(script.Parent.Parent.Types)

export type RarityDef = {
	order: number,
	color: Color3,
	incomePerTick: number, -- passive Coins per PASSIVE_INCOME_INTERVAL while in your pen
	releaseValue: number, -- Coins for releasing a slime
}

local Rarities: { [Types.Rarity]: RarityDef } = {
	Common = {
		order = 1,
		color = Color3.fromRGB(200, 200, 200),
		incomePerTick = 1,
		releaseValue = 10,
	},
	Uncommon = {
		order = 2,
		color = Color3.fromRGB(90, 200, 90),
		incomePerTick = 2,
		releaseValue = 40,
	},
	Rare = {
		order = 3,
		color = Color3.fromRGB(70, 140, 255),
		incomePerTick = 5,
		releaseValue = 150,
	},
	Epic = {
		order = 4,
		color = Color3.fromRGB(170, 80, 255),
		incomePerTick = 12,
		releaseValue = 600,
	},
	Legendary = {
		order = 5,
		color = Color3.fromRGB(255, 170, 30),
		incomePerTick = 30,
		releaseValue = 2500,
	},
	Mythic = {
		order = 6,
		color = Color3.fromRGB(255, 60, 120),
		incomePerTick = 80,
		releaseValue = 10000,
	},
	Secret = {
		order = 7,
		color = Color3.fromRGB(20, 20, 20),
		incomePerTick = 200,
		releaseValue = 50000,
	},
}

return table.freeze(Rarities)

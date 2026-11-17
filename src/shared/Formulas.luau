--!strict
-- Pure gameplay math. No Roblox APIs and no requires, so it can be unit
-- tested outside Studio (see tests/Formulas.spec.luau).

local Formulas = {}

-- XP needed to go from `level` to `level + 1`.
function Formulas.xpToNext(level: number): number
	return math.floor(10 * level ^ 1.5)
end

-- Adds XP and returns the new level, the leftover XP, and how many levels
-- were gained. Caps at maxLevel (extra XP is discarded at the cap).
function Formulas.addXp(
	level: number,
	xp: number,
	amount: number,
	maxLevel: number
): (number, number, number)
	local newLevel = level
	local newXp = xp + math.max(0, amount)
	while newLevel < maxLevel do
		local need = Formulas.xpToNext(newLevel)
		if newXp < need then
			break
		end
		newXp -= need
		newLevel += 1
	end
	if newLevel >= maxLevel then
		newXp = 0
	end
	return newLevel, newXp, newLevel - level
end

export type Stage = "Blob" | "Slime" | "Greater Slime" | "Monarch"

function Formulas.stage(level: number): Stage
	if level >= 50 then
		return "Monarch"
	elseif level >= 25 then
		return "Greater Slime"
	elseif level >= 10 then
		return "Slime"
	end
	return "Blob"
end

-- Visual diameter in studs; slimes grow as they level.
function Formulas.slimeSize(level: number): number
	local stageBonus = (
			{ Blob = 0, Slime = 0.5, ["Greater Slime"] = 1.2, Monarch = 2 }
		)[Formulas.stage(level)] :: number
	return 1.6 + math.min(level, 100) * 0.03 + stageBonus
end

-- Passive strength grows with level, up to double at level 100.
function Formulas.passiveValue(baseAmount: number, level: number): number
	return baseAmount * (1 + math.clamp(level, 1, 100) / 100)
end

function Formulas.sellCoins(orbValue: number, sellBonus: number): number
	return math.floor(orbValue * (1 + sellBonus))
end

function Formulas.feedXp(orbValue: number, xpPerValue: number): number
	return math.floor(orbValue * xpPerValue)
end

function Formulas.passiveIncome(incomePerTick: number, level: number): number
	return math.floor(incomePerTick * (1 + math.min(level, 100) * 0.02))
end

-- How many orbs (and how much value) a caught player drops.
function Formulas.catchDrop(count: number, value: number, fraction: number): (number, number)
	if count <= 0 then
		return 0, 0
	end
	local dropCount = math.floor(count * fraction)
	local dropValue = math.floor(value * dropCount / count)
	return dropCount, dropValue
end

-- Weighted pick. `roll` is a number in [0, 1).
function Formulas.weightedPick(
	options: { { species: string, weight: number } },
	roll: number
): string
	local total = 0
	for _, option in options do
		total += option.weight
	end
	local target = roll * total
	local running = 0
	for _, option in options do
		running += option.weight
		if target < running then
			return option.species
		end
	end
	return options[#options].species
end

-- Percent chance for each option, for the odds display.
function Formulas.oddsPercent(
	options: { { species: string, weight: number } }
): { [string]: number }
	local total = 0
	for _, option in options do
		total += option.weight
	end
	local result: { [string]: number } = {}
	for _, option in options do
		result[option.species] = option.weight / total * 100
	end
	return result
end

return Formulas

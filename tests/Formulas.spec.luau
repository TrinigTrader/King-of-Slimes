--!strict
-- Unit tests for the pure gameplay math. Run with the Luau CLI:
--   luau tests/Formulas.spec.luau
local Formulas = require("../src/shared/Formulas")

local failures = 0
local function check(name: string, condition: boolean)
	if condition then
		print(`  ok  {name}`)
	else
		failures += 1
		print(`FAIL  {name}`)
	end
end

-- XP curve
check("xpToNext(1) is 10", Formulas.xpToNext(1) == 10)
check("xpToNext grows", Formulas.xpToNext(10) > Formulas.xpToNext(9))

do
	local level, xp, gained = Formulas.addXp(1, 0, 9, 100)
	check("9 xp keeps level 1", level == 1 and xp == 9 and gained == 0)
	level, xp, gained = Formulas.addXp(1, 0, 10, 100)
	check("10 xp reaches level 2", level == 2 and xp == 0 and gained == 1)
	level, xp, gained = Formulas.addXp(1, 0, 10 + 28 + 5, 100)
	check("multi-level gain carries leftover", level == 3 and xp == 5 and gained == 2)
	level, xp = Formulas.addXp(99, 0, 10 ^ 9, 100)
	check("caps at max level with 0 xp", level == 100 and xp == 0)
	level = Formulas.addXp(5, 3, -50, 100)
	check("negative xp is ignored", level == 5)
end

-- Stages and size
check("stage Blob at 1", Formulas.stage(1) == "Blob")
check("stage Slime at 10", Formulas.stage(10) == "Slime")
check("stage Greater at 25", Formulas.stage(25) == "Greater Slime")
check("stage Monarch at 50", Formulas.stage(50) == "Monarch")
check("size grows with level", Formulas.slimeSize(50) > Formulas.slimeSize(10))

-- Economy
check("sell with no bonus", Formulas.sellCoins(100, 0) == 100)
check("sell with 25% bonus", Formulas.sellCoins(100, 0.25) == 125)
check("passive doubles at 100", Formulas.passiveValue(0.1, 100) == 0.2)

do
	local count, value = Formulas.catchDrop(10, 30, 0.3)
	check("catch drops 30% of orbs", count == 3 and value == 9)
	count, value = Formulas.catchDrop(0, 0, 0.3)
	check("catch with empty backpack drops nothing", count == 0 and value == 0)
	count, value = Formulas.catchDrop(2, 10, 0.3)
	check("catch rounds down small backpacks", count == 0 and value == 0)
end

-- Egg rolls
do
	local odds = { { species = "A", weight = 75 }, { species = "B", weight = 25 } }
	check("roll 0 picks first", Formulas.weightedPick(odds, 0) == "A")
	check("roll 0.74 picks first", Formulas.weightedPick(odds, 0.74) == "A")
	check("roll 0.75 picks second", Formulas.weightedPick(odds, 0.75) == "B")
	check("roll 0.9999 picks last", Formulas.weightedPick(odds, 0.9999) == "B")
	local percent = Formulas.oddsPercent(odds)
	check("odds percent", percent.A == 75 and percent.B == 25)
end

if failures > 0 then
	error(`{failures} test(s) failed`)
end
print("All Formulas tests passed")

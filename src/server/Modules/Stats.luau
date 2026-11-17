--!strict
-- Derived numbers computed from a profile (upgrades + partner passive).
-- The server uses these for every check; the client only displays them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Formulas = require(Shared.Formulas)
local Game = require(Shared.Config.Game)
local Slimes = require(Shared.Config.Slimes)
local Upgrades = require(Shared.Config.Upgrades)

local Stats = {}

function Stats.upgradeValue(profile: Types.Profile, id: Types.UpgradeId): number
	local tiers = Upgrades[id].tiers
	local level = math.clamp(profile.upgrades[id] or 1, 1, #tiers)
	return tiers[level].value
end

-- Passive bonus from the partner slime, or 0 if the partner's passive is
-- a different kind.
function Stats.partnerPassive(profile: Types.Profile, kind: Types.PassiveKind): number
	local uid = profile.partnerUid
	if not uid then
		return 0
	end
	local slime = profile.slimes[uid]
	if not slime then
		return 0
	end
	local def = Slimes[slime.species]
	if not def or def.passive ~= kind then
		return 0
	end
	return Formulas.passiveValue(def.passiveAmount, slime.level)
end

function Stats.backpackCapacity(profile: Types.Profile): number
	local base = Stats.upgradeValue(profile, "Backpack")
	return math.floor(base * (1 + Stats.partnerPassive(profile, "BackpackBonus")))
end

function Stats.walkSpeed(profile: Types.Profile): number
	return Stats.upgradeValue(profile, "Shoes") + Stats.partnerPassive(profile, "SpeedBonus")
end

function Stats.pickupRadius(profile: Types.Profile): number
	return Game.BASE_PICKUP_RADIUS * (1 + Stats.partnerPassive(profile, "PickupRange"))
end

function Stats.sellBonus(profile: Types.Profile): number
	return Stats.partnerPassive(profile, "SellBonus")
end

-- Fraction (0..0.5) that monsters are slowed by while chasing this player.
function Stats.monsterSlow(profile: Types.Profile): number
	return math.min(0.5, Stats.partnerPassive(profile, "MonsterSlow"))
end

function Stats.penCapacity(profile: Types.Profile): number
	return Stats.upgradeValue(profile, "Pen")
end

function Stats.incubatorCapacity(profile: Types.Profile): number
	return Stats.upgradeValue(profile, "Incubators")
end

function Stats.slimeCount(profile: Types.Profile): number
	local count = 0
	for _ in profile.slimes do
		count += 1
	end
	return count
end

return Stats

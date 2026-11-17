--!strict
-- Shared type definitions. Anything that crosses the client/server boundary
-- (the saved profile, the state snapshot) is defined here so both sides agree.

export type UpgradeId = "Backpack" | "Shoes" | "Pen" | "Incubators"
export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"
export type Element =
	"Goo"
	| "Fire"
	| "Ice"
	| "Earth"
	| "Electric"
	| "Water"
	| "Wind"
	| "Poison"
	| "Gravity"
	| "Light"
	| "Shadow"
export type PassiveKind = "PickupRange" | "BackpackBonus" | "SellBonus" | "MonsterSlow" | "SpeedBonus"

export type SlimeData = {
	species: string,
	level: number,
	xp: number,
	shiny: boolean,
}

export type IncubatorSlot = {
	eggId: string,
	readyAt: number,
}

export type Stats = {
	orbsCollected: number,
	eggsHatched: number,
	timesCaught: number,
}

-- Saved to DataStore. Bump Game.PROFILE_VERSION and add a migration step in
-- DataService when the shape changes.
export type Profile = {
	version: number,
	coins: number,
	gems: number,
	upgrades: { [string]: number },
	slimes: { [string]: SlimeData },
	partnerUid: string?,
	nextUid: number,
	backpackCount: number,
	backpackValue: number,
	incubating: { IncubatorSlot },
	stats: Stats,
	lastOnline: number,
}

-- Sent from server to the owning client whenever their state changes.
export type Snapshot = {
	coins: number,
	gems: number,
	backpackCount: number,
	backpackValue: number,
	backpackCapacity: number,
	walkSpeed: number,
	upgrades: { [string]: number },
	slimes: { [string]: SlimeData },
	partnerUid: string?,
	incubating: { IncubatorSlot },
	incubatorCapacity: number,
	penCapacity: number,
	carryingEgg: string?,
	pvpShieldUntil: number,
	serverTime: number,
}

return {}

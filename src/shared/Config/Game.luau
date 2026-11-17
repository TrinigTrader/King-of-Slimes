--!strict
-- Global tuning values. Replicated to clients: nothing secret here, and the
-- server never trusts a client-reported value.

return table.freeze({
	PROFILE_VERSION = 1,
	DATASTORE_NAME = "KingOfSlimes_PlayerData_v1",
	AUTOSAVE_INTERVAL = 60,
	SESSION_LOCK_TIMEOUT = 600,

	PLOT_COUNT = 6,

	BASE_PICKUP_RADIUS = 7,
	MONSTER_CATCH_RADIUS = 5,
	CATCH_DROP_FRACTION = 0.3,
	CATCH_GRACE_SECONDS = 3,
	DROPPED_ORB_LIFETIME = 60,

	FEED_XP_PER_VALUE = 2,
	MAX_SLIME_LEVEL = 100,
	SHINY_CHANCE = 1 / 200,

	PASSIVE_INCOME_INTERVAL = 10,
	EGG_RESPAWN_SECONDS = 45,

	-- Open-world PvP arrives in milestone 2; the shield length is tracked now
	-- so new players already have it when PvP turns on.
	NEW_PLAYER_SHIELD_SECONDS = 30 * 60,
})

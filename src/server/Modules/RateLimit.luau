--!strict
-- Simple per-player cooldown for remote handlers.

local RateLimit = {}

local last: { [Player]: { [string]: number } } = {}

-- Returns true if the call is allowed (and records it).
function RateLimit.allow(player: Player, key: string, cooldown: number): boolean
	local now = os.clock()
	local byKey = last[player]
	if not byKey then
		byKey = {}
		last[player] = byKey
	end
	local previous = byKey[key]
	if previous and now - previous < cooldown then
		return false
	end
	byKey[key] = now
	return true
end

function RateLimit.clear(player: Player)
	last[player] = nil
end

return RateLimit

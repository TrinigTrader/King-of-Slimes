--!strict
-- Per-session state that is NOT saved (lost when the player leaves).

export type State = {
	plotIndex: number?,
	carryingEgg: string?,
	graceUntil: number, -- monsters ignore the player until this time
	teleportedAt: number, -- movement checks skip right after a server teleport
	joinedAt: number,
}

local PlayerState = {}

local states: { [Player]: State } = {}

function PlayerState.get(player: Player): State
	local state = states[player]
	if not state then
		state = {
			plotIndex = nil,
			carryingEgg = nil,
			graceUntil = 0,
			teleportedAt = 0,
			joinedAt = os.clock(),
		}
		states[player] = state
	end
	return state
end

function PlayerState.clear(player: Player)
	states[player] = nil
end

-- Teleport a player's character and tell the movement check to expect it.
function PlayerState.teleport(player: Player, position: Vector3)
	local character = player.Character
	if not character then
		return
	end
	PlayerState.get(player).teleportedAt = os.clock()
	character:PivotTo(CFrame.new(position))
end

function PlayerState.rootPart(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

return PlayerState

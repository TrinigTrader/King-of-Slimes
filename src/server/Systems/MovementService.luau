--!strict
-- Sets each player's WalkSpeed from their upgrades and partner, and pulls
-- back characters that move much faster than their speed allows.

local Players = game:GetService("Players")

local Modules = script.Parent.Parent.Modules
local Stats = require(Modules.Stats)
local PlayerState = require(Modules.PlayerState)

local DataService = require(script.Parent.DataService)

local MovementService = {}

local CHECK_INTERVAL = 0.5
local TOLERANCE = 1.6 -- allow 60% over speed for latency and knockback
local FLAT_ALLOWANCE = 8

local lastPositions: { [Player]: { character: Model, position: Vector3 } } = {}

function MovementService.init() end

function MovementService.start()
	Players.PlayerRemoving:Connect(function(player)
		lastPositions[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for player, profile in DataService.allProfiles() do
				local root = PlayerState.rootPart(player)
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if not root or not humanoid or not character then
					lastPositions[player] = nil
					continue
				end

				local speed = Stats.walkSpeed(profile)
				if humanoid.WalkSpeed ~= speed then
					humanoid.WalkSpeed = speed
				end

				local position = root.Position
				local last = lastPositions[player]
				-- A new character (respawn) starts a fresh track.
				local previous = if last and last.character == character then last.position else nil
				local state = PlayerState.get(player)
				local recentlyTeleported = os.clock() - state.teleportedAt < CHECK_INTERVAL * 2
				if previous and not recentlyTeleported then
					local flat = Vector3.new(position.X - previous.X, 0, position.Z - previous.Z)
					local allowed = speed * CHECK_INTERVAL * TOLERANCE + FLAT_ALLOWANCE
					if flat.Magnitude > allowed then
						-- Too fast: put them back where they were.
						PlayerState.teleport(player, previous + Vector3.new(0, 1, 0))
						position = previous
					end
				end
				lastPositions[player] = { character = character, position = position }
			end
		end
	end)
end

return MovementService

--!strict
-- Holds the latest state snapshot from the server and signals changes.
-- Display only: the server re-checks everything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)

local StateController = {}

StateController.Changed = Signal.new() -- (snapshot)
StateController.Notified = Signal.new() -- (message)
StateController.OpenRequested = Signal.new() -- (uiName)

local current: Types.Snapshot? = nil

function StateController.get(): Types.Snapshot?
	return current
end

function StateController.init()
	Remotes.get("StateChanged").OnClientEvent:Connect(function(snapshot: Types.Snapshot)
		current = snapshot
		StateController.Changed:Fire(snapshot)
	end)
	Remotes.get("Notify").OnClientEvent:Connect(function(message: string)
		StateController.Notified:Fire(message)
	end)
	Remotes.get("OpenUI").OnClientEvent:Connect(function(name: string)
		StateController.OpenRequested:Fire(name)
	end)
end

return StateController

--!strict
-- One registry for every RemoteEvent. The server creates them; clients wait.
--
-- Server -> client: StateChanged(snapshot), Notify(text), OpenUI(name)
-- Client -> server: BuyUpgrade(upgradeId), SetPartner(uid), ReleaseSlime(uid)
-- Every client -> server payload is validated on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type RemoteName =
	"StateChanged"
	| "Notify"
	| "OpenUI"
	| "BuyUpgrade"
	| "SetPartner"
	| "ReleaseSlime"

local NAMES: { RemoteName } =
	{ "StateChanged", "Notify", "OpenUI", "BuyUpgrade", "SetPartner", "ReleaseSlime" }
local FOLDER_NAME = "Remotes"

local Remotes = {}

local function getFolder(): Instance
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			local created = Instance.new("Folder")
			created.Name = FOLDER_NAME
			for _, name in NAMES do
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = created
			end
			created.Parent = ReplicatedStorage
			folder = created
		end
		return folder :: Instance
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

function Remotes.get(name: RemoteName): RemoteEvent
	local remote = getFolder():WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), `{name} is not a RemoteEvent`)
	return remote
end

return Remotes

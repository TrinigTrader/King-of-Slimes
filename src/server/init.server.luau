--!strict
-- King of Slimes server entry point. Two-phase bootstrap: init() every
-- system (create state, connect signals), then start() every system
-- (begin loops, handle players). Systems may require each other directly.

local Systems = script:WaitForChild("Systems")

type System = { init: (() -> ())?, start: (() -> ())? }

local loaded: { [string]: System } = {}
for _, child in Systems:GetChildren() do
	if child:IsA("ModuleScript") then
		loaded[child.Name] = (require :: any)(child) :: System
	end
end

for name, system in loaded do
	local init = system.init
	if init then
		local ok, err = pcall(init :: any)
		if not ok then
			warn(`[Server] {name}.init failed: {err}`)
		end
	end
end

for _, system in loaded do
	if system.start then
		task.spawn(system.start)
	end
end

print("[KingOfSlimes] server started")

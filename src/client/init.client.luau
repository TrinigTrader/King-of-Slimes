--!strict
-- King of Slimes client entry point. Same two-phase bootstrap as the server.

local Controllers = script:WaitForChild("Controllers")

type Controller = { init: (() -> ())?, start: (() -> ())? }

local loaded: { [string]: Controller } = {}
for _, child in Controllers:GetChildren() do
	if child:IsA("ModuleScript") then
		loaded[child.Name] = (require :: any)(child) :: Controller
	end
end

for _, controller in loaded do
	if controller.init then
		controller.init()
	end
end

for _, controller in loaded do
	if controller.start then
		task.spawn(controller.start)
	end
end

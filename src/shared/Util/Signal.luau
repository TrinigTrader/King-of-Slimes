--!strict
-- Minimal signal for server/client modules to talk without BindableEvents.

local Signal = {}
Signal.__index = Signal

type Handler = (...any) -> ()
export type Signal = typeof(setmetatable({} :: { _handlers: { Handler } }, Signal))

function Signal.new(): Signal
	return setmetatable({ _handlers = {} :: { Handler } }, Signal)
end

-- Returns a function that disconnects the handler.
function Signal.Connect(self: Signal, handler: Handler): () -> ()
	table.insert(self._handlers, handler)
	return function()
		local index = table.find(self._handlers, handler)
		if index then
			table.remove(self._handlers, index)
		end
	end
end

function Signal.Fire(self: Signal, ...: any)
	for _, handler in table.clone(self._handlers) do
		task.spawn(handler, ...)
	end
end

return Signal

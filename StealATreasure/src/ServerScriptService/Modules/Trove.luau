--!strict
-- Trove.luau
-- Tracks connections, instances and cleanup functions so they can all be
-- released at once (skill SE-4: never leak connections). One Trove per player.

local Trove = {}
Trove.__index = Trove

export type Trove = typeof(setmetatable({} :: { _items: { any } }, Trove))

function Trove.new(): Trove
	return setmetatable({ _items = {} }, Trove)
end

-- Adds an RBXScriptConnection, Instance, Trove or function and returns it.
function Trove.Add<T>(self: Trove, item: T): T
	table.insert(self._items, item)
	return item
end

function Trove.Connect(self: Trove, signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	return self:Add(signal:Connect(fn))
end

function Trove.Clean(self: Trove)
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		local item = items[i]
		local t = typeof(item)
		if t == "RBXScriptConnection" then
			item:Disconnect()
		elseif t == "Instance" then
			item:Destroy()
		elseif t == "function" then
			task.spawn(item)
		elseif t == "table" and item.Clean then
			item:Clean()
		end
	end
end

return Trove

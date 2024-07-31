--!strict

--[[
	A stack implementation which is really just a table.insert/table.remove wrapper for more standard usage
	E.G. `add` and `get` accessor functions
]]

local mod = { }
local Stack = { }
Stack.__index = { __index = mod }

function Stack:push(item)
	table.insert(self, item)
	return #self
end

function Stack:pop()
	return table.remove(self)
end

function Stack:get(idx)
	assert(typeof(idx) == "number")
	return self[idx]
end

function mod.new()
	local t = { }
	return setmetatable(t, Stack)
end

export type Stack<T> = {
	[number]: T,
	push: (self: Stack<T>, item: T) -> number,
	pop: (self: Stack<T>) -> T,
	get: (self: Stack<T>, idx: number) -> T,
	add: (self: Stack<T>, item: T) -> number,
	remove: (self: Stack<T>, idx: number) -> T
}

-- Support for mixing interfaces
Stack.add = Stack.push
Stack.remove = Stack.pop

function mod.__tests(G, T)
	-- TODO: Tests
--[[ 	T("Simply work", function()
		local t = mod.new()

		local id1 = t:add("test 1")
		local id2 = t:add("test 2")

		local a = t:get(id1)
		local b = t:get(id2)

		T("adding",
			a, "test 1",
			b, "test 2"
		)
	end) ]]

end

return mod
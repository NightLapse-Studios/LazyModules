--!strict

--[[
	A stack implementation which is really just a table.insert/table.remove wrapper for more standard usage
	E.G. `add` and `get` accessor functions
]]

local mod = { }
local mt_Stack = { __index = mod }

function mod:push(item)
	table.insert(self, item)
	return #self
end

function mod:pop()
	return table.remove(self)
end

function mod:get(idx)
	assert(typeof(idx) == "number")
	return self[idx]
end

function mod.new()
	local t = { }
	return setmetatable(t, mt_Stack)
end

-- Support for mixing interfaces
mod.add = mod.push
mod.remove = mod.pop

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
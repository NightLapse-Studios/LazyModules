--!strict

local mod = { }
local mt_IDList = { __index = mod }

local AssociativeList = _G.Game.PreLoad(game.ReplicatedFirst.Util.AssociativeList)

function mod:add(item)
	assert(typeof(item) ~= "number", "Cannot differentiate between numbers and their IDs")

	self.next_id += 1
	self.List:add(self.next_id, item)

	return self.next_id
end

function mod:remove(id_or_item)
	self.List:remove(id_or_item)
end

function mod:get(id_or_item)
	return self.List:get(id_or_item)
end

function mod.new()
	local t = {
		next_id = 0,
		List = AssociativeList.new()
	}
	return setmetatable(t, mt_IDList)
end

function mod:__tests(G, T)
	T:Test("Simply work", function()
		local t = mod.new()

		local id1 = t:add("test 1")
		local id2 = t:add("test 2")

		local a = t:get(id1)
		local b = t:get(id2)

		T:WhileSituation("adding",
			T.Equal, a, "test 1",
			T.Equal, b, "test 2"
		)

		T:ExpectError("adding number values", function()
			t:add(3)
		end)
	end)
end

return mod
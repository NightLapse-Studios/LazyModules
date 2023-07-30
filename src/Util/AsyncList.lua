--!strict

local Globals

--[[

@important, note that
 callbacks will be called the frame after :provide() is called

]]

local mod = { }
local mt_AsyncValue = { __index = mod }
local SparseList

-- @param index_ct the length of the sequence of indexes for the list, f[a][b] is 2 indexes
function mod.new(index_ct: number)
	local t = {
		provided = { },
		awaiting = SparseList.new(),
		__index_ct = index_ct,
	}
	return setmetatable(t, mt_AsyncValue)
end

-- returns if anything is waiting on a value
function mod:is_awaiting()
	return self.awaiting:is_empty() ~= true
end

-- Initializes the indexers and returns the final table
function mod:__fill_indices(target_tbl, indexers, value)
	local t = target_tbl

	if value then
		for i = 1, self.__index_ct do
			local index = indexers[i]

			local a = t[index]
			if not a then
				a = if i ~= self.__index_ct then { } else value
				t[index] = a
			end

			t = a
		end
	end

	return t
end

-- set value to be at the given sequence of indexes
function mod:provide(value: any, ...)
	local indexers = { ... }
	if #indexers ~= self.__index_ct then
		error("Value provided to AsyncValue list has the wrong number of indexers")
	end

	local t = self:__fill_indices(self.provided, indexers, value)
end

function mod:__await(t, index, callback, id)
	local waiting_idx = self.awaiting:insert(id)

	if t[index] == nil then
		task.desynchronize()
		while t[index] == nil do
			task.wait()
			-- print(index)
		end
		task.synchronize()
	end

	if callback then
		callback(t[index])
	end

	self.awaiting:remove(waiting_idx)
end

-- the first paramaters are the sequence of indexes
-- the last paramater is the function to call when the value is provided in the indexes
function mod:get(...)
	local indexers = { ... }
	local callback = table.remove(indexers, #indexers)
	assert(typeof(callback) == "function")

	if #indexers ~= self.__index_ct then
		error("Value provided to AsyncValue list has the wrong number of indexers")
	end

	--Get the last indexable list
	local id = ""
	local t = self.provided
	for i = 1, self.__index_ct - 1 do
		local index = indexers[i]

		if index == nil then
			error("Index can't be nil")
		end

		id = id .. tostring(index)

		local a = t[index]
		if not a then
			a =  { }
			t[index] = a
		end

		t = a
	end

	local co = coroutine.create(mod.__await)
	local succ, ret = coroutine.resume(co, self, t, indexers[#indexers], callback, id)

	if not succ then
		local err = "\nError waiting for Async Value:\n"
		for _, v in indexers do
			err = err .. v
		end

		warn(err, ret)
		warn(debug.traceback())

		return false
	end

	return true
end

-- returns plainly what is stored at the given sequence of indexes
function mod:inspect(...)
	local indexers = { ... }

	local indices = math.min(#indexers, self.__index_ct - 1)

	local exists = true
	local t = self.provided
	for i = 1, indices do
		local index = indexers[i]

		local a = t[index]
		if not a then
			exists = false
			break
		end

		t = a
	end

	return if exists then t[indexers[#indexers]] else nil
end

function mod:remove(...)
	local indexers = { ... }

	local indices = math.min(#indexers, self.__index_ct - 1)

	local exists = true
	local t = self.provided
	for i = 1, indices do
		local index = indexers[i]

		local a = t[index]
		if not a then
			exists = false
			break
		end

		t = a
	end

	if exists then
		t[indexers[#indexers]] = nil
	end
end

function mod:__tests(G, T)
	local async_list = mod.new(1)
	T:Test("Basically work", function()
		async_list:provide(1, "asdf")
		async_list:provide(2, 1)

		T:WhileSituation("inserting",
			T.Equal, async_list.provided["asdf"], 1,
			T.Equal, async_list.provided[1], 2
		)

		local a, b
		async_list:get("asdf", function(v) a = v end)
		async_list:get(1, function(v) b = v end)

		T:WhileSituation("awaiting",
			T.Equal, a, 1,
			T.Equal, b, 2
		)
	end)

	T:Test("Be async", function()
		local a
		async_list:get("zxcv", function(v) a = v end)

		T:WhileSituation("awaiting",
			T.Equal, a, nil
		)

		async_list:provide(45, "zxcv")
		task.desynchronize()
		task.synchronize()

		T:WhileSituation("receiving",
			T.Equal, a, 45
		)
	end)

	T:Test("Fill indices", function()
		local list = mod.new(3)
		list:provide(true, "a", "b", "c")

		T:WhileSituation("constructing",
			T.NotEqual, list.provided.a, nil,
			T.NotEqual, list.provided.a.b, nil,
			T.NotEqual, list.provided.a.b.c, nil
		)
	end)

	T:Test("Support inspection", function()
		local list = mod.new(3)
		list:provide(true, "a", "b", "c")

		T:WhileSituation("reading",
			T.Equal, list:inspect("a", "b", "c"), true
		)

		T:WhileSituation("under-reading",
			T.Equal, list:inspect("a"), nil
		)

		T:WhileSituation("wrong-reading",
			T.Equal, list:inspect("b", "a", "r"), nil
		)
	end)
end

function mod:__init(G)
	Globals = G
	SparseList = require(game.ReplicatedFirst.Util.SparseList)
end

return mod
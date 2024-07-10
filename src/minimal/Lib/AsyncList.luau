--!strict
--!native

--[[

@important, note that
 callbacks will be called the frame after :provide() is called

]]

local SparseList = require(game.ReplicatedFirst.Lib.SparseList)

local mod = { }

local AsyncList = { }
AsyncList.__index = AsyncList

type _provided = {}

export type AsyncList<T> = {
	provided: 		T,
	awaiting: 		SparseList.SparseList,
	__index_ct: 	number,

	is_awaiting: 	(AsyncList<T>) -> boolean,
	provide: 		(AsyncList<T>, value: any, ...any) -> (),
	
	get:			(AsyncList<T>, ...any) -> any?,
	inspect: 		(AsyncList<T>, ...any) -> any?,
	remove: 		(AsyncList<T>, ...any) -> (),
	__fill_indices: (AsyncList<T>, { [any]: any }, { any }, any) -> ({ [any]: any }),
	__await: 		(AsyncList<T>, { }, number, (any) -> (), number) -> (),
}

type indexer_table = { [unknown]: indexer_table }

local function provided_type_factory(index_ct: number)
	local provided_type = { }
	for i = 1, index_ct - 1 do
		-- local a = if i ~= index_ct then { } else (1 :: any)
		local t = { }
		provided_type[1] = t
		provided_type = t
	end

	provided_type[1] = 1 :: any

	return provided_type
end

-- @param index_ct the length of the sequence of indexes for the list, f[a][b] is 2 indexes
-- The number of indices to use is dependent on how you intend to call :provide
function mod.new<T...>(index_ct: number)
	local t = {
		provided = { },
		awaiting = SparseList.new(),
		__index_ct = index_ct,
	}

	setmetatable(t, AsyncList)

	return (t :: any) :: AsyncList<typeof(provided_type_factory(index_ct))>
end

-- returns if anything is waiting on a value
function AsyncList:is_awaiting()
	return self.awaiting:is_empty() ~= true
end

-- Initializes the indexers and returns the final table
function AsyncList:__fill_indices(target_tbl, indexers, value)
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
function AsyncList:provide(value: any, ...)
	local indexers = { ... }
	if #indexers ~= self.__index_ct then
		error("Value provided to AsyncValue list has the wrong number of indexers")
	end

	self:__fill_indices(self.provided, indexers, value)
end

function AsyncList:__await(t, index, callback, id)
	local waiting_idx = self.awaiting:insert(id)

	if t[index] == nil then
		while t[index] == nil do
			task.wait()
			-- print(index)
		end
	end

	if callback then
		callback(t[index])
	end

	self.awaiting:remove(waiting_idx)
end

-- the first paramaters are the sequence of indexes
-- the last paramater is the function to call when the value is provided in the indexes
function AsyncList:get(...)
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

	local co = coroutine.create(AsyncList.__await)
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
function AsyncList:inspect(...)
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

function AsyncList:remove(...)
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

function mod.__tests(G, T)
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
		task.wait()

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

return mod
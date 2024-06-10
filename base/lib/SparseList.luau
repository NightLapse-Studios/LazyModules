--!strict
--!native

local mod = { }
local SparseList = { }
SparseList.__index = SparseList

export type SparseList = {
	Contents: 		{ any },
	insert_stack: 	{ number },

	insert: 		(SparseList, item: any) -> number,
	remove: 		(SparseList, idx: number) -> any,
	find_remove: 	(SparseList, item: any) -> boolean,
	is_empty:		(SparseList) -> boolean,
	dump: 			(SparseList) -> string,
}

function mod.new( opt_len: number? ): SparseList
	local n = {
		Contents = opt_len and table.create(opt_len) or { },
		insert_stack = { }
	}

	setmetatable(n, SparseList)

	return (n :: any):: SparseList
end

local function push_stack(stack, val)
	stack[#stack + 1] = val
end

local function pop_stack(stack): number?
	local len = #stack

	--It's important to allow underflows with this particular stack! Just return nil, though.
	if len == 0 then
		return nil
	end

	local ret = stack[len]
	stack[len] = nil

	return ret
end

function SparseList:insert(item: any): number
	local insert_idx  = (pop_stack(self.insert_stack) or (#self.Contents + 1))
	self.Contents[ insert_idx ] = item

	return insert_idx
end

function SparseList:remove(idx: number): any
	local store = self.Contents[idx]
	
	if store == nil then
		return
	end
	
	push_stack(self.insert_stack, idx)
	self.Contents[idx] = nil
	
	return store
end

function SparseList:find_remove(item: any): boolean
	for i,v in pairs(self.Contents) do
		if v == item then
			self:remove(i)
			return true
		end
	end

	--Wasn't found
	return false
end

function SparseList:is_empty(): boolean
	for _, _ in self.Contents do
		return false
	end

	return true
end

function SparseList:dump()
	local s = ""
	for i,v in self.Contents do
		if v then
			s = s .. "[" .. i .. "] " .. tostring(v) .. "\n"
		end
	end

	return s
end

function mod.newFromList( list: { any } ): SparseList
	local n = {
		Contents = list,
		insert_stack = { }
	}

	setmetatable(n, SparseList)

	return (n :: any) :: SparseList
end

function mod.__tests(G, T)
	local a,s,d,f,g = 1,2,3,4,5
	local function generic_psa()
		local psa = mod.new(16)
		psa:insert(a)
		psa:insert(s)
		psa:insert(d)
		psa:insert(f)
		psa:insert(g)

		return psa
	end

	T:Test("Insert and remove items", function()
		local psa = generic_psa()

		T:WhileSituation( "inserting",
			T.Equal, psa.Contents[1], a,
			T.Equal, psa.Contents[2], s,
			T.Equal, psa.Contents[3], d,
			T.Equal, psa.Contents[4], f,
			T.Equal, psa.Contents[5], g
		)

		psa:remove(2)
		
		T:WhileSituation( "removing",
			T.Equal, psa.Contents[1], a,
			T.Equal, psa.Contents[2], nil,
			T.Equal, psa.Contents[3], d,
			T.Equal, psa.Contents[4], f,
			T.Equal, psa.Contents[5], g
		)

		psa:find_remove(f)
		
		T:WhileSituation( "search-removing",
			T.Equal, psa.Contents[1], a,
			T.Equal, psa.Contents[2], nil,
			T.Equal, psa.Contents[3], d,
			T.Equal, psa.Contents[4], nil,
			T.Equal, psa.Contents[5], g
		)
	end)

	T:Test("Know if it's empty", function()
		local psa = generic_psa()

		T:WhileSituation( "inserting",
			T.Equal, psa:is_empty(), false
		)

		psa:remove(1)
		psa:remove(2)
		psa:remove(3)
		psa:remove(4)
		psa:remove(5)

		T:WhileSituation( "removing",
			T.Equal, psa:is_empty(), true
		)

	end)

	T:Test("Format and dump its contents", function()
		local psa = generic_psa()

		T:WhileSituation( "full",
			T.Equal, psa:dump(), "[1] 1\n[2] 2\n[3] 3\n[4] 4\n[5] 5\n"
		)
	end)
end

return mod
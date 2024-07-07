
local rshift = bit32.rshift
local Table = {}


function Table.RemoveDuplicates(tbl)
	local hash = {}
	local res = {}
	local Increment = 0
	for _,v in pairs(tbl) do
		if (not hash[v]) then
			Increment += 1
			res[Increment] = v
			hash[v] = true
		end
	end

	return res
end

function Table.AreTablesValuesTheSame(...)-- returns true if all tables values are the same, but can be in a different order.
	local tbs = {...}
	local initialtb = tbs[1]
	tbs[1] = nil

	local length = #initialtb
	for i,v in pairs(tbs) do
		if #v ~= length then
			return false
		end
	end

	local hash = {}
	for i,v in pairs(initialtb) do
		hash[v] = (hash[v] or 0) + 1
	end

	for _,tb in pairs(tbs) do
		local nhash = {}
		for _, v in pairs(tb) do
			if not hash[v] then
				return false
			end
			local next = (nhash[v] or 0) + 1
			nhash[v] = next
			if next > hash[v] then
				return false
			end
		end

		for i,v in pairs(nhash) do
			if hash[i] ~= v then
				return false
			end
		end
	end

	return true
end

function Table.Duplicate(tbl)
	local t = {}
	for i,v in pairs(tbl)do
		t[i] = v
	end
	return t
end

function Table.DeepDuplicate(tbl, seen)
	-- Handle non-tables and previously-seen tables.
	if type(tbl) ~= 'table' then return tbl end
	if seen and seen[tbl] then return seen[tbl] end

	-- New table; mark it as seen and copy recursively.
	local s = seen or {}
	local res = {}
	s[tbl] = res
	for k, v in pairs(tbl) do res[Table.DeepDuplicate(k, s)] = Table.DeepDuplicate(v, s) end
	return setmetatable(res, getmetatable(tbl))
end

function Table.DuplicateChange(table, overwrites)
	local tbl = Table.Duplicate(table)
	for i,v in pairs(overwrites) do
		tbl[i] = v
	end
	return tbl
end

function Table.Reverse(tbl)
	for i = 1, rshift(#tbl, 1) do
		local tmp = tbl[i]
		tbl[i] = tbl[#tbl - i + 1]
		tbl[#tbl - i + 1] = tmp
	end
end

function Table.Shuffle(tbl)
	for i = #tbl, 2, -1 do
		local j = math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
end

function Table.IsArray(tbl)
	local i = 0
	for _ in pairs(tbl) do
		i += 1
		if tbl[i] == nil then
			return false
		end
	end
	return true
end

function Table.GetOrderedIndex(array, value, comp)
	local low = 1
	local high = #array

	while low <= high do
		local mid = rshift(low + high, 1)
		if comp(array[mid], value) then
			low = mid + 1
		else
			high = mid - 1
		end
	end
	return low
end

function Table.Chunk(tbl, size)
	local chunked_arr = {}
	for _,v in pairs(tbl)do
		local clen = #chunked_arr
		local last = chunked_arr[clen]
		if not last or #last == size then
			chunked_arr[clen + 1] = {v}
		else
			last[#last + 1] = v
		end
	end
	return chunked_arr
end

function Table.GetTableSize(tbl)
	local c = 0
	for _,_ in pairs(tbl) do
		c += 1
	end
	return c
end

function Table.IsTableEmpty(tbl)
	for _,_ in pairs(tbl) do
		return false
	end
	return true
end

function Table.RandomHashIdx( hashTable )
    local choice = ""
    local n = 0
    for i, _ in pairs(hashTable) do
        n = n + 1
        if math.random() < (1/n) then
            choice = i
        end
    end
    return choice
end
function Table.RandomHashValue( hashTable )
	return hashTable[Table.RandomHashIdx(hashTable)]
end

function Table.GetAlphabetIdx(tbl)
	local a = {}
	for i,_ in pairs(tbl) do
		a[#a + 1] = i
	end
	table.sort(a, function(a,b)return a < b end)
	return a[1]
end

function Table.AppendNew(t1, t2)
	local new = {}
	local length = #t1
	for i = 1, length do
		new[i] = t1[i]
	end
	for i = 1, #t2 do
		new[length + i] = t2[i]
	end
	return new
end

function Table.Clear(Tbl)
	for i,_ in pairs(Tbl) do
		Tbl[i] = nil
	end
end
Table.Clear2 = table.clear

function Table.Max(Tbl, compute)
	local values
	
	if compute then
		values = {}
		for i, v in Tbl do
			local value = compute(i, v)
			values[i] = value
		end
	else
		values = Tbl
	end
	
	local maxIndex, maxV
	local maxValue
	
	for i, v in Tbl do
		local value = values[i]
		
		if (maxValue == nil) or value > maxValue then
			maxValue = value
			
			maxIndex = i
			maxV = v
		end
	end
	
	return maxV, maxValue, maxIndex
end

function Table.Min(Tbl, compute)
	local values
	
	if compute then
		values = {}
		
		for i, v in values do
			local value = compute(i, v)
			values[i] = value
		end
	else
		values = Tbl
	end
	
	local minIndex, minV
	local minValue
	
	for i, v in Tbl do
		local value = values[i]
		
		if (minValue == nil) or value < minValue then
			minValue = value
			
			minIndex = i
			minV = v
		end
	end
	
	return minV, minValue, minIndex
end

return Table
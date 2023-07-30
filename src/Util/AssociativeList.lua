--!strict

local mod = { }
local mt_AssociativeList = { __index = mod }

function mod:add(a, b)
	self.size += 1
	self._a[a] = b
	self._b[b] = a
end

function mod:remove(a_or_b)
	local a1, l1 = self:get(a_or_b)
	local a2, l2 = self:get(a1)
	l1[a_or_b] = nil
	l2[a2] = nil
	self.size -= 1
end

function mod:get(a_or_b)
	local a, b = self._a[a_or_b], self._b[a_or_b]

	if a and b then
		-- wtf you did???
		warn("Associative table has data on both ends of the association `" .. a_or_b .. "`")
	end

	if a then return a, self._a else return b, self._b end
end

-- TODO: Figure out naming scheme for these that is more intuitive
-- You basically have to look at the source here to see which list is returned
function mod:get_associated_list(a_or_b)
	local a, b = self._a[a_or_b], self._b[a_or_b]

	if a and b then
		-- wtf you did???
		warn("Associative table has data on both ends of the association `" .. a_or_b .. "`")
	end

	if a then return self._a else return self._b end
end
function mod:get_other_associated_list(a_or_b)
	local a, b = self._a[a_or_b], self._b[a_or_b]

	if a and b then
		-- wtf you did???
		warn("Associative table has data on both ends of the association `" .. a_or_b .. "`")
	end

	if a then return self._a else return self._b end
end

function mod.new()
	local t = {
		size = 0,
		_a = { },
		_b = { }
	}
	return setmetatable(t, mt_AssociativeList)
end

return mod
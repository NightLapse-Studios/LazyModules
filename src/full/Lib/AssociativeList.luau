--!strict
--!native

local mod = { }
local AssociativeList = {}
AssociativeList.__index = AssociativeList

export type AssociativeList<T, R> = {
	add: (self: AssociativeList<T, R>, a: T, b: R) -> (),
	remove: (self: AssociativeList<T, R>, a_or_b: T | R) -> (),
	get: (self: AssociativeList<T, R>, a_or_b: T | R) -> (T | R),
	get_associated_list: (self: AssociativeList<T, R>, a_or_b: T | R) -> { [T]: R } | { [R]: T },
	size: number,
	_a: { [T]: R },
	_b: { [R]: T },
}

function AssociativeList:add(a, b)
	self.size += 1
	self._a[a] = b
	self._b[b] = a
end

function AssociativeList:remove(a_or_b)
	local a1, l1 = self:get(a_or_b)
	local a2, l2 = self:get(a1)
	l1[a_or_b] = nil
	l2[a2] = nil
	self.size -= 1
end

function AssociativeList:get(a_or_b)
	local a, b = self._a[a_or_b], self._b[a_or_b]

	if a and b then
		-- wtf you did???
		warn("Associative table has data on both ends of the association `" .. a_or_b .. "`")
	end

	if a then return a, self._a else return b, self._b end
end

-- TODO: Figure out naming scheme for these that is more intuitive
-- You basically have to look at the source here to see which list is returned
function AssociativeList:get_associated_list(a_or_b)
	local a, b = self._a[a_or_b], self._b[a_or_b]

	if a and b then
		-- wtf you did???
		warn("Associative table has data on both ends of the association `" .. a_or_b .. "`")
	end

	if a then return self._a else return self._b end
end
function AssociativeList:get_other_associated_list(a_or_b)
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
	return setmetatable(t, AssociativeList)
end

return mod

local rshift = bit32.rshift

local Range = { }

function Range:add(thing, weight)
	if weight == 0.0 then
		return
	end

	self.Len += 1

	local entry = {
		Thing = thing,
		Weight = weight,
		CumulativeWeight = self.Total
	}

	self[#self + 1] = entry
	self.Total = self.Total + weight

	return self
end

--Takes in an **array-like** table as thing-and-weight pairs
function Range:addMultiple(tbl)
	for i = 1, #tbl, 2 do
		assert(tbl[i + 1])

		local entry = tbl[i]
		self:add(entry, tbl[i + 1])
	end

	--For some nice syntactic sugar like: ThisRange = ProbabilityRange.new():addMultiple({1, 2, 2, 10})
	return self
end

function Range:remove(thing, removal_weight)
	for i = 1, #self, 1 do
		local entry = self[i]
		if entry.Thing == thing then
			--remove partial weight or full weight
			local adjustment = removal_weight or entry.Weight
			entry.Weight -= adjustment
			self.Total -= adjustment

			for j = i + 1, #self, 1 do
				self[j].CumulativeWeight -= adjustment
			end

			if entry.Weight <= 0 then
				table.remove(self, i)
				self.Len -= 1
			end

			return
		end
	end
end

function Range:getRandom()
	local targetWeight = math.random()
	targetWeight = targetWeight * self.Total

	--Binary Search
	local L = 1
	local R = self.Len
	while true do
		if L > R then
			--Should be literally impossible
			warn("Probability range appears to be empty")
			warn(debug.traceback())
			return nil
		end

		local curIdx = rshift((L + R), 1)
		local this = self[curIdx]
		local othis = self[curIdx + 1]

		if this.CumulativeWeight < targetWeight then
			if othis == nil or othis.CumulativeWeight > targetWeight then
				return this.Thing
			else
				L = curIdx + 1
				continue
			end
		elseif this.CumulativeWeight > targetWeight then
			R = curIdx - 1
			continue
		else
			return this.Thing
		end
	end
end

--[[
	This is only used for tests!
	]]--
function Range:getAtWeight(targetWeight)

	--Binary Search
	local L = 1
	local R = self.Len
	while true do
		if L > R then
			--Should be literally impossible
			return -1
		end

		local curIdx = rshift((L + R), 1)
		local this = self[curIdx]
		local othis = self[curIdx + 1]

		if this.CumulativeWeight < targetWeight then
			if othis == nil or othis.CumulativeWeight > targetWeight then
				return this.Thing
			else
				L = curIdx + 1
				continue
			end
		elseif this.CumulativeWeight > targetWeight then
			R = curIdx - 1
			continue
		else
			return this.Thing
		end
	end
end



function Range.new(): FPR
	local range = {
		Total = 0.0,
		Len = 0
	}
	setmetatable(range, Range)

	return range
end

local function add_ranges(r1: FPR, r2: FPR)
	local r3 = Range.new()

	for i = 1, #r1, 1 do
		r3:add(r1[i].Thing, r1[i].Weight)
	end
	for i = 1, #r2, 1 do
		r3:add(r2[i].Thing, r2[i].Weight)
	end

	return r3
end

Range.__index = Range
Range.__add = add_ranges

return Range

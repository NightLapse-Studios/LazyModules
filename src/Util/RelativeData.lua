
local RD = {}
RD.__index = RD

-- for edges, you pass an array where pairs of 2 are opposites and it goes clockwise. EX:
--{front, back, right, left}

function RD.new(name, edges)
	local newRD = {}
	setmetatable(newRD, RD)

	newRD.Edges = edges
	newRD.Hash = {}
	for i,v in pairs(edges)do
		newRD.Hash[v] = i
	end
	newRD.ClockWiseV = newRD:GetClockWiseVersion()
	newRD.CWHash = {}
	for i,v in pairs(newRD.ClockWiseV)do
		newRD.CWHash[v] = i
	end
	newRD.CounterClockWiseV = newRD:GetCounterClockWiseVersion()
	newRD.CCWHash = {}
	for i,v in pairs(newRD.CounterClockWiseV)do
		newRD.CCWHash[v] = i
	end

	RD[name] = newRD

	return newRD
end

function RD:Opposite(data)
	local dataidx = self.Hash[data]
	if dataidx % 2 == 0 then
		return self.Edges[dataidx - 1]
	else
		return self.Edges[dataidx + 1]
	end
end

function RD:ClockWise(data)
	local idx = self.Hash[data]
	if idx >= #self.Edges - 1 then
		return self:Wrap(data)
	else
		return self.Edges[idx + 2]
	end
end

function RD:CounterClockWise(data)
	local idx = self.Hash[data]
	if idx <= 2 then
		return self:Wrap(data)
	else
		return self.Edges[idx - 2]
	end
end

function RD:Wrap(data)
	local idx = self.Hash[data]
	return self.Edges[#self.Edges - idx + 1]
end

function RD:GetClockWiseVersion(data_start)
	data_start = data_start or self.Edges[1]
	local cwv = {data_start}
	local i = self.Hash[data_start]
	for _ = 1, #self.Edges - 1 do
		local nex = self:ClockWise(self.Edges[i])
		cwv[#cwv + 1] = nex
		i = self.Hash[nex]
	end
	return cwv
end

function RD:GetCounterClockWiseVersion(data_start)
	data_start = data_start or self.Edges[1]
	local cwv = {data_start}
	local i = self.Hash[data_start]
	for _ = 1, #self.Edges - 1 do
		local nex = self:CounterClockWise(self.Edges[i])
		cwv[#cwv + 1] = nex
		i = self.Hash[nex]
	end
	return cwv
end

function RD:GetRotatedVersion(deg, edges, counterclockwise)
	--360, -270, -180, -90
	-- 0,   90,   180, 270

	if deg < 0 then
		deg += 360
	end

	local offset = (deg / 45 + 1) % 8
	if counterclockwise then
		return self:GetCounterClockWiseVersion(edges[offset])
	else
		return self:GetClockWiseVersion(edges[offset])
	end
end

return RD
--[[
for all to work as expected, pass the edges data in pairs of opposites
"left", "right", "top", "bottom"
]]
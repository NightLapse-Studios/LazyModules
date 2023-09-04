--!strict

--[[
	An early mockup of an idea for a buffer of text output as an alternative to just printing to console
	This way server logs of some sort can be sent to e.g. discord on error
]]

local mod = { }
local CircleBuffer

local Buffers = { }

local function new_log_group(name)
	local t = { }
	Buffers[name] = t
	return t
end


function mod.DumpGroup(group_name)
	local group = Buffers[group_name]
	for i = 1, #group do
		print(group[i])
	end
end

function mod.SerializeGroup(group_name)
	local group = Buffers[group_name]
	local ret = ""
	for i = #group, 1, -1 do
		ret = ret .. group[i] .. "\n"
	end

	return ret
end
function mod.SerializeGroupUntilLen(group_name, len)
	local group = Buffers[group_name]
	local ret = ""
	for i = #group, 1, -1 do
		ret = ret .. group[i] .. "\n"
		if string.len(ret) >= len then
			break
		end
	end

	return ret
end

function mod.Log(group_name, message)
	local group = Buffers[group_name] or new_log_group(group_name)
	table.insert(group, message)
end

function mod:__init(G)
	CircleBuffer = G.Load("CircleBuffer")
end

return mod
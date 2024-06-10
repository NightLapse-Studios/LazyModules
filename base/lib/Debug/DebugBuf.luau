local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local LogBufRemoteEvent

local mod = { }

local Buffers = { }

local MAX_LOGS = 100

local function new_log_group(name)
	local t = {
		Name = name,
	}
	Buffers[name] = t
	return t
end

local logMeta = {
	__tostring = function(self)
		return string.format("[%d : %.10f] %s: %s\n%s", self.Order, self.Timestamp, self.Context, self.Message, self.Traceback)
	end
}

local function add_log(group, message, context, timestamp, traceback)
	if #group >= MAX_LOGS then
		table.remove(group, 1)
	end
	
	local log = setmetatable({
		Order = #group + 1,
		Message = message,
		Context = context,
		Timestamp = timestamp,
		Traceback = traceback,
		
		_delivered = false,
	}, logMeta)
	
	table.insert(group, log)
	
	if LogBufRemoteEvent and not IsServer then
		log._delivered = true
		LogBufRemoteEvent:FireServer(group.Name, message, timestamp, traceback)
	end
end

-- raw functions
function mod.DumpGroup(group_name)
	local group = Buffers[group_name]
	for i = 1, #group do
		print(tostring(group[i]))
	end
end

function mod.SerializeGroup(group_name, sort, isolate_player)
	local group = Buffers[group_name]
	
	local tbl = {}
	for i = 1, #group do
		tbl[i] = group[i]
	end
	
	if isolate_player then
		for i = #tbl, 1, -1 do
			if tbl[i].Context ~= "CLIENT: [" .. isolate_player.Name .. "]" then
				table.remove(tbl, i)
			end
		end
	end
	
	if sort then
		table.sort(tbl, function(a, b)
			return a.Timestamp < b.Timestamp
		end)
	end
	
	
	local ret = ""
	for i = 1, #tbl do
		ret = ret .. tostring(tbl[i]) .. "\n"
	end

	return ret
end

function mod.SerializeGroupUntilLen(group_name, len)
	local group = Buffers[group_name]
	local ret = ""
	for i = 1, #group do
		ret = ret .. tostring(group[i]) .. "\n"
		if string.len(ret) >= len then
			break
		end
	end

	return ret
end


-- Both of these functions work on the client and server.
-- if used on the client, it will apply it on the server as well.
function mod.GroupWarn(group_name, isolate_player)
	if IsServer then
		local str = mod.SerializeGroup(group_name, true, isolate_player)
		
		warn(group_name .. "\n" .. str)
	elseif LogBufRemoteEvent then
		LogBufRemoteEvent:FireServer(group_name, nil, nil, nil)
	else
		Buffers[group_name]._groupWarnPending = true
	end
end

function mod.Log(group_name, message, _clientPacket)
	local group = Buffers[group_name] or new_log_group(group_name)
	
	local context
	local timestamp
	local traceback
	
	if _clientPacket then
		context = "CLIENT: [" .. _clientPacket[1].Name .. "]"
		timestamp = _clientPacket[2]
		traceback = _clientPacket[3]
	else
		context = IsServer and "SERVER" or "CLIENT"
		timestamp = workspace:GetServerTimeNow()
		traceback = debug.traceback()
	end
	
	add_log(group, message, context, timestamp, traceback)
end

function mod.ListGroups()
	print("-- Listing Debug Groups --\n")
	for name, list in Buffers do
		print(name)
	end
	print("\n")
end

if IsServer then
	LogBufRemoteEvent = Instance.new("RemoteEvent", game.ReplicatedStorage)
	LogBufRemoteEvent.Name = "LogBufRemoteEvent"
	
	LogBufRemoteEvent.OnServerEvent:Connect(function(plr, group_name, message, timestamp, traceback)
		if message == nil and timestamp == nil and traceback == nil then
			mod.GroupWarn(group_name, plr)
		else
			mod.Log(group_name, message, {plr, timestamp, traceback })
		end
	end)
else
	task.spawn(function()
		LogBufRemoteEvent = game.ReplicatedStorage:WaitForChild("LogBufRemoteEvent")
		for name, list in Buffers do
			for i = 1, #list do
				local log = list[i]
				if not log._delivered then
					log._delivered = true
					LogBufRemoteEvent:FireServer(name, log.Message, log.Timestamp, log.Traceback)
				end
			end
			
			if list._groupWarnPending then
				list._groupWarnPending = false
				LogBufRemoteEvent:FireServer(name, nil, nil, nil)
			end
		end
	end)
end

return mod
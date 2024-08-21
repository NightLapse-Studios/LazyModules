--!strict

local RS = game:GetService("RunService")
local Players = game:GetService("Players")

export type Queue = { [string]: { any } }
export type QueueStruct = {
	[Player | "All"]: Queue
}


local Queue: QueueStruct = { }
local mod = { }

local function NewQueue()
	return { } :: Queue
end

if RS:IsServer() then
	Players.PlayerAdded:Connect(function(plr)
		if Queue[plr] then
			return
		end

		Queue[plr] = NewQueue()
	end)

	Players.PlayerRemoving:Connect(function(plr)
		Queue[plr] = nil
	end)

	for i,v in Players:GetPlayers() do
		if not Queue[v] then
			Queue[v] = NewQueue()
		end
	end
else
	Queue[Players.LocalPlayer] = NewQueue()
end

function mod.Submit(plr: Player | "All", event_name: string, ...)
	if not Queue[plr] then
		warn("Event submitted before Queue exists for player " .. plr.Name .. " " .. plr.UserId)
	end

	if plr == "All" then
		for i,v in Queue do
			v[event_name] = v[event_name] or { }
			table.insert(v[event_name], { ... })
		end
	else
		local queue = Queue[plr]
		queue[event_name] = queue[event_name] or { }
		table.insert(queue[event_name], { ... })
	end
end

function mod.GetFromPlayer(plr: Player | "All")
	return Queue[plr]
end

function mod.GetQueue()
	return Queue
end

function mod.Clear(plr: Player)
	Queue[plr] = NewQueue()
end

return mod
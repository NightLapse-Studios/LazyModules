local Players = game:GetService("Players")
local IsServer = game:GetService("RunService"):IsServer()

local Config = require(game.ReplicatedFirst.Config)

local mod = { }

local Game
function mod.GiveGame(G)
	Game = G
end


local RemoteEventClass = {}
RemoteEventClass.__index = RemoteEventClass

function RemoteEventClass.new(event)
	return setmetatable({
		Event = event,
		OnServerEvent = event.OnServerEvent,
		OnClientEvent =  event.OnClientEvent
	}, RemoteEventClass)
end

function RemoteEventClass:FireClient(plr, ...)
	if Config.ReleaseType == "full" then
		if Game.LoadedPlayers[plr] then
			self.Event:FireClient(plr, ...)
		end
	else
		self.Event:FireClient(plr, ...)
	end
end

function RemoteEventClass:FireAllClients(...)
	for _, plr in Players:GetPlayers() do
		self:FireClient(plr, ...)
	end
end


function mod.wrapper(identifier: string)
	-- TODO: check that all events made on the server are also made on the client
	local wrapper
	if IsServer then
		local remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = identifier
		remoteEvent.Parent = game.ReplicatedStorage
		
		wrapper = {
			Event = remoteEvent,
		}
	else
		local event = game.ReplicatedStorage:WaitForChild(identifier, 4)
		
		if not event then
			error("Waiting for event timed out! - " .. identifier)
		end
		
		wrapper = {
			Event = event,
		}
	end

	return wrapper
end

return mod
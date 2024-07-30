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
	if Config.ReleaseType == "full" and (Game[plr] and Game[plr].ServerLoaded) then
		self.Event:FireClient(plr, ...)
	end
end

function RemoteEventClass:FireAllClients(...)
	for _, plr in Players:GetPlayers() do
		self:FireClient(plr, ...)
	end
end


function mod.wrapper<T>(identifier: string, builder_mt: T)
	-- TODO: check that all events made on the server are also made on the client
	local wrapper
	if IsServer then
		local remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = identifier
		remoteEvent.Parent = game.ReplicatedStorage
		
		wrapper = setmetatable(
			{
				Event = RemoteEventClass.new(remoteEvent),
				Name = identifier
			},
			builder_mt
		)
	else
		local event = game.ReplicatedStorage:WaitForChild(identifier, 4)
		
		if not event then
			-- By this point LM should exist
			warn("Waiting for event timed out! - " .. identifier .. "\n" .. _G.Game.LazyModules.format_lazymodules_traceback())
		end
		
		wrapper = setmetatable(
			{
				Event = { Event = event },
				Name = identifier
			},
			builder_mt
		)
	end

	return wrapper
end

return mod
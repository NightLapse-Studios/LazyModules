local Players = game:GetService("Players")
local IsServer = game:GetService("RunService"):IsServer()

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
	if Game[plr] and Game[plr].ServerLoaded then
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
	local transmitter
	if IsServer then
		local remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = identifier
		remoteEvent.Parent = game.ReplicatedStorage
		
		transmitter = setmetatable(
			{
				Event = RemoteEventClass.new(remoteEvent),
				Configured = {
					Server = false,
					Client = false,
				},
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
		
		transmitter = setmetatable(
			{
				Event = event,
				Configured = {
					Server = false,
					Client = false,
				},
				Name = identifier
			},
			builder_mt
		)
	end

	return transmitter
end

return mod
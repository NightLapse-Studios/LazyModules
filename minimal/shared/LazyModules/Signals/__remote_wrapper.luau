local Players = game:GetService("Players")
local IsServer = game:GetService("RunService"):IsServer()

local mod = { }

local Game
<<<<<<< Updated upstream:minimal/shared/LazyModules/Signals/__remote_wrapper.lua
=======
function mod.GiveGame(G)
	Game = G
end
>>>>>>> Stashed changes:src/Util/LazyModules/Signals/__remote_wrapper.lua

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
	self.Event:FireClient(plr, ...)
end

function RemoteEventClass:FireAllClients(...)
	for _, plr in Players:GetPlayers() do
		self.Event:FireClient(plr, ...)
	end
end


function mod.wrapper<T>(identifier: string, signal_mt: T)
	-- TODO: check that all events made on the server are also made on the client
	local transmitter
	local event
	if IsServer then
		event = Instance.new("RemoteEvent")
		event.Name = identifier
		event.Parent = game.ReplicatedStorage
	else
		event = game.ReplicatedStorage:WaitForChild(identifier, 4)
		
		if not event then
			-- By this point LM should exist
			warn("Waiting for event timed out! - " .. identifier .. "\n" .. _G.Game.LazyModules.format_lazymodules_traceback())
		end
		
	end
	
	transmitter = setmetatable(
		{
			RemoteEventClass.new(event),
			Configured = {
				Server = false,
				Client = false,
			},
			Name = identifier
		},
		signal_mt
	)

	return transmitter
end

function mod.GiveGame(G)
	Game = G
end

return mod
--!strict

--[[
	Broadcasters:

	Broadcasters bring fire-and-forget to cross-client events.
	When the client does something (that the server must typically validate) which will affect other clients,
		the Broadcaster pattern allows you to call `Broadcast` on the server and client. The client behavior will just
		fire server, but the server behavrio will replicate to all clients except for the one supplied in the first argument
		(same as typical RemoteEvents)

	Single-file networking design is much easier given the accompanying Builder functions which can each be used on
		client and server.

	Search `NewBroadcaster` for example patterns in other modules
]]
local async_list = require(game.ReplicatedFirst.Lib.AsyncList)

local mod = {
	Broadcasters = {
		Identifiers = async_list.new(1),
		Modules = async_list.new(2),
	}
}

local Broadcasters = mod.Broadcasters

--local INIT_CONTEXT = if game:GetService("RunService"):IsServer()  then "SERVER" else "CLIENT"

local ClassicSignal = require(game.ReplicatedFirst.Lib.ClassicSignal)

local IsServer = game:GetService("RunService"):IsServer()

local remote_wrapper = require(script.Parent.__remote_wrapper).wrapper

-- Rare case of inheritance in the wild
local BroadcastBuilder = {
	Type = "Builder",

	ClientConnection = function(self, func: CGameEventConnection)
		if not func then return self end
		if IsServer then return self end

		self.Configured.Client = true
		self.Connections += 1
		self[2]:Connect(func)

		return self
	end,

	ServerConnection = function(self, func: SGameEventConnection)
		if not func then return self end
		if not IsServer then return self end

		self.Configured.Server = true
		self.Connections += 1
		self[2]:Connect(func)

		return self
	end,

	ShouldAccept = function(self, func)
		if typeof(func) ~= "function" then
			error("Missing func for Broadcaster")
		end

		self.__ShouldAccept = func
		return self
	end,

	Build = function(self)
		if IsServer then
			self.Event.Event.OnServerEvent:Connect(function(plr, ...)
				local should_accept = self.__ShouldAccept(plr, ...)

				if should_accept then
					print(debug.traceback())
					self[2]:Fire(plr, ...)

					for i,v in game.Players:GetPlayers() do
						if v == plr then continue end
						self.Event:FireClient(v, plr, ...)
					end
				end
			end)
		else
			self.Event.Event.OnClientEvent:Connect(function(plr, ...)
				self[2]:Fire(plr, ...)
			end)
		end
	end
}

local BroadcasterClient = {
	Broadcast = function(self, ...)
		if self.monitor then
			self.monitor(self, ...)
		end

		self.Event.Event:FireServer(...)
	end
}
local BroadcasterServer = {
	Broadcast = function(self, ...)
		if self.monitor then
			self.monitor(self, ...)
		end

		self[2]:Fire(nil, ...)
		self.Event.Event:FireAllClients(nil, ...)
	end,
	BroadcastLikePlayer = function(self, plr, ...)
		if self.monitor then
			self.monitor(self, ...)
		end

		self[2]:Fire(plr, ...)
		self.Event.Event:FireAllClients(plr, ...)
	end,
}

setmetatable(BroadcasterClient, { __index = BroadcastBuilder })
setmetatable(BroadcasterServer, { __index = BroadcastBuilder })

local mt_BroadcastBuilder = {__index = BroadcastBuilder}
mod.client_mt = {__index = BroadcasterClient}
mod.server_mt = {__index = BroadcasterServer}

local function default_should_accept()
	return true
end

-- Broadcasters use a client->server?->all-clients model
function mod.NewBroadcaster(signals_module, identifier: string): Broadcaster
	local broadcaster = remote_wrapper(identifier, mt_BroadcastBuilder)
	broadcaster[2] = ClassicSignal.new()
	broadcaster.Connections = 0
	broadcaster.__ShouldAccept = default_should_accept
	setmetatable(broadcaster, mt_BroadcastBuilder)

	if Broadcasters.Identifiers:inspect(identifier) ~= nil then
		error("Re-declared broadcaster `" .. identifier .. "` in `" .. signals_module.CurrentModule .. "`")
	end

	Broadcasters.Identifiers:provide(broadcaster, identifier)
	Broadcasters.Modules:provide(broadcaster, signals_module.CurrentModule, identifier)

	return broadcaster
end

export type Broadcaster = typeof(mod.NewBroadcaster({CurrentModule=""}, "Ex"))

return mod
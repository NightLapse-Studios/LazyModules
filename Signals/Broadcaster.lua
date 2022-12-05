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

local mod = {
	Broadcasters = {
		Identifiers = { },
		Modules = { }
	}
}

local Broadcasters = mod.Broadcasters

--local INIT_CONTEXT = if game:GetService("RunService"):IsServer()  then "SERVER" else "CLIENT"

local Globals
local LazyString
local unwrap_or_warn
local unwrap_or_error
local safe_require

local IsServer = game:GetService("RunService"):IsServer()

local Players = game.Players

local remote_wrapper = require(script.Parent.__remote_wrapper)

-- Rare case of inheritance in the wild
local BroadcastBuilder = {
	Type = "Builder",

	ClientConnection = function(self, func: CGameEventConnection)
		if not func then return self end
		if IsServer then return self end

		self.Configured.Client = true
		self.Connections += 1
		self[2].Event:Connect(func)

		return self
	end,

	ServerConnection = function(self, func: SGameEventConnection)
		if not func then return self end
		if not IsServer then return self end

		self.Configured.Server = true
		self.Connections += 1
		self[2].Event:Connect(func)

		return self
	end,

	ShouldAccept = function(self, func)
		unwrap_or_error(
			typeof(func) == "function",
			"Missing func for Broadcaster"
		)
		self.__ShouldAccept = func
		return self
	end,

	Build = function(self)
		if IsServer then
			self[1].OnServerEvent:Connect(function(plr, ...)
				local should_accept = self.__ShouldAccept(plr, ...)

				if should_accept then
					self[2]:Fire(plr, ...)
				end
			end)
		else
			self[1].OnClientEvent:Connect(function(plr, ...)
				self[2]:Fire(plr, ...)
			end)
		end
	end
}

local BroadcasterClient = {
	Broadcast = function(self, ...)
		self[1]:FireServer(...)
	end
}
local BroadcasterServer = {
	Broadcast = function(self, ...)
		self[2]:Fire(...)
		self[1]:FireAllClients(...)
	end,
}

local mt_BroadcastBuilder = {__index = BroadcastBuilder}
mod.client_mt = {__index = BroadcasterClient}
mod.server_mt = {__index = BroadcasterServer}

-- Broadcasters use a client->server?->all-clients model
function mod.NewBroadcaster(self: Builder, identifier: string)
	local broadcaster = remote_wrapper(identifier, mt_BroadcastBuilder)
	broadcaster[2] = Instance.new("BindableEvent")
	broadcaster.Connections = 0
	broadcaster.__ShouldAccept = false
	setmetatable(broadcaster, mt_BroadcastBuilder)

	Broadcasters[self.CurrentModule] = Broadcasters[self.CurrentModule] or { }

	unwrap_or_error(
		Broadcasters.Identifiers[identifier] == nil,
		"Re-declared broadcaster `" .. identifier .. "` in `" .. self.CurrentModule .. "`"
	)

	local Modules = Broadcasters.Modules
	Modules[self.CurrentModule] = Modules[self.CurrentModule] or { }

	Broadcasters.Identifiers[identifier] = broadcaster
	Modules[self.CurrentModule][identifier] = broadcaster

	return broadcaster
end

function mod:__init(G)
	Globals = G

	--The one true require tree
	safe_require = require(game.ReplicatedFirst.Util.SafeRequire)
	safe_require:__init(G)
	safe_require = safe_require.require

	local err = require(game.ReplicatedFirst.Util.Error)
	unwrap_or_warn = err.unwrap_or_warn
	unwrap_or_error = err.unwrap_or_error

	LazyString = require(game.ReplicatedFirst.Util.LazyString)
end

return mod
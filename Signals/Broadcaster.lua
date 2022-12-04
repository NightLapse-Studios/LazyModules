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

	ShouldAccept = function(self, func)
		unwrap_or_error(
			typeof(func) == "function",
			"Missing func for Broadcaster"
		)
		self.__ShouldAccept = func
		return self
	end,

	ServerConnection = function(self, func)
		unwrap_or_error(
			typeof(func) == "function",
			"Missing func for Broadcaster"
		)
		self.__ServerConnection = func
		return self
	end,

	ClientConnection = function(self, func)
		unwrap_or_error(
			typeof(func) == "function",
			"Missing func for Broadcaster"
		)
		self.__ClientConnection = func
	end,

	Build = function(self)
		if IsServer then
			self[1].OnServerEvent:Connect(function(plr, ...)
				local should_accept = self.__ShouldAccept(plr, ...)

				if should_accept then
					self.__ServerConnection(plr, ...)
				end
			end)
		elseif self.__ClientConnection then
			self[1].OnClientEvent:Connect(self.__ClientConnection)
		end
	end
}

local BroadcasterClient = {
	Broadcast = function(self, ...)
		self[1]:FireServer(...)
	end
}
local BroadcasterServer = {
	Broadcast = function(self, plr, ...)
		for i,v in pairs(Players:GetPlayers()) do
			if plr == v then continue end

			self[1]:FireClient(v, ...)
		end
	end,
}

local mt_BroadcastBuilder = {__index = BroadcastBuilder}
mod.client_mt = {__index = BroadcasterClient}
mod.server_mt = {__index = BroadcasterServer}

-- Broadcasters use a client->server?->all-clients model
function mod.NewBroadcaster(self: Builder, identifier: string)
	local broadcaster = remote_wrapper(identifier, mt_BroadcastBuilder)
	broadcaster.__ShouldAccept = false
	broadcaster.__ServerConnection = false
	broadcaster.__ClientConnection = false
	setmetatable(broadcaster, mt_BroadcastBuilder)

	Broadcasters[self.CurrentModule] = Broadcasters[self.CurrentModule] or { }

	unwrap_or_error(
		Broadcasters[self.CurrentModule][identifier] == nil,
		"Re-declared broadcaster `" .. identifier .. "` in `" .. self.CurrentModule .. "`"
	)

	local Modules = Broadcasters.Modules
	Modules[self.CurrentModule] = Modules[self.CurrentModule] or { }

	Broadcasters.Identifiers[identifier] = self.CurrentModule
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
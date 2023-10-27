--!strict

--[[
	Events:

	Events function like normal RemoteEvents but cannot cross client-server boundaries
]]

local mod = {
	Events = {
		Identifiers = { },
		Modules = { }
	}
}

local Events = mod.Events

local Globals
local unwrap_or_warn
local unwrap_or_error
local safe_require
local async_list

local IsServer = game:GetService("RunService"):IsServer()

local ServerScriptService, ReplicatedStorage = game:GetService("ServerScriptService"), game.ReplicatedStorage

local PlayerScripts = if IsServer then false else game.Players.LocalPlayer.PlayerScripts
local CONTEXT = IsServer and "SERVER" or "CLIENT"

local EventBuilder = {
	Type = "Builder",
	Context = CONTEXT,

	Connect = function(self, func, force_context: string?)
		if force_context and Globals.CONTEXT ~= force_context then
			return self
		end
 
		self[#self + 1] = func
		return self
	end,

	ServerConnection = function(self, func)
		if CONTEXT ~= "SERVER" then
			return self
		end
		
		self[#self + 1] = func
		return self
	end,

	ClientConnection = function(self, func)
		if CONTEXT ~= "CLIENT" then
			return self
		end
		
		self[#self + 1] = func
		return self
	end
}
local EventWrapper = {
	Fire = function(self, ...)
		if self.monitor then
			self.monitor(self, ...)
		end

		for i = 1, #self do
			task.spawn(self[i], ...)
		end
	end,
	Connect = function(self, func)
		self[#self + 1] = func
	end
}

local mt_EventBuilder = { __index = EventBuilder }
mod.client_mt = { __index = EventWrapper }
mod.server_mt = { __index = EventWrapper }


function mod.NewEvent(self: Builder, identifier)
	if Events.Identifiers:inspect(identifier) ~= nil then
		error("Re-declared Event identifier `" .. identifier .. "`\nFirst declared in `" .. Events.Identifiers[identifier] .. "`")
	end

	local event =
		setmetatable(
			{ },
			mt_EventBuilder
		)

	if Events.Modules:inspect(self.CurrentModule, identifier) ~= nil then
		error("Duplicate event `" .. identifier .. "` in `" .. self.CurrentModule .. "`")
	end

	Events.Identifiers:provide(event, identifier)
	Events.Modules:provide(event, self.CurrentModule, identifier)

	return event
end

function mod:__init(G)
	Globals = G

	safe_require = require(game.ReplicatedFirst.Util.SafeRequire)
	safe_require = safe_require.require

	local err = require(game.ReplicatedFirst.Util.Error)
	unwrap_or_warn = err.unwrap_or_warn
	unwrap_or_error = err.unwrap_or_error


	async_list = require(game.ReplicatedFirst.Util.AsyncList)
	async_list:__init(G)

	mod.Events.Identifiers = async_list.new(1)
	mod.Events.Modules = async_list.new(2)
end

return mod
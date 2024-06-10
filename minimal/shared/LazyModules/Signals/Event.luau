--!strict

--[[
	Events:

	Events function like normal RemoteEvents but cannot cross client-server boundaries
]]

local async_list = require(game.ReplicatedFirst.Lib.AsyncList)

local mod = {
	Events = {
		Identifiers = async_list.new(1),
		Modules = async_list.new(2),
	}
}

local Events = mod.Events

local IsServer = game:GetService("RunService"):IsServer()
local CONTEXT = IsServer and "SERVER" or "CLIENT"

local EventBuilder = {
	Type = "Builder",
	Context = CONTEXT,

	Connect = function(self, func, force_context: string?)
		if force_context and _G.Game.CONTEXT ~= force_context then
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


function mod.NewEvent(signals_module, identifier: string): Event
	if Events.Identifiers:inspect(identifier) ~= nil then
		error("Re-declared Event identifier `" .. identifier .. "`\nFirst declared in `" .. Events.Identifiers[identifier] .. "`")
	end

	local event =
		setmetatable(
			{ },
			mt_EventBuilder
		)

	if Events.Modules:inspect(signals_module.CurrentModule, identifier) ~= nil then
		error("Duplicate event `" .. identifier .. "` in `" .. signals_module.CurrentModule .. "`")
	end

	Events.Identifiers:provide(event, identifier)
	Events.Modules:provide(event, signals_module.CurrentModule, identifier)

	return event
end

export type Event = typeof(mod.NewEvent({CurrentModule=""}, "Ex"))

return mod
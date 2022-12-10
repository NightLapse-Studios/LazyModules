--!strict

--[[
	Events:

	Events function like normal RemoteEvents but cannot cross client-server boundaries
	Can only have one recieving connected function
]]

local mod = {
	Events = {
		Identifiers = { },
		Modules = { }
	}
}

local Events = mod.Events

local Globals
local LazyString
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
			return
		end
 
		unwrap_or_error(
			self.Connected ~= true,
			"Attempt to Connect to an Event multiple times"
		)
		self[1].Event:Connect(func)
		self.Connected = true
	end
}
local EventWrapper = {
	Fire = function(self, ...)
		self[1]:Fire(...)
	end,
	Connect = function()
		error("Only one reciever can be attached to an event\nNor can you connect to an Event outside of the BUILD_EVENTS phase")
	end
}

local mt_EventBuilder = { __index = EventBuilder }
mod.client_mt = { __index = EventWrapper }
mod.server_mt = { __index = EventWrapper }


function mod.NewEvent(self: Builder, identifier)
	unwrap_or_error(
		Events.Identifiers:inspect(identifier) == nil,
		LazyString.new("Re-declared Event identifier `", identifier, "`\nFirst declared in `", Events.Identifiers[identifier], "`")
	)

	local event =
		setmetatable(
			{
				Instance.new("BindableEvent",
					IsServer
					and ServerScriptService
					or PlayerScripts),
				Connected = false
			},
			mt_EventBuilder
		)

	Events.Modules.provided[self.CurrentModule] = Events.Modules.provided[self.CurrentModule] or { }

	unwrap_or_error(
		Events.Modules:inspect(self.CurrentModule, identifier) == nil,
		"Duplicate event `" .. identifier .. "` in `" .. self.CurrentModule .. "`"
	)

	Events.Identifiers:provide(event, identifier)
	Events.Modules:provide(event, self.CurrentModule, identifier)

	return event
end

function mod:__init(G)
	Globals = G

	safe_require = require(game.ReplicatedFirst.Util.SafeRequire)
	safe_require:__init(G)
	safe_require = safe_require.require

	local err = require(game.ReplicatedFirst.Util.Error)
	unwrap_or_warn = err.unwrap_or_warn
	unwrap_or_error = err.unwrap_or_error

	LazyString = require(game.ReplicatedFirst.Util.LazyString)

	async_list = require(game.ReplicatedFirst.Util.AsyncList)
	async_list:__init(G)

	mod.Events.Identifiers = async_list.new(1)
	mod.Events.Modules = async_list.new(2)
end

return mod
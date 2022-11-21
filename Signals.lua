--!strict
--[[
	Part of the LazyModules system

	This implements a series of "Builder" object, similar to the pattern used in Rust, to create networking and module
		communication interfaces. They are just wrappers around RemoteEvents or BindableEvents which enforce certain
		usage standards


Builders:
	A Builder object is any object used to construct another object of the Builder's target type.
	For this module, Builders which simply set their metatable to refer to a non-builder object is enough to
		instantiate the object from the builder

	Builders are transformed into their related objects in the `__finalize` function of this module.
	The finalization step guarantees other modules that the signal building process is done, so it must be the first
		finalize call.

Valid usage:
	Any module implementing a signal from this module can have that signal be depended on by any other module,
		even the direct parent of a module can use signals from its children, but only during or after the finalize phase

	Signals are not usable during the signal building phase
]]
local mod = {
	Verbs = { },
	Nouns = { },
}

local Globals
local LazyModules
local LazyString
local Err
local unwrap_or_warn
local unwrap_or_error
local safe_require

local Verbs = mod.Verbs

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local IsServer = game:GetService("RunService"):IsServer()

local Players = game.Players
local ServerScriptService, ReplicatedStorage = game.ServerScriptService, game.ReplicatedStorage

local PlayerScripts = if IsServer then false else game.Players.LocalPlayer.PlayerScripts
local CONTEXT = IsServer and "Server" or "Client"

type opt_func = ((any?) -> any)?


--[[
	Generic Signals:

	Signals allow any module to say that some action has taken place in regards to a subject
	No further details are provided to hooks other than the `verb` and `noun`
	This restrictive design makes it most relevant on the client

	DON'T USE THESE YET
	we still need to see if they
]]

local SignalWrapper = {
	Fire = function(self)
		self[1]:Fire()
	end,

	Hook = function(self, func)
		self[1].Event:Connect(func)
	end
}
local mt_SignalWrapper = { __index = SignalWrapper }

function mod:NewGenericSignal(verb, noun)
	if not Verbs[verb] then
		Verbs[verb] = { }
	end

	local _con = Verbs[verb][noun]
	if _con then
		error("Registered " .. verb .. " " .. noun .. " multiple times")
		return _con
	end

	--Create a light wrapper for remote events
	local sig =
		setmetatable(
			{
				Instance.new("BindableEvent",
					IsServer
					and ServerScriptService
					or PlayerScripts)
			},
			mt_SignalWrapper
		)

	Verbs[verb][noun] = sig

	return sig
end

local AnyEventIsWaiting = false

local function wait_for_signal(verb, noun, func)
	while mod.Verbs[verb] == nil do task.wait() end
	local t = mod.Verbs[verb]
	while t[noun] == nil do task.wait() end
	t[noun]:Hook(func)
end

function mod:HookGenericSignal(verb, noun, func)
	unwrap_or_error(
		Globals.LOADING_CONTEXT == Globals.LazyModules.CONTEXTS.SIGNAL_BUILDING,
		"Can only hook Signals during the signal building startup phase"
	)

	AnyEventIsWaiting = true

	local co = coroutine.create(wait_for_signal)
	local _, signal = coroutine.resume(co, verb, noun, func)

	AnyEventIsWaiting = false

	return signal
end


--[[
	Events:

	Events function like normal RemoteEvents but cannot cross client-server boundaries
	Can only have one recieving connected function
]]

local Events = {
	Identifiers = { },
	Modules = { }
}

local EventBuilder = {
	Type = "Builder",
	Context = CONTEXT,

	Connect = function(self, func)
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
local mt_EventWrapper = { __index = EventWrapper }

-- Makes a wrapper for events which uses a verb->noun abstraction idea rather than module->something-happened
-- Client and Server have slightly different wrappers
function mod:NewEvent(identifier)
	unwrap_or_error(
		Events.Identifiers[identifier] == nil,
		LazyString.new("Re-declared Event identifier `", identifier, "`\nFirst declared in `", Events.Identifiers[identifier], "`")
	)

	Events.Identifiers[identifier] = mod.CurrentModule

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

	Events.Modules[mod.CurrentModule] = Events.Modules[mod.CurrentModule] or { }

	unwrap_or_error(
		Events.Modules[mod.CurrentModule][identifier] == nil,
		"Duplicate event `" .. identifier .. "` in `" .. mod.CurrentModule .. "`"
	)

	Events.Modules[mod.CurrentModule][identifier] = event

	return event
end

local function wait_for_event(module, identifier)
	while Events[module] == nil do task.wait() end
	local t = Events[module]
	while t[identifier] == nil do task.wait() end
end

function mod:GetEvent(module, identifier)
	AnyEventIsWaiting = true
	local co = coroutine.create(wait_for_event)
	local _, event = coroutine.resume(co, module, identifier)
	AnyEventIsWaiting = false
	return event
end




-- We'll link ids to their mods and mods to their ids so that they can be requested by ids alone
local Transmitters = {
	Identifiers = { },
	Modules = { }
}

-- These wrappers are named from the perspective of their callers
-- so the client one uses "FireServer" to transmit and vice-versa
local TransmitterBuilder = {
	Type = "Builder",

	ClientConnection = function(self, func: opt_func)
		if not func then return self end
		if IsServer then return self end
		unwrap_or_error(
			self.Configured.Client == false,
			"Cannot have multiple recievers of a transmission object"
		)

		self.Configured.Client = true
		self[1].OnClientEvent:Connect(func)

		return self
	end,
	ServerConnection = function(self, func: opt_func)
		if not func then return self end
		if not IsServer then return self end
		unwrap_or_error(
			self.Configured.Server == false,
			"Cannot have multiple recievers of a transmission object"
		)

		self.Configured.Server = true
		self[1].OnServerEvent:Connect(func)

		return self
	end
}
local ClientTransmitter = {
	Transmit = function(self, ...)
		self[1]:FireServer(...)
	end,
}
local ServerTransmitter = {
	Transmit = function(self, ...)
		self[1]:FireClient(...)
	end,
}

local mt_TransmitterBuilder = { __index = TransmitterBuilder}
local mt_ClientTransmitter = { __index = ClientTransmitter }
local mt_ServerTransmitter = { __index = ServerTransmitter }

local function basic_transmitter(identifier: string)
	-- TODO: check that all events made on the server are also made on the client
	local transmitter
	if IsServer then
		transmitter = setmetatable(
			{
				Instance.new("RemoteEvent", ReplicatedStorage),
				Configured = {
					Server = false,
					Client = false,
				},
			},
			mt_TransmitterBuilder
		)
		transmitter[1].Name = identifier
	else
		transmitter = setmetatable(
			{
				ReplicatedStorage:WaitForChild(identifier),
				Configured = {
					Server = false,
					Client = false,
				},
			},
			mt_TransmitterBuilder
		)
	end

	return transmitter
end

-- Makes a wrapper for events which uses a verb->noun abstraction idea rather than module->something-happened
-- Client and Server have slightly different wrappers
function mod:NewTransmitter(identifier: string)
	local transmitter = basic_transmitter(identifier)

	local Modules = Transmitters.Modules
	Modules[mod.CurrentModule] = Modules[mod.CurrentModule] or { }

	local _mod = Transmitters.Identifiers[identifier]
	unwrap_or_error(
		_mod == nil,
		LazyString.new("Re-declared event `", identifier, "` in `", mod.CurrentModule, "`.\nOriginally declared here: `", _mod, "`")
	)
	Transmitters.Identifiers[identifier] = mod.CurrentModule
	Modules[mod.CurrentModule][identifier] = transmitter

	return transmitter
end

local function wait_for_transmitter(module, identifier)
	while Transmitters[module] == nil do task.wait() end
	local t = Transmitters[module]
	while t[identifier] == nil do task.wait() end
end

function mod:GetTransmitter(module, identifier)
	AnyEventIsWaiting = true
	local co = coroutine.create(wait_for_transmitter)
	local _, transmitter = coroutine.resume(co, module, identifier)
	AnyEventIsWaiting = false
	return transmitter
end





local Broadcasters = {
	Identifiers = { },
	Modules = { }
}

-- Rare case of inheritance in the wild
local BroadcastBuilder = {
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
		else
			self[1].OnClientEvent:Connect(self.__ClientConnection)
		end
	end
}
setmetatable(BroadcastBuilder, {__index = TransmitterBuilder})

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
local mt_BroadcasterClient = {__index = BroadcasterClient}
local mt_BroadcasterServer = {__index = BroadcasterServer}

-- Broadcasters use a client->server?->all-clients model
function mod:NewBroadcaster(identifier: string)
	local broadcaster = basic_transmitter(identifier)
	broadcaster.__ShouldAccept = false
	broadcaster.__ServerConnection = false
	broadcaster.__ClientConnection = false
	setmetatable(broadcaster, mt_BroadcastBuilder)

	Broadcasters[mod.CurrentModule] = Broadcasters[mod.CurrentModule] or { }

	unwrap_or_error(
		Broadcasters[mod.CurrentModule][identifier] == nil,
		"Re-declared broadcaster `" .. identifier .. "` in `" .. mod.CurrentModule .. "`"
	)

	local Modules = Broadcasters.Modules
	Modules[mod.CurrentModule] = Modules[mod.CurrentModule] or { }

	Broadcasters.Identifiers[identifier] = mod.CurrentModule
	Modules[mod.CurrentModule][identifier] = broadcaster

	return broadcaster
end

local function wait_for_broadcaster(module, identifier)
	while Broadcasters[module] == nil do task.wait() end
	local t = Broadcasters[module]
	while t[identifier] == nil do task.wait() end
end

function mod:GetBroadcaster(module, identifier)
	AnyEventIsWaiting = true
	local co = coroutine.create(wait_for_broadcaster)
	local _, broadcaster = coroutine.resume(co, module, identifier)
	AnyEventIsWaiting = false
	return broadcaster
end



function mod:__finalize(G)
--[[ 	while AnyEventIsWaiting == true do
		task.wait()
	end ]]

	for module, identifers in Transmitters.Modules do
		for ident, transmitter in identifers do
			local transmitter_str = "Transmitter `" .. module .. "::" .. ident

			if CONTEXT == "Client" then
--[[ 				unwrap_or_error(
					transmitter.Configured.Client == false,
					transmitter_str .. "` is not configured on the client"
				) ]]
				setmetatable(transmitter, mt_ClientTransmitter)
			else
--[[ 				unwrap_or_error(
					transmitter.Configured.Server == false,
					transmitter_str .. "` is not configured on the server"
				) ]]
				setmetatable(transmitter, mt_ServerTransmitter)
			end
		end
	end

	for module, identifers in Broadcasters.Modules do
		for ident, broadcaster in identifers do
			local transmitter_str = "Broadcaster `" .. module .. "::" .. ident .. "` "

			if CONTEXT == "Client" then
--[[ 				unwrap_or_error(
					broadcaster.__ClientConnection ~= false,
					transmitter_str .. "is not configured on the client"
				) ]]
				if self.__ClientConnection then
					broadcaster[1].OnClientEvent:Connect(self.__ClientConnection)
				end

				setmetatable(broadcaster, mt_BroadcasterClient)
			elseif CONTEXT == "Server" then
				unwrap_or_warn(
					broadcaster.__ShouldAccept ~= false,
					transmitter_str .. "needs a config call to Builder:ShouldAccept(func)"
				)
				unwrap_or_error(
					typeof(broadcaster.__ShouldAccept) == "function" and typeof(broadcaster.__ServerConnection) == "function",
					transmitter_str .. "passed value is not a function"
				)
--[[ 				unwrap_or_error(
					broadcaster.__ServerConnection ~= false,
					transmitter_str .. "needs a config call to Builder:ServerConnection(func)"
				) ]]
				if broadcaster.__ShouldAccept then
					broadcaster[1].OnServerEvent:Connect(function(plr, ...)
						local should_accept = broadcaster.__ShouldAccept(plr, ...)
						if not should_accept then return end

						broadcaster.__ServerConnection(plr, ...)
					end)
				elseif broadcaster.__ServerConnection then
					broadcaster[1].OnServerEvent:Connect(broadcaster.__ServerConnection)
				end

				setmetatable(broadcaster, mt_BroadcasterServer)
			end
		end
	end

	for module, identifers in Events.Modules do
		for ident, event in identifers do
			local event_str = "Event `" .. module .. "::" .. ident
			unwrap_or_error(
				event.Type == "Builder",
				event_str .. "` is not a Builder (what did you do?)"
			)

			setmetatable(event, mt_EventWrapper)
		end
	end
end




function mod:Builder( module_name: string )
	assert(module_name)
	assert(typeof(module_name) == "string")

	mod.CurrentModule = module_name

	return mod
end

function mod:__init(G, LazyModules)
	Globals = G
	LazyModules = LazyModules

	--The one true require tree
	safe_require = require(ReplicatedFirst.Util.SafeRequire)
	safe_require:__init(G)
	safe_require = safe_require.require

	Err = require(ReplicatedFirst.Util.Error)
	unwrap_or_warn = Err.unwrap_or_warn
	unwrap_or_error = Err.unwrap_or_error

	LazyString = require(ReplicatedFirst.Util.LazyString)
end

return mod
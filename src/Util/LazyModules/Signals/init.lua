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
	Nouns = { },
}

local Globals
local LazyModules
local LazyString
local PSA
local Err
local unwrap_or_warn
local unwrap_or_error
local safe_require

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local IsServer = game:GetService("RunService"):IsServer()

local AnyEventIsWaiting = false

local Players = game.Players

local PlayerScripts = if IsServer then false else game.Players.LocalPlayer.PlayerScripts
local CONTEXT = IsServer and "SERVER" or "CLIENT"

--event abstraction modules
local GameEvent
local Transmitter
local Broadcaster
local Event

--lists
local Transmitters
local Broadcasters
local GameEvents
local Events

local WaitingList




function mod:GetEvent(identifier, cb, force_context: string?)
	if force_context and force_context ~= Globals.CONTEXT then
		return
	end

	local success = Event.Events.Identifiers:get(identifier, cb)
	if not success then
		error("\nEvent: " .. mod.CurrentModule .. " " .. identifier)
	end
end

function mod:GetGameEvent(verb, noun, cb, force_context: string)
	if force_context and force_context ~= Globals.CONTEXT then
		return
	end

	local success = GameEvent.GameEvents.Verbs:get(verb, noun, cb)
	if not success then
		error("\nGameEvent: " .. mod.CurrentModule .. " " .. verb .. " " .. noun)
	end
end

function mod:GetTransmitter(identifier, cb, force_context: string)
	if force_context and force_context ~= Globals.CONTEXT then
		return
	end

	local success = Transmitter.Transmitters.Identifiers:get(identifier, cb)
	if not success then
		error("\nEvent: " .. mod.CurrentModule .. " " .. identifier)
	end
end

function mod:GetBroadcaster(identifier, cb, force_context: string)
	if force_context and force_context ~= Globals.CONTEXT then
		return
	end

	local success = Broadcaster.Broadcasters.Identifiers:get(identifier, cb)
	if not success then
		error("\nEvent: " .. mod.CurrentModule .. " " .. identifier)
	end
end



function mod:Builder( module_name: string )
	assert(module_name)
	assert(typeof(module_name) == "string")

	mod.CurrentModule = module_name

	return mod
end


local function monitor_func(signal, ...)
	print(signal[1].Name)
end

function mod:Monitor( ... )
	-- TODO: You can't put Signals.Events in here. We should probably sunset Events
	local signals = { ... }
	for i,v in signals do
		v.monitor = monitor_func
	end
end



local mt_ClientTransmitter
local mt_ServerTransmitter
local mt_ServerBroadcaster
local mt_ClientBroadcaster
local mt_ServerEvent
local mt_ClientEvent
local mt_ServerGameEvent
local mt_ClientGameEvent

function mod:__init(G, LazyModules)
	Globals = G
	LazyModules = LazyModules

	safe_require = require(ReplicatedFirst.Util.SafeRequire)
	safe_require = safe_require.require

	local remote_wrapper = require(ReplicatedFirst.Util.LazyModules.Signals.__remote_wrapper)
	remote_wrapper:__init(G, LazyModules)

	PSA = require(ReplicatedFirst.Util.SparseList)
	WaitingList = PSA.new()

	Err = require(ReplicatedFirst.Util.Error)
	unwrap_or_warn = Err.unwrap_or_warn
	unwrap_or_error = Err.unwrap_or_error

	GameEvent = require(script.GameEvent)
	Transmitter = require(script.Transmitter)
	Broadcaster = require(script.Broadcaster)
	Event = require(script.Event)

	GameEvent:__init(G, mod)
	Transmitter:__init(G, mod)
	Broadcaster:__init(G, mod)
	Event:__init(G, mod)

	mt_ClientTransmitter = Transmitter.client_mt
	mt_ServerTransmitter = Transmitter.server_mt
	mt_ClientBroadcaster = Broadcaster.client_mt
	mt_ServerBroadcaster = Broadcaster.server_mt
	mt_ClientGameEvent = GameEvent.client_mt
	mt_ServerGameEvent = GameEvent.server_mt
	mt_ClientEvent = Event.client_mt
	mt_ServerEvent = Event.server_mt

	mod.NewEvent = Event.NewEvent
	mod.NewGameEvent = GameEvent.NewGameEvent
	mod.NewTransmitter = Transmitter.NewTransmitter
	mod.NewBroadcaster = Broadcaster.NewBroadcaster

	Transmitters = Transmitter.Transmitters
	Broadcasters = Broadcaster.Broadcasters
	GameEvents = GameEvent.GameEvents
	Events = Event.Events

	LazyString = require(ReplicatedFirst.Util.LazyString)
end

local function wait_for(async_table)
	local waited = 0
	while
		async_table:is_awaiting()
	do
		waited += 1
		local too_long = waited > 32
		unwrap_or_warn(
			too_long == false,
			"Took too long to resolve signals (should usually be 1 tick)\n\nContents:\n" .. WaitingList:dump()
		)

		if too_long then break end

		task.wait()
	end

	return waited
end

-- TODO: Many safety checks require some meta-communication with the server. eeeeghhh
function mod:__finalize(G)
	task.desynchronize()

	local wait_dur = 0
	wait_dur += wait_for(Event.Events.Identifiers)
	wait_dur += wait_for(GameEvent.GameEvents.Identifiers)
	wait_dur += wait_for(Transmitter.Transmitters.Identifiers)
	wait_dur += wait_for(Broadcaster.Broadcasters.Identifiers)

	print("Waited " .. wait_dur .. " ticks")

	task.synchronize()

	for module, identifers in Transmitters.Modules.provided do
		for ident, transmitter in identifers do
			local transmitter_str = "Transmitter `" .. module .. "::" .. ident

			if CONTEXT == "CLIENT" then
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

	for module, identifers in Broadcasters.Modules.provided do
		for ident, broadcaster in identifers do
			local transmitter_str = "Broadcaster `" .. module .. "::" .. ident .. "` "

			broadcaster:Build()

			if CONTEXT == "CLIENT" then
				setmetatable(broadcaster, mt_ClientBroadcaster)
			elseif CONTEXT == "SERVER" then
				if broadcaster.Connections > 0 then
					unwrap_or_warn(
						broadcaster.__ShouldAccept ~= false,
						transmitter_str .. "has no config call to Builder:ShouldAccept(func)\nTherefore any client firing this event will be trusted!"
					)

					if broadcaster.__ShouldAccept then
						unwrap_or_error(
							typeof(broadcaster.__ShouldAccept) == "function",
							transmitter_str .. "passed value is not a function"
						)
					end
				end

				setmetatable(broadcaster, mt_ServerBroadcaster)
			end
		end
	end

	for module, identifers in GameEvents.Modules.provided do
		for ident, event in identifers do
			local transmitter_str = "GameEvent `" .. module .. "::" .. ident .. "` "

			event:Build()

			for i,v in event.Implications do
				unwrap_or_warn(
					typeof(v) ~= "string",
					LazyString.new(transmitter_str, "has unresolved implication for `", event.Verb, "`\n\n(GameEvent `", event.Verb, " ", i, "` does not exist)\n")
				)
			end

			if CONTEXT == "CLIENT" then
				setmetatable(event, mt_ClientGameEvent)
			elseif CONTEXT == "SERVER" then
--[[ 				if event.Connections > 0 then
					unwrap_or_warn(
						event.__ShouldAccept ~= false,
						transmitter_str .. "needs a config call to Builder:ShouldAccept(func) (due to server connection)"
					)
				end ]]

				setmetatable(event, mt_ServerGameEvent)
			end
		end
	end

	for module, identifers in Events.Modules.provided do
		for ident, event in identifers do
			if CONTEXT == "CLIENT" then
				local event_str = "Event `" .. module .. "::" .. ident
				unwrap_or_error(
					event.Type == "Builder",
					event_str .. "` is not a Builder (what did you do?)"
				)

				setmetatable(event, mt_ClientEvent)
			elseif CONTEXT == "SERVER" then
				local event_str = "Event `" .. module .. "::" .. ident
				unwrap_or_error(
					event.Type == "Builder",
					event_str .. "` is not a Builder (what did you do?)"
				)

				setmetatable(event, mt_ServerEvent)
			end
		end
	end
end

return mod
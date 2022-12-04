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
local ServerScriptService, ReplicatedStorage = game.ServerScriptService, game.ReplicatedStorage

local PlayerScripts = if IsServer then false else game.Players.LocalPlayer.PlayerScripts
local CONTEXT = IsServer and "Server" or "Client"

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


local function wait_for_event(identifier, cb)
	local module = mod.CurrentModule
	local idx = WaitingList:insert("Event: " .. module .. " " .. identifier)

	while Events.Identifiers[identifier] == nil do task.wait() end
	WaitingList:remove(idx)

	if cb then
		cb(Events.Identifiers[identifier])
	end
end

local function wait_for_gameevent(verb, noun, cb)
	local idx = WaitingList:insert("GameEvent: " .. verb .. " " .. noun)
	while GameEvents.Verbs[verb] == nil do task.wait() end
	local t = GameEvents.Verbs[verb]

	while t[noun] == nil do task.wait() end
	WaitingList:remove(idx)

	if cb then
		cb(t[noun])
	end
end

local function wait_for_transmitter(identifier, cb)
	local module = mod.CurrentModule
	local idx = WaitingList:insert("Transmitter: " .. module .. " " .. identifier)

	while Transmitters.Identifiers[identifier] == nil do task.wait() end
	WaitingList:remove(idx)

	if cb then
		cb(Transmitters.Identifiers[identifier])
	end
end

local function wait_for_broadcaster(identifier, cb)
	local module = mod.CurrentModule
	local idx = WaitingList:insert("Broadcaster: " .. module .. " " .. identifier)

	while Broadcasters.Identifiers[identifier] == nil do task.wait() end
	WaitingList:remove(idx)

	if cb then
		cb(Broadcasters.Identifiers[identifier])
	end
end




function mod:GetEvent(identifier, cb, force_context: string?)
	if force_context and force_context ~= Globals.CONTEXT then
		return
	end
	local co = coroutine.create(wait_for_event)
	local _, _ = coroutine.resume(co, identifier, cb)
end

function mod:GetGameEvent(verb, noun, cb, force_context: string)
	if force_context and force_context ~= Globals.CONTEXT then
		return
	end
	local co = coroutine.create(wait_for_gameevent)
	local _, _ = coroutine.resume(co, verb, noun, cb)
end

function mod:GetTransmitter(identifier, cb, force_context: string)
	if force_context and force_context ~= Globals.CONTEXT then
		return
	end
	local co = coroutine.create(wait_for_transmitter)
	local _, _ = coroutine.resume(co, identifier, cb)
end

function mod:GetBroadcaster(identifier, cb, force_context: string)
	if force_context and force_context ~= Globals.CONTEXT then
		return
	end
	local co = coroutine.create(wait_for_broadcaster)
	local _, _ = coroutine.resume(co, identifier, cb)
end



function mod:Builder( module_name: string )
	assert(module_name)
	assert(typeof(module_name) == "string")

	mod.CurrentModule = module_name

	return mod
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

	--The one true require tree
	safe_require = require(ReplicatedFirst.Util.SafeRequire)
	safe_require:__init(G)
	safe_require = safe_require.require

	PSA = require(ReplicatedFirst.Modules.PackedSparseArray)
	WaitingList = PSA.new()

	Err = require(ReplicatedFirst.Util.Error)
	unwrap_or_warn = Err.unwrap_or_warn
	unwrap_or_error = Err.unwrap_or_error

	GameEvent = require(script.GameEvent)
	Transmitter = require(script.Transmitter)
	Broadcaster = require(script.Broadcaster)
	Event = require(script.Event)

	GameEvent:__init(G)
	Transmitter:__init(G)
	Broadcaster:__init(G)
	Event:__init(G)

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

-- TODO: Many safety checks require some meta-communication with the server. eeeeghhh
function mod:__finalize(G)
	local wait_dur = 0
	while WaitingList:is_empty() == false do
		wait_dur += 1
		unwrap_or_error(
			wait_dur < 32,
			"Took too long to resolve signals (should usually be 1 tick)\nContents:\n" .. WaitingList:dump()
		)

		task.wait()
	end

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

			broadcaster:Build()

			if CONTEXT == "Client" then
--[[ 				unwrap_or_error(
					broadcaster.__ClientConnection ~= false,
					transmitter_str .. "is not configured on the client"
				) ]]
				if broadcaster.__ClientConnection then
					broadcaster[1].OnClientEvent:Connect(broadcaster.__ClientConnection)
				end

				setmetatable(broadcaster, mt_ClientBroadcaster)
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

				setmetatable(broadcaster, mt_ServerBroadcaster)
			end
		end
	end

	for module, identifers in GameEvents.Modules do
		for ident, event in identifers do
			local transmitter_str = "GameEvent `" .. module .. "::" .. ident .. "` "

			event:Build()

			if CONTEXT == "Client" then
				setmetatable(event, mt_ClientGameEvent)
			elseif CONTEXT == "Server" then
				if event.__ServerConnection then
					unwrap_or_warn(
						event.__ShouldAccept ~= false,
						transmitter_str .. "needs a config call to Builder:ShouldAccept(func) (due to server connection)"
					)
					unwrap_or_error(
						typeof(event.__ShouldAccept) == "function" and typeof(event.__ServerConnection) == "function",
						transmitter_str .. "passed value is not a function"
					)
				end

				setmetatable(event, mt_ServerGameEvent)
			end
		end
	end

	for module, identifers in Events.Modules do
		for ident, event in identifers do
			if CONTEXT == "Client" then
				local event_str = "Event `" .. module .. "::" .. ident
				unwrap_or_error(
					event.Type == "Builder",
					event_str .. "` is not a Builder (what did you do?)"
				)

				setmetatable(event, mt_ClientEvent)
			elseif CONTEXT == "Server" then
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
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



local function wait_for_event(module, identifier)
	while Events[module] == nil do task.wait() end
	local t = Events[module]
	while t[identifier] == nil do task.wait() end
end

local function wait_for_gameevent(module, identifier)
	while GameEvents[module] == nil do task.wait() end
	local t = GameEvents[module]
	while t[identifier] == nil do task.wait() end
end

local function wait_for_transmitter(module, identifier)
	while Transmitters[module] == nil do task.wait() end
	local t = Transmitters[module]
	while t[identifier] == nil do task.wait() end
end

local function wait_for_broadcaster(module, identifier)
	while Broadcasters[module] == nil do task.wait() end
	local t = Broadcasters[module]
	while t[identifier] == nil do task.wait() end
end




function mod:GetEvent(module, identifier)
	AnyEventIsWaiting = true
	local co = coroutine.create(wait_for_event)
	local _, event = coroutine.resume(co, module, identifier)
	AnyEventIsWaiting = false
	return event
end

function mod:NewGameEvent(module, identifier)
	AnyEventIsWaiting = true
	local co = coroutine.create(wait_for_gameevent)
	local _, event = coroutine.resume(co, module, identifier)
	AnyEventIsWaiting = false
	return event
end

function mod:GetTransmitter(module, identifier)
	AnyEventIsWaiting = true
	local co = coroutine.create(wait_for_transmitter)
	local _, transmitter = coroutine.resume(co, module, identifier)
	AnyEventIsWaiting = false
	return transmitter
end

function mod:GetBroadcaster(module, identifier)
	AnyEventIsWaiting = true
	local co = coroutine.create(wait_for_broadcaster)
	local _, broadcaster = coroutine.resume(co, module, identifier)
	AnyEventIsWaiting = false
	return broadcaster
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
	while AnyEventIsWaiting == true do
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

			if CONTEXT == "Client" then
--[[ 				unwrap_or_error(
					broadcaster.__ClientConnection ~= false,
					transmitter_str .. "is not configured on the client"
				) ]]
				if self.__ClientConnection then
					broadcaster[1].OnClientEvent:Connect(self.__ClientConnection)
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
				if broadcaster.__ShouldAccept then
					broadcaster[1].OnServerEvent:Connect(function(plr, ...)
						local should_accept = broadcaster.__ShouldAccept(plr, ...)
						if not should_accept then return end

						broadcaster.__ServerConnection(plr, ...)
					end)
				elseif broadcaster.__ServerConnection then
					broadcaster[1].OnServerEvent:Connect(broadcaster.__ServerConnection)
				end

				setmetatable(broadcaster, mt_ServerBroadcaster)
			end
		end
	end

	for module, identifers in GameEvents.Modules do
		for ident, event in identifers do
			local transmitter_str = "Broadcaster `" .. module .. "::" .. ident .. "` "

			if CONTEXT == "Client" then
--[[ 				unwrap_or_error(
					broadcaster.__ClientConnection ~= false,
					transmitter_str .. "is not configured on the client"
				) ]]
				if self.__ClientConnection then
					event[1].OnClientEvent:Connect(self.__ClientConnection)
				end

				setmetatable(event, mt_ClientGameEvent)
			elseif CONTEXT == "Server" then
				unwrap_or_warn(
					event.__ShouldAccept ~= false,
					transmitter_str .. "needs a config call to Builder:ShouldAccept(func)"
				)
				unwrap_or_error(
					typeof(event.__ShouldAccept) == "function" and typeof(event.__ServerConnection) == "function",
					transmitter_str .. "passed value is not a function"
				)
--[[ 				unwrap_or_error(
					broadcaster.__ServerConnection ~= false,
					transmitter_str .. "needs a config call to Builder:ServerConnection(func)"
				) ]]
				if event.__ShouldAccept then
					event[1].OnServerEvent:Connect(function(plr, ...)
						local should_accept = event.__ShouldAccept(plr, ...)
						if not should_accept then return end

						event.__ServerConnection(plr, ...)
						event:Fire(plr)
					end)
				elseif event.__ServerConnection then
					event[1].OnServerEvent:Connect(event.__ServerConnection)
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
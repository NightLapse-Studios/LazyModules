--!strict
--!native

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
	CurrentModule = "",
}

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local IsServer = game:GetService("RunService"):IsServer()

local CONTEXT = IsServer and "SERVER" or "CLIENT"

local SparseList = require(ReplicatedFirst.Util.SparseList)

--event abstraction modules
local Transmitter = require(script.Transmitter)
local Broadcaster = require(script.Broadcaster)
local Event = require(script.Event)

local Transmitters = Transmitter.Transmitters
local Broadcasters = Broadcaster.Broadcasters
local Events = Event.Events

mod.NewEvent = Event.NewEvent
mod.NewTransmitter = Transmitter.NewTransmitter
mod.NewBroadcaster = Broadcaster.NewBroadcaster

local mt_ClientTransmitter = Transmitter.client_mt
local mt_ServerTransmitter = Transmitter.server_mt
local mt_ClientBroadcaster = Broadcaster.client_mt
local mt_ServerBroadcaster = Broadcaster.server_mt
local mt_ClientEvent = Event.client_mt
local mt_ServerEvent = Event.server_mt

local WaitingList = SparseList.new()

function mod:GetEvent(identifier, cb, force_context: string?)
	if force_context and force_context ~= _G.Game.CONTEXT then
		return
	end

	local success = Event.Events.Identifiers:get(identifier, cb)
	if not success then
		error("\nEvent: " .. mod.CurrentModule .. " " .. identifier)
	end
end

function mod:GetTransmitter(identifier, cb, force_context: string)
	if force_context and force_context ~= _G.Game.CONTEXT then
		return
	end

	local success = Transmitter.Transmitters.Identifiers:get(identifier, cb)
	if not success then
		error("\nEvent: " .. mod.CurrentModule .. " " .. identifier)
	end
end

function mod:GetBroadcaster(identifier, cb, force_context: string)
	if force_context and force_context ~= _G.Game.CONTEXT then
		return
	end

	local success = Broadcaster.Broadcasters.Identifiers:get(identifier, cb)
	if not success then
		error("\nEvent: " .. mod.CurrentModule .. " " .. identifier)
	end
end



function mod.SetModule( module_name: string )
	assert(typeof(module_name) == "string")

	mod.CurrentModule = module_name
end


local function monitor_func(signal, ...)
	print(signal[1].Name)
end

local function __monitor(signal)
	signal.monitor = monitor_func
end

function mod:Monitor( ... )
	-- TODO: You can't put Signals.Events in here. We should probably sunset Events
	local signals = { ... }
	for i,v in signals do
		__monitor(v)
	end
end


-- In practice, the number 32 appears to be able to be 1
-- But I have a gut feeling that it's possible to validly use LazyModules but have delayed signals declared
local WAIT_LIMIT = 4

local function wait_for(async_table)
	local waited = 0
	while
		async_table:is_awaiting()
	do
		waited += 1
		local too_long = waited > WAIT_LIMIT
		if too_long ~= false then
			error("Took too long to resolve signals (should usually be 1 tick)\n\nContents:\n" .. WaitingList:dump())
		end

		if too_long then break end

		task.wait()
	end

	return waited
end

-- TODO: Many safety checks require some meta-communication with the server. eeeeghhh
function mod.BuildSignals(G)
	local wait_dur = 0
	wait_dur += wait_for(Event.Events.Identifiers)
	wait_dur += wait_for(Transmitter.Transmitters.Identifiers)
	wait_dur += wait_for(Broadcaster.Broadcasters.Identifiers)

	print("Waited " .. wait_dur .. " ticks")

	for module, identifers in Transmitters.Modules.provided do
		for ident, transmitter in identifers do
			local transmitter_str = "Transmitter `" .. module .. "::" .. ident

			if CONTEXT == "CLIENT" then
				setmetatable(transmitter, mt_ClientTransmitter)
			else
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
					if broadcaster.__ShouldAccept == false then
						warn(transmitter_str .. "has no config call to Builder:ShouldAccept(func)\nTherefore any client firing this event will be trusted!")
					end

					if broadcaster.__ShouldAccept then
						if typeof(broadcaster.__ShouldAccept) ~= "function" then
							error(transmitter_str .. "passed value is not a function")
						end
					end
				end

				setmetatable(broadcaster, mt_ServerBroadcaster)
			end
		end
	end

	for module, identifers in Events.Modules.provided do
		for ident, event in identifers do
			if CONTEXT == "CLIENT" then
				local event_str = "Event `" .. module .. "::" .. ident
				if event.Type ~= "Builder" then
					error(event_str .. "` is not a Builder (what did you do?)")
				end

				setmetatable(event, mt_ClientEvent)
			elseif CONTEXT == "SERVER" then
				local event_str = "Event `" .. module .. "::" .. ident
				if event.Type ~= "Builder" then
					error(event_str .. "` is not a Builder (what did you do?)")
				end

				setmetatable(event, mt_ServerEvent)
			end
		end
	end

	if G.Config.MonitorAllSignals then
		for module, identifers in Transmitters.Modules.provided do
			for _, event in identifers do
				__monitor(event)
			end
		end
		for module, identifers in Broadcasters.Modules.provided do
			for _, event in identifers do
				__monitor(event)
			end
		end
		for module, identifers in Events.Modules.provided do
			for _, event in identifers do
				__monitor(event)
			end
		end
	end
end

return mod
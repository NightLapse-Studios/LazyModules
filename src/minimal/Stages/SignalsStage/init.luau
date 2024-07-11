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
	SignalAPI = { }
}

local SignalAPI = mod.SignalAPI

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local IsServer = game:GetService("RunService"):IsServer()

local CONTEXT = IsServer and "SERVER" or "CLIENT"
local STAGE_NAME = "__build_signals"
local STAGE_PRIORITY = 1000

local SparseList = require(ReplicatedFirst.Lib.SparseList)
local Config = require(game.ReplicatedFirst.Config)

--event abstraction modules
local Transmitter = require(script.Transmitter)
local Broadcaster = require(script.Broadcaster)
local Event = require(script.Event)

export type Transmitter = Transmitter.Transmitter
export type Broadcaster = Broadcaster.Broadcaster
export type Event = Event.Event

local Transmitters = Transmitter.Transmitters
local Broadcasters = Broadcaster.Broadcasters
local Events = Event.Events

local mt_ClientTransmitter = Transmitter.client_mt
local mt_ServerTransmitter = Transmitter.server_mt
local mt_ClientBroadcaster = Broadcaster.client_mt
local mt_ServerBroadcaster = Broadcaster.server_mt
local mt_ClientEvent = Event.client_mt
local mt_ServerEvent = Event.server_mt

local WaitingList = SparseList.new()

type EventGetter = (Event) -> ()

SignalAPI.NewEvent = Event.NewEvent
SignalAPI.NewTransmitter = Transmitter.NewTransmitter
SignalAPI.NewBroadcaster = Broadcaster.NewBroadcaster

function SignalAPI:GetEvent(identifier: string, cb: EventGetter, force_context: string?)
	if force_context and force_context ~= _G.Game.CONTEXT then
		return
	end

	local success = Event.Events.Identifiers:get(identifier, cb)
	if not success then
		error("\nEvent: " .. self.CurrentModule .. " " .. identifier)
	end
end

function SignalAPI:GetTransmitter(identifier, cb, force_context: string)
	if force_context and force_context ~= _G.Game.CONTEXT then
		return
	end

	local success = Transmitter.Transmitters.Identifiers:get(identifier, cb)
	if not success then
		error("\nEvent: " .. self.CurrentModule .. " " .. identifier)
	end
end

function SignalAPI:GetBroadcaster(identifier, cb, force_context: string)
	if force_context and force_context ~= _G.Game.CONTEXT then
		return
	end

	local success = Broadcaster.Broadcasters.Identifiers:get(identifier, cb)
	if not success then
		error("\nEvent: " .. self.CurrentModule .. " " .. identifier)
	end
end

export type SignalAPI = typeof(SignalAPI)



local function run_module_stage(game, fn, mod_name: string)
	SignalAPI:SetModule(mod_name)
	fn(game, SignalAPI)
end

local function stage_finished_callback(game)
	mod.BuildSignals(game)
end

function mod.GiveLM(lm)
	lm.RegisterModuleStage(STAGE_NAME, STAGE_PRIORITY, run_module_stage, stage_finished_callback)
end



function SignalAPI.SetModule(self: SignalAPI, module_name: string )
	assert(typeof(module_name) == "string")

	self.CurrentModule = module_name
end

local function monitor_func(signal, ...)
	print(signal.Name)
end

local function __monitor(signal)
	signal.monitor = monitor_func
end

function mod.Monitor( ... )
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
function mod.BuildSignals(G: any)
	-- The exact form of dependency injection we want to eradicate
	local remote_wrapper = require(script.__remote_wrapper)
	remote_wrapper.GiveGame(G)

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

	if Config.MonitorAllSignals then
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
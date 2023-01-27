--!strict
--[[
]]
local mod = {
	GameEvents = {
		Verbs = { },
		Identifiers = { },
		Modules = { },
	}
}

local Verbs = mod.GameEvents.Verbs

local GameEvents = mod.GameEvents

local mt = { __index = mod }

--local INIT_CONTEXT = if game:GetService("RunService"):IsServer()  then "SERVER" else "CLIENT"

local Globals
local LazyString
local Signals
local unwrap_or_warn
local unwrap_or_error
local safe_require
local async_list

local IsServer = game:GetService("RunService"):IsServer()
local SocialService = game:GetService("SocialService")

local Players = game.Players

local remote_wrapper = require(script.Parent.__remote_wrapper)

type Verb = string
type Noun = string
type CGameEventConnection = (Player, Verb, Noun) -> nil
type SGameEventConnection = (Player, Verb, Noun) -> nil

-- These wrappers are named from the perspective of their callers
-- so the client one uses "FireServer" to transmit and vice-versa
local GameEventBuilder = {
	Type = "Builder",

	ClientConnection = function(self, func: CGameEventConnection)
		if not func then return self end
		if IsServer then return self end

		self.Configured.Client = true
		self.Connections += 1
		self[2][#self[2]+1] = func

		return self
	end,

	ServerConnection = function(self, func: SGameEventConnection)
		if not func then return self end
		if not IsServer then return self end

		self.Configured.Server = true
		self.Connections += 1
		self[2][#self[2]+1] = func

		return self
	end,

	ShouldAccept = function(self, func)
		unwrap_or_error(
			typeof(func) == "function",
			"Missing func for GameEvent"
		)

		self.__ShouldAccept = func
		return self
	end,

	Build = function(self)
		if IsServer then
			self[1].OnServerEvent:Connect(function(plr, n: Noun, noun: any)
				local should_accept = false
				if self.__ShouldAccept then
					should_accept = self.__ShouldAccept(plr, n, noun)
				else
					warn("GameEvent " .. self.Verb .. ":" .. self.Noun .. " does not have a ShouldAccept function")
					end

				if should_accept then
					--Note that this accesses the wrapper function below, as we do not index to the bindable event
					self:Fire(plr, noun)
				end
			end)
		else
			self[1].OnClientEvent:Connect(
				function(plr, noun: any)
					for i = 1, #(self[2]) do
						self[2][i](plr, noun)
					end

					for _, o in self.Implications do
						o[2]:Fire(plr, noun)
					end
				end
			)
		end
	end,

	Implies = function(self, noun: Noun)
		self.Implications[noun] = Signals.CurrentModule
		Signals:GetGameEvent(self.Verb, noun, function(E)
			self.Implications[noun] = E
		end)

		return self
	end
}
local ClientGameEvent = {
	Fire = function(self, noun: any)
		-- print("Fired " .. Globals.CONTEXT .. self[1].Name)
		--Note that this doesn't use the bindable events, those only happen in respons to a server firing a GE
		--Only server GEs can be valid
		self[1]:FireServer(self.Verb, self.Noun, noun)
	end
}
local ServerGameEvent = {
	Fire = function(self, actor: Player, noun: any)
		-- print("Fired " .. Globals.CONTEXT .. self[1].Name)
		assert(actor)

		actor = actor.UserId
		local v: Verb, n: Noun = self.Verb, self.Noun

		self[1]:FireAllClients(actor, noun)
		for i = 1, #(self[2]) do
			self[2][i](actor, noun)
		end

		for _, o in self.Implications do
			--print(v, o.Noun)
			o[2]:Fire(actor, noun)
		end
	end
}

local mt_GameEventBuilder = { __index = GameEventBuilder}
mod.client_mt = { __index = ClientGameEvent }
mod.server_mt = { __index = ServerGameEvent }

function mod.NewGameEvent(self: Builder, verb: Verb, noun: Noun)
	local id = verb .. noun

	local event = remote_wrapper(id, mt_GameEventBuilder)
	event[2] = {} -- stores functions for events on the same machine
	event.Connections = 0
	event.Verb = verb
	event.Noun = noun
	event.Implications = { }
	event.__ShouldAccept = false

	local _mod = GameEvents.Identifiers:inspect(id)
	unwrap_or_error(
		_mod == nil,
		LazyString.new("Re-declared GameEvent `", id, "` in `", self.CurrentModule, "`.\nOriginally declared here: `", _mod, "`")
	)

	GameEvents.Identifiers:provide(event, id)

	GameEvents.Verbs:provide(event, verb, noun)

	GameEvents.Modules:provide(event, self.CurrentModule, id)

	return event
end

function mod:__init(G, S)
	Globals = G

	--The one true require tree
	safe_require = require(game.ReplicatedFirst.Util.SafeRequire)
	safe_require:__init(G)
	safe_require = safe_require.require

	local err = require(game.ReplicatedFirst.Util.Error)
	unwrap_or_warn = err.unwrap_or_warn
	unwrap_or_error = err.unwrap_or_error

	LazyString = require(game.ReplicatedFirst.Util.LazyString)

	async_list = require(game.ReplicatedFirst.Util.AsyncList)
	async_list:__init(G)

	mod.GameEvents.Verbs = async_list.new(2)
	mod.GameEvents.Identifiers = async_list.new(1)
	mod.GameEvents.Modules = async_list.new(2)

	Signals = S
end

return mod
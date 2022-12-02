--!strict
--[[
]]
local mod = {
	GameEvents = {
		Verbs = { },
		Identifiers = { },
		Modules = { }
	}
}

local GameEvents = mod.GameEvents

local mt = { __index = mod }

--local INIT_CONTEXT = if game:GetService("RunService"):IsServer()  then "SERVER" else "CLIENT"

local Globals
local LazyString
local unwrap_or_warn
local unwrap_or_error
local safe_require

local IsServer = game:GetService("RunService"):IsServer()

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
		unwrap_or_error(
			self.Configured.Client == false,
			"Cannot have multiple recievers of a transmission object"
		)

		self.Configured.Client = true
		self[1].OnClientEvent:Connect(func)

		return self
	end,

	ServerConnection = function(self, func: SGameEventConnection)
		if not func then return self end
		if not IsServer then return self end
		unwrap_or_error(
			self.Configured.Server == false,
			"Cannot have multiple recievers of a transmission object"
		)

		self.Configured.Server = true
		self[1].OnServerEvent:Connect(func)

		return self
	end,

	ShouldAccept = function(self, func)
		unwrap_or_error(
			typeof(func) == "function",
			"Missing func for Broadcaster"
		)

		self.__ShouldAccept = func
		return self
	end,
}
local ClientGameEvent = {
	Fire = function(self)
		self[1]:FireServer(self.Verb, self.Noun)
	end,
}
local ServerGameEvent = {
	Fire = function(self, actor: Player)
		assert(actor)

		actor = actor.UserId
		local v: Verb, n: Noun = self.Verb, self.Noun

		for _, plr in pairs(Players:GetPlayers()) do
			self[1]:FireClient(plr, actor, v, n)
		end
	end,
}

local mt_GameEventBuilder = { __index = GameEventBuilder}
GameEvents.client_mt = { __index = ClientGameEvent }
GameEvents.server_mt = { __index = ServerGameEvent }

local Verbs = { }
function mod.NewGameEvent(self: Builder, verb: Verb, noun: Noun)
	local id = verb .. noun

	local event = remote_wrapper(id, mt_GameEventBuilder)
	event.Verb = verb
	event.Noun = noun
	event.__ShouldAccept = false
	event.__ServerConnection = false
	event.__ClientConnection = false

	local _mod = GameEvents.Identifiers[id]
	unwrap_or_error(
		_mod == nil,
		LazyString.new("Re-declared GameEvent `", id, "` in `", self.CurrentModule, "`.\nOriginally declared here: `", _mod, "`")
	)

	GameEvents.Identifiers[id] = event

	if not Verbs[verb] then
		Verbs[verb] = { }
	end

	local Nouns = Verbs[verb]
	Nouns[noun] = event

	local Modules = GameEvents.Modules
	Modules[self.CurrentModule] = Modules[self.CurrentModule] or { }
	Modules[self.CurrentModule][id] = event

	return event
end

function mod:__init(G)
	Globals = G

	--The one true require tree
	safe_require = require(game.ReplicatedFirst.Util.SafeRequire)
	safe_require:__init(G)
	safe_require = safe_require.require

	local err = require(game.ReplicatedFirst.Util.Error)
	unwrap_or_warn = err.unwrap_or_warn
	unwrap_or_error = err.unwrap_or_error

	LazyString = require(game.ReplicatedFirst.Util.LazyString)
end

return mod
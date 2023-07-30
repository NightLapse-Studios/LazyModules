--!strict


--[[
	Transmitters:

	Transmitters are a fire-and-forget event that clients and servers can send to eachother, just like normal remotes.
		Transmitters can be used to send data to all clients but you really shouldn't >:^|
		Broadcasters are there for that reason and these abstractions are valuable for code quality and visibility more
		than anything else
]]


local mod = {
	Transmitters = {
		Identifiers = { },
		Modules = { }
	}
}

local Transmitters = mod.Transmitters

--local INIT_CONTEXT = if game:GetService("RunService"):IsServer()  then "SERVER" else "CLIENT"

local Globals
local LazyString
local unwrap_or_warn
local unwrap_or_error
local safe_require
local async_list

local IsServer = game:GetService("RunService"):IsServer()

local remote_wrapper = require(script.Parent.__remote_wrapper).wrapper

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
		if self.monitor then
			self.monitor(self, ...)
		end

		self[1]:FireServer(...)
	end,
}
local ServerTransmitter = {
	Transmit = function(self, ...)
		if self.monitor then
			self.monitor(self, ...)
		end

		self[1]:FireClient(...)
	end,
	TransmitAll = function(self, ...)
		if self.monitor then
			self.monitor(self, ...)
		end

		self[1]:FireAllClients(...)
	end,
}

setmetatable(ClientTransmitter, { __index = TransmitterBuilder })
setmetatable(ServerTransmitter, { __index = TransmitterBuilder })

local mt_TransmitterBuilder = { __index = TransmitterBuilder }
mod.client_mt = { __index = ClientTransmitter }
mod.server_mt = { __index = ServerTransmitter }

function mod.NewTransmitter(self: Builder, identifier: string)
	local transmitter = remote_wrapper(identifier, mt_TransmitterBuilder)

--[[ 	local Modules = Transmitters.Modules
	Modules[self.CurrentModule] = Modules[self.CurrentModule] or { } ]]

	local _mod = Transmitters.Identifiers:inspect(identifier)
	unwrap_or_error(
		_mod == nil,
		LazyString.new("Re-declared event `", identifier, "` in `", self.CurrentModule, "`.\nOriginally declared here: `", _mod, "`")
	)

	Transmitters.Identifiers:provide(transmitter, identifier)
	Transmitters.Modules:provide(transmitter, self.CurrentModule, identifier)

	return transmitter
end

function mod:__init(G)
	Globals = G

	--The one true require tree
	safe_require = require(game.ReplicatedFirst.Util.SafeRequire)
	safe_require = safe_require.require

	local err = require(game.ReplicatedFirst.Util.Error)
	unwrap_or_warn = err.unwrap_or_warn
	unwrap_or_error = err.unwrap_or_error

	async_list = require(game.ReplicatedFirst.Util.AsyncList)
	async_list:__init(G)

	mod.Transmitters.Identifiers = async_list.new(1)
	mod.Transmitters.Modules = async_list.new(2)

	LazyString = require(game.ReplicatedFirst.Util.LazyString)
end

return mod
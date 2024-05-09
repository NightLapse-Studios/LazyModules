--!strict


--[[
	Transmitters:

	Transmitters are a fire-and-forget event that clients and servers can send to eachother, just like normal remotes.
		Transmitters can be used to send data to all clients but you really shouldn't >:^|
		Broadcasters are there for that reason and these abstractions are valuable for code quality and visibility more
		than anything else
]]


local async_list = require(game.ReplicatedFirst.Util.AsyncList)

local mod = {
	Transmitters = {
		Identifiers = async_list.new(1),
		Modules = async_list.new(2),
	}
}

local Transmitters = mod.Transmitters

--local INIT_CONTEXT = if game:GetService("RunService"):IsServer()  then "SERVER" else "CLIENT"

local IsServer = game:GetService("RunService"):IsServer()

local remote_wrapper = require(script.Parent.__remote_wrapper).wrapper

-- These wrappers are named from the perspective of their callers
-- so the client one uses "FireServer" to transmit and vice-versa
local TransmitterBuilder = {
	Type = "Builder",

	ClientConnection = function(self, func: opt_func)
		if not func then return self end
		if IsServer then return self end

		self[1].OnClientEvent:Connect(func)

		return self
	end,
	ServerConnection = function(self, func: opt_func)
		if not func then return self end
		if not IsServer then return self end

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

function mod.NewTransmitter(signals_module, identifier: string): Transmitter
	local transmitter = remote_wrapper(identifier, mt_TransmitterBuilder)

--[[ 	local Modules = Transmitters.Modules
	Modules[self.CurrentModule] = Modules[self.CurrentModule] or { } ]]

	local _mod = Transmitters.Identifiers:inspect(identifier)
	if _mod ~= nil then
		error("Re-declared event `" .. identifier .. "` in `" .. signals_module.CurrentModule .. "`.\nOriginally declared here: `" .. _mod .. "`")
	end

	Transmitters.Identifiers:provide(transmitter, identifier)
	Transmitters.Modules:provide(transmitter, signals_module.CurrentModule, identifier)

	return transmitter
end

export type Transmitter = typeof(mod.NewTransmitter({CurrentModule=""}, "Ex"))

return mod
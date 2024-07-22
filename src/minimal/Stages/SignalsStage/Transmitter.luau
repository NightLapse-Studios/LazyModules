--!strict


--[[
	Transmitters:

	Transmitters are a fire-and-forget event that clients and servers can send to eachother, just like normal remotes.
		Transmitters can be used to send data to all clients but you really shouldn't >:^|
		Broadcasters are there for that reason and these abstractions are valuable for code quality and visibility more
		than anything else
]]


local async_list = require(game.ReplicatedFirst.Lib.AsyncList)

local mod = {
	Transmitters = {
		Identifiers = async_list.new(1),
		Modules = async_list.new(2),
	}
}

local Transmitters = mod.Transmitters

local IsServer = game:GetService("RunService"):IsServer()

local remote_wrapper = require(script.Parent.remote_wrapper).wrapper

local TransmitterBuilder = ({
	STransmit = function(self, ...)
		if self.monitor then
			self.monitor(self, ...)
		end

		self.Event.Event:FireClient(...)
	end,
	STransmitAll = function(self, ...)
		if self.monitor then
			self.monitor(self, ...)
		end

		self.Event.Event:FireAllClients(...)
	end,
	CTransmit = function(self, ...)
		if self.monitor then
			self.monitor(self, ...)
		end

		self.Event.Event:FireServer(...)
	end,
	ClientConnection = function(self, func)
		if not func then return self end
		if IsServer then return self end

		self.Event.Event.OnClientEvent:Connect(func)

		return self
	end,
	ServerConnection = function(self, func)
		if not func then return self end
		if not IsServer then return self end

		self.Event.Event.OnServerEvent:Connect(func)

		return self
	end
} :: any) :: Transmitter
TransmitterBuilder.__index = TransmitterBuilder

export type Transmitter = {
	ClientConnection: <T, C...>(T, fn: (C...) -> ()) -> (T & {
		STransmit: (self: T, Player, C...) -> (),
		-- Discouraged over broadcasters
		STransmitAll: (self: T, C...) -> ()
	}),
	ServerConnection: <T, C...>(T, fn: (Player, C...) -> ()) -> (T & { CTransmit: (self: T, C...) -> ()}),
}

function mod.NewTransmitter(signals_module, identifier: string): Transmitter
	local transmitter = remote_wrapper(identifier, TransmitterBuilder)

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

return mod
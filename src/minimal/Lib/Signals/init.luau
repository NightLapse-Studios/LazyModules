--!strict

local Players = game:GetService("Players")
local RS = game:GetService("RunService")

local LMT = require(game.ReplicatedFirst.Lib.LMTypes)
local Game: LMT.LMGame = _G.Game

local RemoteWrapper = require(script.remote_wrapper)
local EventQueue = require(script.EventQueue)
local Config = require(game.ReplicatedFirst.Config)
local SerDesmond = require(game.ReplicatedFirst.Lib.SerDesmond)

local IsServer = RS:IsServer()
local IsClient = not IsServer

local function default_should_accept()
	return true
end

export type SignalCommon = {
	Type: "Broadcaster" | "Transmitter",
	Name: string,
	Wrapper: { Event: RemoteEvent } | false,
	Encoding: string?,
	UpConnectionTypeSet: boolean,
	DownConnectionTypeSet: boolean,
	Connections: { (...unknown) -> () },
	Monitor: true?
}

export type Transmitter = SignalCommon & {
	Type: Transmitter,
	SetEncoding: <T>(T, string) -> T,
	UpConnectionType: <T, C...>(T, ty: (Player, C...) -> ()) -> (T & {
		TransmitUp: (self: T, C...) -> (),
		UpConnection: <T>(T, con: (Player, C...) -> ()) -> T
	}),
	DownConnectionType: <T, C...>(T, ty: (C...) -> ()) -> (T & {
		TransmitDown: (self: T, plr: Player, C...) -> (),
		TransmitDownAll: (self: T, C...) -> (),
		DownConnection: <T>(T, con: (C...) -> ()) -> T
	})
}

export type Broadcaster = SignalCommon & {
	Type: "Broadcaster",
	ShouldAcceptFn: (Player, ...unknown) -> boolean,
	SetEncoding: <T>(T, string) -> T,
	UpConnectionType: <T, C...>(T, ty: (Player, C...) -> ()) -> (T & {
		BroadcastUp: (self: T, C...) -> (),
		UpConnection: <T>(T, con: (Player, C...) -> ()) -> T,
		ShouldAccept: <T>(T, fn: (Player, C...) -> boolean) -> T,
	}),
	DownConnectionType: <T, C...>(T, ty: (Player?, C...) -> ()) -> (T & {		
		BroadcastDown: (self: T, C...) -> (),
		BroadcastDownLikePlayer: (self: T, player: Player, C...) -> (),
		DownConnection: <T>(T, con: (plr: Player?, C...) -> ()) -> T
	}),
}

local RegisteredSignals: { [string]: Broadcaster | Transmitter } = { }

local mod = { }

local Transmitter = { }
Transmitter.__index = Transmitter

function Transmitter:SetEncoding(e: string)
	if self.Encoding then
		error("Encoding already set for " .. self.Name)
	end

	self.Encoding = e

	return self
end

-- The connection type functions are only used to generate type data
-- So they just need to return self!
function Transmitter:UpConnectionType(ty)
	self.UpConnectionTypeSet = true
	return self
end

function Transmitter:DownConnectionType(ty)
	self.DownConnectionTypeSet = true
	return self
end

function Transmitter:UpConnection(fn)
	if Game.CONTEXT == "SERVER" then
		table.insert(self.Connections, fn)
	end

	return self
end

function Transmitter:DownConnection(fn)
	if Game.CONTEXT == "CLIENT" then
		table.insert(self.Connections, fn)
	end
	
	return self
end

function Transmitter:TransmitUp(...)
	assert(IsClient)
	if self.Monitor then
		print(self.Name)
	end

	if self.Encoding then
		EventQueue.Submit(Players.LocalPlayer, self.Name, ...)
	else
		self.Wrapper.Event:FireServer(...)
	end
end

function Transmitter:TransmitDown(plr: Player, ...)
	assert(IsServer)
	if self.Monitor then
		print(self.Name)
	end

	if self.Encoding then
		EventQueue.Submit(plr, self.Name, ...)
	else
		self.Wrapper.Event:FireClient(plr, ...)
	end
end

function Transmitter:TransmitDownAll(...)
	assert(IsServer)
	if self.Monitor then
		print(self.Name)
	end

	if self.Encoding then
		EventQueue.Submit("All", self.Name, ...)
	else
		self.Wrapper.Event:FireAllClients(...)
	end
end

local Broadcaster = { }
Broadcaster.__index = Broadcaster

function Broadcaster:SetEncoding(e: string)
	if self.Encoding then
		error("Encoding already set for " .. self.Name)
	end

	self.Encoding = e

	return self
end

-- The connection type functions are only used to generate type data
-- So they just need to return self!
function Broadcaster:UpConnectionType(ty)
	self.UpConnectionTypeSet = true
	return self
end

function Broadcaster:DownConnectionType(ty)
	self.DownConnectionTypeSet = true
	return self
end

function Broadcaster:UpConnection(fn)
	if Game.CONTEXT == "SERVER" then
		table.insert(self.Connections, fn)
	end

	return self
end

function Broadcaster:DownConnection(fn)
	if Game.CONTEXT == "CLIENT" then
		table.insert(self.Connections, fn)
	end
	
	return self
end

function Broadcaster:ShouldAccept(fn)
	if self.ShouldAcceptFn ~= default_should_accept then
		error("Should accept function already set for Broadcaster " .. self.Name)
	end

	self.ShouldAcceptFn = fn

	return self
end

function Broadcaster:BroadcastUp(...)
	assert(IsClient)
	if self.Monitor then
		print(self.Name)
	end

	if self.Encoding then
		EventQueue.Submit(Players.LocalPlayer, self.Name, Players.LocalPlayer, ...)
	else
		self.Wrapper.Event:FireServer(...)
	end
end

local mock_no_plr = { UserId = 0 }
function Broadcaster:BroadcastDown(...)
	assert(IsServer)
	if self.Monitor then
		print(self.Name)
	end

	if self.Encoding then
		EventQueue.Submit("All", self.Name, mock_no_plr, ...)
	else
		self.Wrapper.Event:FireAllClients(mock_no_plr, ...)
	end
end

function Broadcaster:BroadcastDownLikePlayer(plr: Player, ...)
	assert(IsServer)
	if self.Monitor then
		print(self.Name)
	end

	if self.Encoding then
		EventQueue.Submit("All", self.Name, plr, ...)
	else
		self.Wrapper.Event:FireAllClients(plr, ...)
	end
end



function mod.NewTransmitter(name: string): Transmitter
	local t = {
		Type = "Transmitter",
		Name = name,
		Wrapper = false,
		Encoding = false,
		UpConnectionTypeSet = false,
		DownConnectionTypeSet = false,
		Connections = { },
		Monitor = if Config.MonitorAllSignals then true else nil,
	}

	if RegisteredSignals[name] then
		error(`Transmitter "{name}" already exists!`)
	end

	RegisteredSignals[name] = t
	setmetatable(t, Transmitter)

	return (t :: any) :: Transmitter
end

function mod.NewBroadcaster(name: string): Broadcaster
	local t = {
		Type = "Broadcaster",
		Name = name,
		Wrapper = false,
		Encoding = false,
		UpConnectionTypeSet = false,
		DownConnectionTypeSet = false,
		Connections = { },
		Monitor = if Config.MonitorAllSignals then true else nil,
		ShouldAcceptFn = default_should_accept
	}

	if RegisteredSignals[name] then
		error(`Broadcaster "{name}" already exists!`)
	end

	RegisteredSignals[name] = t
	setmetatable(t, Broadcaster)

	return (t :: any) :: Broadcaster
end

local SerialRemote: RemoteEvent
if RS:IsServer() then
	SerialRemote = Instance.new("RemoteEvent")
	SerialRemote.Name = "SerialRemote"
	SerialRemote.Parent = game.ReplicatedStorage
else
	SerialRemote = game.ReplicatedStorage:WaitForChild("SerialRemote") :: RemoteEvent
end

-- The init stage is configured to call this function after __init finishes
function mod.Build()
	local SerDesBody = ""
	for _,signal in RegisteredSignals do
		if signal.Type == "Broadcaster" then
			if signal.Encoding then
				if RS:IsClient() then
					SerDesBody ..= `\t@optional "{signal.Name}": periodic_array(array(player,{signal.Encoding})),\n`
				else
					SerDesBody ..= `\t@optional "{signal.Name}": periodic_array(array(player,{signal.Encoding})),\n`
				end
			else
				signal.Wrapper = RemoteWrapper.wrapper(signal.Name)

				if RS:IsClient() then
					for i,v in signal.Connections do
						signal.Wrapper.Event.OnClientEvent:Connect(v)
					end
				else
					for i,v in signal.Connections do
						signal.Wrapper.Event.OnServerEvent:Connect(v)
					end
				end
			end
		elseif signal.Type == "Transmitter" then
			if signal.Encoding then
				SerDesBody ..= `\t@optional "{signal.Name}": periodic_array(array({signal.Encoding})),\n`
			else
				signal.Wrapper = RemoteWrapper.wrapper(signal.Name)

				if RS:IsClient() then
					for i,v in signal.Connections do
						signal.Wrapper.Event.OnClientEvent:Connect(v)
					end
				else
					for i,v in signal.Connections do
						signal.Wrapper.Event.OnServerEvent:Connect(v)
					end
				end
			end
		end
	end

	if string.len(SerDesBody) > 0 then
		local SerDes = `struct(\n{SerDesBody}\n)`

		print(SerDes)

		local ser, des, _ = SerDesmond.Compile(SerDes, true)

		if RS:IsServer() then
			RS.Heartbeat:Connect(function()
				local plrs: { Player | "All" } = Players:GetPlayers()
				table.insert(plrs, "All")

				for _, plr in plrs do
					local queue = EventQueue.GetFromPlayer(plr)
					if not queue then continue end

					local has_keys = false
					for i,v in queue do
						has_keys = true
						break
					end

					if not has_keys then continue end

					local msg = ser(queue)
					if plr == "All" then
						SerialRemote:FireAllClients(msg)
					else
						SerialRemote:FireClient(plr, msg)
					end

					EventQueue.Clear(plr)
				end
			end)

			SerialRemote.OnServerEvent:Connect(function(plr, msg: buffer)
				local obj: EventQueue.Queue = des(msg)

				for event_name, events in obj do
					local signal = RegisteredSignals[event_name]
					
					if signal.Type == "Transmitter" then
						for i,v in events do
							for _, fn in signal.Connections do
								task.spawn(fn, plr, table.unpack(v))
							end
						end
					elseif signal.Type == "Broadcaster" then
						for i,v in events do
							local errored, is_ok = pcall(signal.ShouldAcceptFn, plr, table.unpack(v))

							if errored then
								warn("Error in ShouldAccept for Broadcaster " .. signal.Name)
								continue
							end

							if not is_ok then
								continue
							end

							for _, fn in signal.Connections do
								task.spawn(fn, plr, table.unpack(v))
							end

							signal:BroadcastDownLikePlayer(plr, table.unpack(v))
						end
					end
				end
			end)
		else
			RS.Heartbeat:Connect(function()
				local queue = EventQueue.GetFromPlayer(Players.LocalPlayer)
				if not queue then return end

				local has_keys = false
				for i,v in queue do
					has_keys = true
					break
				end

				if not has_keys then return end

				local msg = ser(queue)
				SerialRemote:FireServer(msg)
				EventQueue.Clear(Players.LocalPlayer)
			end)

			SerialRemote.OnClientEvent:Connect(function(msg: buffer)
				local obj = des(msg)

				for event_name, events in obj do
					local signal = RegisteredSignals[event_name]

					for i,v in events do
						for _, fn in signal.Connections do
							task.spawn(fn, table.unpack(v))
						end
					end
				end
			end)
		end
	end
end

function mod.Monitor(signal)
	signal.Monitor = true
end

return mod
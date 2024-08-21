--!strict
--!native

local LMT = require(game.ReplicatedFirst.Lib.LMTypes)
local Signals = require(game.ReplicatedFirst.Lib.Signals)

-- May need to raise this value in a non-local (non-studio) environment
local SIGNAL_TIMEOUT = 1

local TestPlayer: Player?
local confirmations = { }

local TestConfirmationTransmitter = Signals.NewTransmitter("TestConfirmationTransmitter")
	:DownConnectionType(function(name: string) end)
	:UpConnectionType(function(plr, name: string) end)
	:UpConnection(function(plr, name: string)
		if name == "Handshake" then
			TestPlayer = plr
		end

		confirmations[name] = true
	end)
	:DownConnection(function(name: string)
		confirmations[name] = true
	end)
local TestBroadcaster = Signals.NewBroadcaster("TestBroadcaster")
	:DownConnectionType(function() end)
	:UpConnectionType(function(plr) end)
	:UpConnection(function(plr)
		if plr then
			TestConfirmationTransmitter:TransmitDown(plr, "TestBroadcaster")
		end
	end)
	:DownConnection(function()
		TestConfirmationTransmitter:TransmitUp("TestBroadcaster")
	end)

local TestTransmitter = Signals.NewTransmitter("TestTransmitter")
	:UpConnectionType(function(plr) end)
	:DownConnectionType(function() end)
	:UpConnection(function(plr)
		TestConfirmationTransmitter:TransmitDown(plr, "TestTransmitter")
	end)
	:DownConnection(function()
		TestConfirmationTransmitter:TransmitUp("TestTransmitter")
	end)


local function client_signals()
    -- An initial event to give the server a player to send its events to
    TestConfirmationTransmitter:TransmitUp("Handshake")
    TestBroadcaster:BroadcastUp()
    TestTransmitter:TransmitUp()
end

local function server_signals()
    while not confirmations.Handshake do
        task.wait()
    end

	assert(TestPlayer)
    
    TestBroadcaster:BroadcastDown()
    TestTransmitter:TransmitDown(TestPlayer)
end

local mod = { } :: LMT.LazyModule

function mod.__tests(G: LMT.LMGame, T: LMT.Tester)
    if G.CONTEXT == "CLIENT" then
        client_signals()
    elseif G.CONTEXT == "SERVER" then
        server_signals()
    end
    
    local waited = 0
    local did_timeout = false
    while not (
        confirmations.TestTransmitter and
        confirmations.TestBroadcaster
    ) do
        waited += task.wait()
        if waited > SIGNAL_TIMEOUT then
            did_timeout = true
        end
    end

	T:Test("Not time out", function()
		T:ForContext("ever",
			T.Equal, did_timeout, false,
			T.LessThan, waited, SIGNAL_TIMEOUT
		)
	end)

	T:Test("Communicate with", function()
        T:ForContext("Broadcasters",
            T.Equal, confirmations.TestBroadcaster, true
        )

		T:ForContext("Transmitters",
			T.Equal, confirmations.TestTransmitter, true
		)
    end)
end

return mod
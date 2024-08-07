--!strict
--!native

local LMT = require(game.ReplicatedFirst.Lib.LMTypes)

-- May need to raise this value in a non-local (non-studio) environment
local SIGNAL_TIMEOUT = 1

local TestBroadcaster
local TestTransmitter
-- TODO: Test events
-- local TestEvent
local TestConfirmationTransmitter

local TestPlayer: Player?

local confirmations = { }

local mod = { } :: LMT.LazyModule

function mod.__build_signals(G, B: LMT.Signals)
    TestConfirmationTransmitter = B:NewTransmitter("TestConfirmationTransmitter")
        :ServerConnection(function(plr, name: string)
            if name == "Handshake" then
                TestPlayer = plr
            end

            confirmations[name] = true
        end)
        :ClientConnection(function(name: string)
            confirmations[name] = true
        end)

    TestBroadcaster = B:NewBroadcaster("TestBroadcaster")
        :ShouldAccept(function(plr, test_cond: boolean)
            return test_cond
        end)
        :ServerConnection(function(plr, _: boolean)
            -- plr will be nill if a broadcast originates on the server
            if plr then
                TestConfirmationTransmitter:STransmit(plr, "TestBroadcaster")
            end
        end)
        :ClientConnection(function()
            TestConfirmationTransmitter:CTransmit("TestBroadcaster")
        end)

    TestTransmitter = B:NewTransmitter("TestTransmitter")
        :ServerConnection(function(plr)
            TestConfirmationTransmitter:STransmit(plr, "TestTransmitter")
        end)
        :ClientConnection(function(name: string)
            TestConfirmationTransmitter:CTransmit("TestTransmitter")
        end)
end

local function client_signals()
    -- An initial event to give the server a player to send its events to
    TestConfirmationTransmitter:CTransmit("Handshake")
    TestBroadcaster:CBroadcast(true)
    TestTransmitter:CTransmit()
end

local function server_signals()
    while not confirmations.Handshake do
        task.wait()
    end
    
    TestBroadcaster:SBroadcast(true)
    TestTransmitter:STransmit(TestPlayer, true)
end

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
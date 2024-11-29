--!strict
--!native

local LMT = require(game.ReplicatedFirst.Lib.LMTypes)
local Signals = require(game.ReplicatedFirst.Lib.Signals)

-- May need to raise this value in a non-local (non-studio) environment
local SIGNAL_TIMEOUT = 1

local TestPlayer: Player?
local confirmations: { [string]: string | true | nil } = { }

local TestConfirmationTransmitter = Signals.NewTransmitter("TestConfirmationTransmitter")
	:DownConnectionType(function(name: string, err: string?) end)
	:UpConnectionType(function(plr, name: string, err: string?) end)
	:UpConnection(function(plr, name, err)
		if name == "Handshake" then
			TestPlayer = plr
		end

		confirmations[name] = err or true
	end)
	:DownConnection(function(name, err)
		confirmations[name] = err or true
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

local PackingTestsRun = 0
local BufferPackingTest = Signals.NewTransmitter("BufferPackingTest")
	:SetEncoding([[ periodic_array(u8) ]])
	:UpConnectionType(function(plr, dat: {number}) end)
	:DownConnectionType(function(dat: {number}) end)
	:UpConnection(function(plr, dat)
		PackingTestsRun += 1
		for i = 1, 32, 1 do
			if dat[i] ~= i then
				TestConfirmationTransmitter:TransmitDown(plr, "BufferPackingTest", `Index {i} was {dat[i]}`)
			end
		end
		
		if PackingTestsRun == 5 then
			TestConfirmationTransmitter:TransmitDown(plr, "BufferPackingTest")
		end
	end)
	:DownConnection(function(dat)
		PackingTestsRun += 1
		for i = 1, #dat, 1 do
			if dat[i] ~= i then
				TestConfirmationTransmitter:TransmitUp("BufferPackingTest", `Index {i} was {dat[i]}`)
			end
		end
		
		if PackingTestsRun == 5 then
			TestConfirmationTransmitter:TransmitUp("BufferPackingTest")
		end
	end)

local function packing_test_data()
	local dat = { }
	for i = 1, math.random(8, 33), 1 do
		dat[i] = i
	end

	return dat
end


local function client_signals()
    -- An initial event to give the server a player to send its events to
    TestConfirmationTransmitter:TransmitUp("Handshake")
    TestBroadcaster:BroadcastUp()
    TestTransmitter:TransmitUp()
	BufferPackingTest:TransmitUp(packing_test_data())
	BufferPackingTest:TransmitUp(packing_test_data())
	BufferPackingTest:TransmitUp(packing_test_data())
	BufferPackingTest:TransmitUp(packing_test_data())
	BufferPackingTest:TransmitUp(packing_test_data())
end

local function server_signals()
    while not confirmations.Handshake do
        task.wait()
    end
	
	assert(TestPlayer)
    
    TestBroadcaster:BroadcastDown()
    TestTransmitter:TransmitDown(TestPlayer)
	BufferPackingTest:TransmitDown(TestPlayer, packing_test_data())
	BufferPackingTest:TransmitDown(TestPlayer, packing_test_data())
	BufferPackingTest:TransmitDown(TestPlayer, packing_test_data())
	BufferPackingTest:TransmitDown(TestPlayer, packing_test_data())
	BufferPackingTest:TransmitDown(TestPlayer, packing_test_data())
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

	T:Test("Single Remote buffer packing", function()
		T:ForContext("should just work",
			T.Equal, confirmations.BufferPackingTest, true
		)
	end)
end

return mod
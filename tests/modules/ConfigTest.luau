--!strict
--!native

-- Just a little sanity file to make sure tests are on and config is as needed for other tests.

assert(Config.TESTING == true, "Didn't even turn testing on you silly goose")
local Config = require(game.ReplicatedFirst.Lib.Config)

local mod = { } :: LMT.LazyModule


local LMT = require(game.ReplicatedFirst.Lib.LMTypes)
function mod.__tests(G: LMT.LMGame, T: LMT.Tester)
	T:Test("Have proper values", function()
		T:ForContext("LM Testing project",
			T.Equal, Config.TESTING, true,
			T.Equal, typeof(Config.FocusTestOn), "boolean",
			T.Equal, Config.SaveDatastoresInStudio, true,
			T.Equal, Config.PlaceId, game.PlaceId
		)
	end)
end

return mod
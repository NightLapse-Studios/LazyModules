local LMT = require(game.ReplicatedFirst.Util.LMTypes)
local Config = require(game.ReplicatedFirst.Util.Config.Config)

local mod = { } :: LMT.LazyModule

assert(Config.TESTING == true, "Didn't even turn testing on you silly goose")

function mod:__test(G: LMT.LMGame, T: LMT.Tester)
	warn("123123123123")
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
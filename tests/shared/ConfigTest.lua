local Config = require(game.ReplicatedFirst.Util.Config)

local mod = { }

function mod:__test(G, T)
	T:Test("Have proper values", function()
		T:ForContext("LM Testing project",
			T.Equal, Config.TESTING, true,
			T.Equal, typeof(Config.FocusTestOn), "boolean",
			T.Equal, Config.SaveDatastoresInStudio, true,
			T.Equal, Config.PlaceId, game.PlaceId
		)
	end)
end

function mod:__init(G)
	assert(Config.TESTING == true, "Didn't even turn testing on you silly goose")
end

return mod
local LMT = require(game.ReplicatedFirst.Lib.LMTypes)

local mod = { }

local Stages = { }

function mod.__init(G)
	table.insert(Stages, "__init")
end
function mod.__build_signals(G)
	table.insert(Stages, "__build_signals")
end
function mod.__run(G)
	table.insert(Stages, "__run")
end
function mod.__ui(G, I, P, R)
	table.insert(Stages, "__ui")
end
function mod.__tests(G, T: LMT.Tester)
	table.insert(Stages, "__tests")

	T:Test("Start in the right order", function()
		T:ForContext("full+ tiers",
			T.Equal, "__init", Stages[1],
			T.Equal, "__build_signals", Stages[2],
			T.Equal, "__ui", Stages[3],
			T.Equal, "__run", Stages[4],
			T.Equal, "__tests", Stages[5]
		)
	end)
end

return mod

local LMT = require(game.ReplicatedFirst.Lib.LMTypes)

local mod = { }

local Stages = { }

function mod.__init(G)
	table.insert(Stages, "__init")
end
function mod.__run(G)
	table.insert(Stages, "__run")
end
function mod.__ui(G, I, P, R)
	table.insert(Stages, "__ui")
end
function mod.__tests(G, T: LMT.Tester)
	table.insert(Stages, "__tests")

	if G.CONTEXT == "SERVER" then
		T:Test("Start in the right order", function()
			T:ForContext("full+ tiers",
				T.Equal, Stages[1], "__init",
				T.Equal, Stages[2], "__run",
				T.Equal, Stages[3], "__tests"
			)
		end)
	else
		T:Test("Start in the right order", function()
			T:ForContext("full+ tiers",
				T.Equal, Stages[1], "__init",
				T.Equal, Stages[2], "__ui",
				T.Equal, Stages[3], "__run",
				T.Equal, Stages[4], "__tests"
			)
		end)
	end
end

return mod

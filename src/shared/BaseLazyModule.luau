--!strict
--!native

local LMT = require(game.ReplicatedFirst.Util.LMTypes)
local Config = require(game.ReplicatedFirst.Util.Config.Config)

local mod = { }

function mod.__init(G: LMT.LMGame)

end

function mod.__build_signals(G: LMT.LMGame, B: LMT.Signals)

end

function mod.__ui(G: LMT.LMGame, I: LMT.Pumpkin, P: LMT.PropSet)

end

function mod.__run(G: LMT.LMGame)

end

function mod.__tests(G: LMT.LMGame, T: LMT.Tester)

end

function mod.__get_gamestate(G: LMT.LMGame, plr: Player)

end

function mod.__load_gamestate(G: LMT.LMGame, data: LMT.GameStateData, loaded: LMT.LoadedFunc, after: LMT.AfterLoadedFunc)

end

return mod
--!strict

local Signals = require(game.ReplicatedFirst.Lib.Signals)

local STAGE_NAME = "signals"
local STAGE_PRIORITY = 1000

local mod = { }

function mod.GiveLM(lm)
	lm.RegisterGlobalStage(STAGE_NAME, STAGE_PRIORITY, Signals.Build)
end

return mod
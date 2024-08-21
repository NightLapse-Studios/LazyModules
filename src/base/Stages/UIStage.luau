local STAGE_NAME = "__ui"
local STAGE_PRIORITY = 3000

local Pumpkin = require(game.ReplicatedFirst.Lib.Pumpkin)

local mod = { }

local function run_module_stage(game, fn, mod_name: string)
	fn(game, Pumpkin, Pumpkin.P, Pumpkin.Roact)
end

function mod.GiveLM(lm)
	lm.RegisterModuleStage(STAGE_NAME, STAGE_PRIORITY, run_module_stage, nil, function() return game:GetService("RunService"):IsClient() end)
end

return mod
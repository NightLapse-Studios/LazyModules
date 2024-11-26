--!strict

local STAGE_NAME = "__init"
local STAGE_PRIORITY = 0

local mod = { }

local function run_module_stage(game, fn, mod_name: string)
	task.spawn(fn, game)
end

function mod.GiveLM(lm)
	lm.RegisterModuleStage(STAGE_NAME, STAGE_PRIORITY, run_module_stage)
end

return mod
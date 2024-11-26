local STAGE_NAME = "__run"
local STAGE_PRIORITY = 4000

local mod = { }

local function run_module_stage(game, fn, mod_name: string)
	task.spawn(fn, game)
end

function mod.GiveLM(lm)
	lm.RegisterModuleStage(STAGE_NAME, STAGE_PRIORITY, run_module_stage)
end

return mod
local STAGE_NAME = "__run"

local mod = { }

local function run_module_stage(game, fn, mod_name: string)
	fn(game)
end

function mod.GiveLM(lm)
	lm.RegisterModuleStage(STAGE_NAME, 1000, run_module_stage)
end

return mod
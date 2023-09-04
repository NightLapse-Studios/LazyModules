
-- `require` all modules
print("\n\t\t\tCOLLECT\n")

-- local Secrets = pcall(require, game.ServerScriptService.Secrets)
local safe_require = require(game.ReplicatedFirst.Util.SafeRequire).require

local Main = safe_require(game.ServerScriptService.Main)
local Game, err, traceback =  safe_require(game.ReplicatedFirst.Util.LazyModules.Game)
if err then
	-- Secrets.SendPanicReport(traceback, "Error during server startup")
	error(traceback)
else
	-- The __init functions form a dependency tree that will call __init in a depth-first order
	print("\n\t\t\tBEGIN\n\n")
	local co = coroutine.create(Game.Begin)
	local succ, ret = coroutine.resume(co, Main)

	if not succ then
		local traceback = ret .. "\n" .. debug.traceback(co)
		-- Secrets.SendPanicReport(traceback, "Server error during Game.Begin")
		error(traceback)
	end
end
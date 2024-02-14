
-- Main is has a special behavior with module-scope execution.
-- In the Startup scripts, Main is required before Game, which means this is the first meaningful code to execute
-- in the entire game, other than the loading screen. Anything done here also runs before LazyModules.
-- But note the __init functions; LazyModules still manages this script.
--
-- _G.Game is not available to module-scope code unless __init caches it in an upvalue

local mod = { }

function mod:__init(G)
	
end

function mod:__finalize(G)
	
end

return mod

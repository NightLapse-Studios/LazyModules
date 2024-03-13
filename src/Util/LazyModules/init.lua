--!strict
--[[
	This module is required from the client/server global scripts.
	Its role is to take over all module loading after it is required from globals

	Any module depended that this module depends on must use regular `require`
		and potentially emulate the call to `__init(self, G)`

	Any module loaded using `Load` or `PreLoad` will be tracked and intialized by this module
	Modules managed by this must be a table without special metatable redirection.
		For example Roact implements `strict.lua` which will not allow us to *check* for missing fields in Roact modules
		The solution chosen here is to turn the error into a warning... rip startup output.


	Primary goals:
		Answer the question "When does this code run"
		Answer "When can I run this code"
		Answer "Does this code depend on some state, or is it depended on by some state?"
		Identify dependency issues before they would cause a problem
		Make it obvious where the organization in a module comes from
		Prevent module communication from being used in unintended ways
		Make network communication obvious
		Implement abstractions for common design patterns
			(e.g. network communication has Transmitters (server <-> client) and Broadcasters (client-> server?-> all_clients)
			(see `Signals.lua`)
		Make single-file client-server scripts feasible and safer than multi-file approaches ( TODO: completeness )
			(still allowing for multi-file approaches, but there will be fewer safety checks)


`__init(G)`:
	FUNCTION, selfcall?

	Calls `G.Load` on required modules and other behavior that requires other systems to be availalbe

`__no_preload`:
	FLAG, boolean?

__no_preload modules may depend on pre-loaded modules but pre-loaded modules will still be initialized in the same
	phase as all others. __no_preload modules need to be manually loaded at a special time
	(I don't know of other use cases than to define a custom load step for getting server data)

`__build_signals`:(G, B):
	FUNCTION, selfcall?

	Use a Builder object to make structured network events and cross-module signals. It's just fancy wrappers around
		events but applies rules that implement structures to help organize networked code, and prevent abuse of
		hooking things.

`__finalize(G)`:
	FUNCTION, selfcall?

	Start executing some runtime behavior. Signals are guaranteed to exist and other modules are assumed to be working
		as if the game is running but not loaded.
	This is the first step on the client in which standard server data such as PlayerStats exists

`__run(G)`:
	FUNCTION, selfcall?

	A final finalization step, really. Things such as UI all rely on eachother which also all rely on PlayerStats
		So without this step there would be no UI file capable of setting the initial page of the menu since not even
		interface.lua can have any guarantees about when it is hit by __finalize relative to other modules


	Additionally, LazyModules exposes some other general
]]
local mod = {
	--TODO: This flag needs to be removed
	Initialized = false,
	Signals = false,

	CONTEXT = if game:GetService("RunService"):IsServer()  then "SERVER" else "CLIENT",
}

local CollectedModules: { [string]: script }  = { }
local PreLoads: { [string]: script } = { }
local Initialized: {[string]: boolean} = { }

local LOAD_CONTEXTS = require(game.ReplicatedFirst.Util.Enums).LOAD_CONTEXTS
local CONTEXT = mod.CONTEXT
local SOURCE_NAME = debug.info(function() return end, "s")

local Roact = require(game.ReplicatedFirst.Util.Roact)
local Config = require(game.ReplicatedFirst.Util.Config)
local AsyncList = require(game.ReplicatedFirst.Util.AsyncList)

local depth = 0


local Game
-- This module is required from __run in this module
-- Because it needs to go through the whole loading process in order to rely on Assets, etc
local UI
local Signals
local Tests
local safe_require

-- Convenience function
local function indent()
	local _indent = ""
	for i = 1, depth, 1 do
		_indent = _indent .. " | "
	end

	return _indent
end

-- Determine for our scripts if they are initializing or not
local function set_context(context: number)
	local prior = Game.LOADING_CONTEXT

	-- Do some additional context considerations and error checking
	--prior, context = process_context(prior, context)

	-- If our new context is initializing, then the prior contexts must have been initializing too.
	if context == LOAD_CONTEXTS.LOAD_INIT then
		if not (prior >= LOAD_CONTEXTS.LOAD_INIT) then
			error("\n" .. CONTEXT .. " init: Module is attempting to load during pre-loading" ..
				"Hint: if LazyModules executes an `__init` function, then it must be caused by another module's `__init` function\nExcept for the first module in the init tree")
		end
	end

	Game.LOADING_CONTEXT = context

	return prior
end

local function reset_context(prev: number)
	Game.LOADING_CONTEXT = prev
end

local function warn_load_err(name: string)
	warn("Module \"" .. name .. "\" wasn't found by LazyModules. Use `ModuleCollectionFolders` & `ModuleCollectionBlacklist` to control what LazyModules sees")
end

function mod.format_lazymodules_traceback()
	local traceback = ""

	local stack_idx = 0
	repeat
		stack_idx += 1
		local source, line, fn_name = debug.info(stack_idx, "sln")

		if source == SOURCE_NAME then
			continue
		end

		if not source then
			break
		end

		traceback = traceback .. source .. ":" .. line .. " function " .. fn_name .. "\n"
	until false

	return traceback
end

local function init_wrapper(module, name)
	local s, r = pcall(function() return module.__no_lazymodules end)
	if s and r then
		return
	end

	local prior_context = set_context(LOAD_CONTEXTS.LOAD_INIT)
	if typeof(module.__init) ~= "function" then
		-- Some legacy decisions for Roact's ability to be managed by LM have necessitated this check
		-- TODO: Fix? Remove?
		return
	end

	module:__init(Game)
	reset_context(prior_context)
end

local function signals_wrapper(module, name)
	local s, r = pcall(function() return module.__no_lazymodules end)
	if s and r then
		return
	end

	local prior_context = set_context(LOAD_CONTEXTS.SIGNAL_BUILDING)

	-- Configure the builder for this module
	local builder = Signals:Builder( name )

	-- Pass the builder to the module
	-- The module will use the builder to register its signals
	if typeof(module.__build_signals) ~= "function" then
		-- Some legacy decisions for Roact's ability to be managed by LM have necessitated this check
		-- TODO: Fix? Remove?
		print(0)
		return
	end
	module:__build_signals(Game, builder)
	reset_context(prior_context)
end

local function get_gamestate_wrapper(module, plr)
	local s, r = pcall(function() return module.__no_lazymodules end)
	if s and r then
		return
	end

	-- player being necessary for gamestate is unlikely, but incase necessary.
	-- @param name is a the name of the module on the client that should receive this state via __load_gamestate,
	-- will default to the name of the module.
	local state, name = module:__get_gamestate(plr)
	
	return state, name
end

local function load_gamestate_wrapper(module, modulestate, loadedList, moduleName)
	local s, r = pcall(function() return module.__no_lazymodules end)
	if s and r then
		return
	end

	local prior_context = set_context(LOAD_CONTEXTS.LOAD_GAMESTATE)
	
	local loaded_func = function()
		loadedList:provide(true, moduleName)
	end
	local after_func = function(name, callback)
		loadedList:get(name, callback)
	end

	if not modulestate then
		loaded_func()
	else
		-- @param1, the state returned by __get_gamestate
		-- @param2, a function that you MUST call when you have finished loading, see Gamemodes.lua for a good example.
		-- @param3, a function that you can pass another module name into to ensure its state loades before your callback is called.
		module:__load_gamestate(modulestate, loaded_func, after_func)
	end
	
	reset_context(prior_context)
end

local function tests_wrapper(module, name)
	local s, r = pcall(function() return module.__no_lazymodules end)
	if s and r then
		return
	end

	-- Configure the builder for this module
	local builder = Tests:Builder( name )

	-- __tests **may** yield, we leverage this as a feature
	-- However it means that __tests cannot rely on eachother (probably a good thing)
	module:__tests(Game, builder)
	builder:Finished()
end

local function finalize_wrapper(module, name)
	local s, r = pcall(function() return module.__no_lazymodules end)
	if s and r then
		return
	end

	local prior_context = set_context(LOAD_CONTEXTS.FINALIZE)
	module:__finalize(Game)
	reset_context(prior_context)
end

local function ui_wrapper(module, name)
	local s, r = pcall(function() return module.__no_lazymodules end)
	if s and r then
		return
	end

	local prior_context = set_context(LOAD_CONTEXTS.RUN)

	-- Note that UI will not exist on server contexts
	if Config.LogUIInit then
		print(" -- > UI INIT: " .. name)
	end

	module:__ui(Game, UI, UI.P, Roact)
	reset_context(prior_context)
end

local function run_wrapper(module, name)
	local s, r = pcall(function() return module.__no_lazymodules end)
	if s and r then
		return
	end

	local prior_context = set_context(LOAD_CONTEXTS.RUN)

	-- Note that UI will not exist on server contexts
	module:__run(Game, UI)
	reset_context(prior_context)
end

local function try_init(module, name, astrisk)
	astrisk = astrisk or ""

	if Initialized[name] ~= true then
		Initialized[name] = true
		depth += 1

		if Config.LogLoads then
			print(indent() .. name .. astrisk)
		end

		local s, r = pcall(function() return module.__init end)
		if s and r then
			init_wrapper(module, name)
		end
		s, r = pcall(function() return module.__build_signals end)
		if s and r then
			signals_wrapper(module, name)
		end

		depth -= 1
	end
end

--[[
	Some modules return using metatables that allows PreLoad to have side effects
	This avoids indexing
	A string is also required so that naming overrides are processed by the time __raw_load is called
]]
function mod.__raw_load(script: Instance, name: string): any
	local prior_context = set_context(LOAD_CONTEXTS.PRELOAD)

	local module = safe_require(script)

	if typeof(module) ~= "table" then
		return
	end

	reset_context(prior_context)
	
	-- Guard against multiple inits on one module
	if Initialized[name] ~= nil then
		return module
	end

	CollectedModules[name] = module
	PreLoads[name] = module
	Initialized[name] = false

	return module
end

function mod.PreLoad(script: Instance, opt_name: string?): any
	-- This check was discovered because referencing string.Name doesn't error, but returns nil for some reason
	-- It is common to mistakenly pass a string into thie function
	if typeof(script.Name) ~= "string" then
		error("Value passed into LazyModules.PreLoad must be a script")
	end

	opt_name = opt_name or script.Name

	local module = CollectedModules[opt_name]
	if not module then
		if Config.LogPreLoads then
			print(opt_name)
		end

		module = mod.__raw_load(script, opt_name)
	end

	return module
end

function mod.Load(script: (string | Instance)): any?
	local module
	if typeof(script) == "string" then
		-- A script's name has been passed in
		module = CollectedModules[script]

		if not module then
			warn_load_err(script)
			return
		end
	elseif script then
		-- A script has been passed in
		module = mod.__raw_load(script, script.Name)

		if not module then
			warn_load_err(script.Name)
		end

		try_init(module, script.Name, " **FROM INSTANCE**")

		return module
	end

	try_init(module, script)

	return module
end

function mod.LightLoad(script: Instance): any?
	local module

	-- A script has been passed in
	module = mod.__raw_load(script, script.Name)

	try_init(module, script.Name)

	local s, r
	if CONTEXT == "CLIENT" then
		s, r = pcall(function() return module.__ui end)
		if s and r then
			ui_wrapper(module, script.Name)
		end
	end

	if module.__run or module.__finalize then
		warn("Module `" .. script.Name .. "` has loading stages which are not supported by LightLoad")
		--warn("\tRequired from:\n" .. mod.format_lazymodules_traceback())
	end

	return module
end



local CollectionBlacklist = Config.ModuleCollectionBlacklist
local ContextCollectionBlacklist = if CONTEXT == "SERVER" then Config.ModuleCollectionBlacklist.Server else Config.ModuleCollectionBlacklist.Client

local function recursive_collect(instance: Instance)
	for _,v in instance:GetChildren() do
		if table.find(CollectionBlacklist, v) or table.find(ContextCollectionBlacklist, v) then
			continue
		end

		if typeof(v) ~= "Instance" then
			continue
		end

		if v:IsA("Folder") then
			recursive_collect(v)
			continue
		end

		if not v:IsA("ModuleScript") then
			continue
		end

		-- This is kind of flimsy since PreLoad can do this on its own
		-- TODO: A Call to PreLoad before we collect can cause false positives
		if CollectedModules[v.Name] ~= nil then
			if PreLoads[v.Name] ~= CollectedModules[v.Name] then
				warn("Error durring module collection:\nModule name already used: " .. v.Name)
			end
		end

		CollectedModules[v.Name] = mod.PreLoad(v)

		recursive_collect(v)
	end
end


function mod.CollectModules(Game)
	for _, dir in Config.ModuleCollectionFolders do
		recursive_collect(dir)
	end
end




local IsServer = game:GetService("RunService"):IsServer()

--[[
	To support gradually moving to this heirarchy, modules that need an __init call
	but are depended on by only pre-loaded modules, we'll initialize them anyway.

	These modules can be a problem if their parent scripts have no idea that the it might not be ready to do everything
]]
function mod.Begin(Game, Main)
	Game.LOADING_CONTEXT = LOAD_CONTEXTS.LOAD_INIT

	-- TODO: @NoCommit Game.Main junk
	try_init(Main, "Main")

	for i,v in PreLoads do
		if typeof(v) ~= "table" then continue end

		local did_init = Initialized[i]
		if did_init == false then
			try_init(v, i, " DANGLING!!!")
		end
	end

	if not IsServer then
		local GameStateLoaded = AsyncList.new(1)
		
		local CanContinue = Instance.new("BindableEvent")
		
		local ClientReadyEvent = game.ReplicatedStorage:WaitForChild("ClientReadyEvent")
		ClientReadyEvent.OnClientEvent:Connect(function(gamestate)
			mod:__load_gamestate(gamestate, GameStateLoaded)
			
			while GameStateLoaded:is_awaiting() do
				--print(GameStateLoaded.awaiting.Contents)
				task.wait()
			end
			
			CanContinue:Fire()
		end)
		
		local prior_context = set_context(LOAD_CONTEXTS.AWAITING_SERVER_DATA)
		
		ClientReadyEvent:FireServer()
		CanContinue.Event:Wait()
		
		reset_context(prior_context)
	end

	mod:__finalize(Game)
	
	mod:__run(Game)
	
	if IsServer then
		local ClientReadyEvent = Instance.new("RemoteEvent")
		ClientReadyEvent.Name = "ClientReadyEvent"
		ClientReadyEvent.OnServerEvent:Connect(function(player)
			while (not Game[player]) or (not Game[player].ServerLoaded) do
				task.wait()
			end
			
			local gamestate = mod:__get_gamestate(player)
			ClientReadyEvent:FireClient(player, gamestate)
		end)
		
		ClientReadyEvent.Parent = game.ReplicatedStorage
	end
	
	--We do this last so that UI and stuff can be set up too. Even game processes over large periods of time can
	-- potentially be tested
	if Config.TESTING ~= false then
		assert(Config.TESTING == true or Config.TESTING == "CLIENT" or Config.TESTING == "SERVER")
		mod:__tests(Game)
	end

	set_context(LOAD_CONTEXTS.FINISHED)
end

local APIUtils = require(game.ReplicatedFirst.Util.APIUtils)
APIUtils.EXPORT_LIST(mod)
	:ADD("LazyModules", mod)
	:ADD("LightLoad")
	:ADD("Load")
	:ADD("PreLoad")
	:ADD("CONTEXT")

function mod:__init(G)
	Game = G

	Game.LOADING_CONTEXT = -1
	--The one true require tree
	safe_require = require(script.Parent.SafeRequire)
	safe_require = safe_require.require

	Signals = require(script.Signals)
	Signals:__init(G, mod)
	mod.Signals = Signals

	Tests = require(script.Tests)
	Tests:__init(G, mod)
	mod.Tests = Tests

	if CONTEXT == "CLIENT" then
		UI = mod.PreLoad(script.UI)
	end

	self.Initialized = true
end

function mod:__get_gamestate(plr)
	local gamestate = {}
	
	for i,v in PreLoads do
		if typeof(v == "table") then
			local s, r
			s, r = pcall(function() return v.__get_gamestate end)
			if s and r then
				local state, name = get_gamestate_wrapper(v, plr)
				
				if not name then
					name = i
				end
				
				gamestate[name] = state
			end
		end
	end
	
	return gamestate
end

function mod:__load_gamestate(gamestate, GameStateLoadedList)
	for i,v in PreLoads do
		if typeof(v == "table") then
			local s, r
			s, r = pcall(function() return v.__load_gamestate end)
			if s and r then
				load_gamestate_wrapper(v, gamestate[i], GameStateLoadedList, i)
			end
		end
	end
end

function mod:__finalize(G)
	-- Signals must do its thing first since it implements the stage which comes before this one.
	-- It really serves no purpose until its "finalized"
	Signals.BuildSignals(G)

	for i,v in PreLoads do
		if typeof(v == "table") then
			--Roact managed to ruin everything
			local s, r = pcall(function() return v.__finalize end)
			if s and r then
				finalize_wrapper(v, i)
			end
		end
	end
end

function mod:__tests(G)
	print("\n\t\tTESTING\n")

	for i,v in PreLoads do
		if typeof(v == "table") then
			--Roact managed to ruin everything
			local s, r = pcall(function() return v.__tests end)
			if s and r then
				tests_wrapper(v, i)
			end
		end
	end
end

function mod:__run(G)
	local ui_tasks = {}
	
	for i,v in PreLoads do
		if typeof(v == "table") then
			--Roact managed to ruin everything
			local s, r
			if CONTEXT == "CLIENT" then
				s, r = pcall(function() return v.__ui end)
				if s and r then
					table.insert(ui_tasks, task.spawn(ui_wrapper, v, i))
				end
			end
		end
	end
	
	while true do
		local do_wait = false
		for _, thread in ui_tasks do
			if coroutine.status(thread) ~= "dead" then
				do_wait = true
				break
			end
		end
		
		if do_wait then
			task.wait()
		else
			break
		end
	end
	
	for i,v in PreLoads do
		if typeof(v == "table") then
			local s, r = pcall(function() return v.__run end)
			if s and r then
				run_wrapper(v, i)
			end
		end
	end
end

return mod
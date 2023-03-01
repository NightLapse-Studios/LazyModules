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
]]
local mod = {
	--TODO: This flag needs to be removed
	Initialized = false,
	Signals = false,

	-- This enum must be numerically sorted acording to the order the steps are executed
	CONTEXTS = {
		PRELOAD = 1,
		LOAD_INIT = 2,
		SIGNAL_BUILDING = 4,
		FINALIZE = 5,
		RUN = 6,
		TESTING = 7,

		FINISHED = 1000
	}
}

local TESTING = true
local LOAD_CONTEXTS = mod.CONTEXTS
local CONTEXT = if game:GetService("RunService"):IsServer()  then "SERVER" else "CLIENT"
local SOURCE_NAME = debug.info(function() return end, "s")

local config = require(game.ReplicatedFirst.ClientCore.BUILDCONFIG)

local depth = 0


local Globals
-- This module is required from __run in this module
-- Because it needs to go through the whole loading process in order to rely on Assets, etc
local UI
local Signals
local Tests
local unwrap_or_warn
local unwrap_or_error
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
	local prior = Globals.LOADING_CONTEXT

	-- Do some additional context considerations and error checking
	--prior, context = process_context(prior, context)

	-- If our new context is initializing, then the prior contexts must have been initializing too.
	if context == LOAD_CONTEXTS.LOAD_INIT then
		if not (prior >= LOAD_CONTEXTS.LOAD_INIT) then
			error("\n" .. CONTEXT .. " init: Module is attempting to load during pre-loading" ..
				"Hint: if LazyModules executes an `__init` function, then it must be caused by another module's `__init` function\nExcept for the first module in the init tree")
		end
	end

	Globals.LOADING_CONTEXT = context

	return prior
end

local function reset_context(prev: number)
	Globals.LOADING_CONTEXT = prev
end

local function format_load_err(name)
	local _script = game.ReplicatedFirst:FindFirstChild(name, true)

	if not _script then
		return "Search could not find suggested require path for module \"" .. name .. "\""
	end

	local ret = _script.Name
	while _script.Parent and _script.Parent ~= game do
		ret = _script.Parent.Name .. "." .. ret
		_script = _script.Parent
	end

	ret = "\n" .. CONTEXT .. " init: Module `" .. name .. "` isn't in the `Game` object\n" ..
	"\nSuggested fix:\nGlobals." .. name .. " = LazyModules.PreLoad(game." .. ret .. ")"

	return ret
end

local function format_lazymodules_traceback()
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

local Initialized: {[string]: boolean} = { }

local function init_wrapper(module, name)
	local prior_context = set_context(LOAD_CONTEXTS.LOAD_INIT)
	module:__init(Globals)
	reset_context(prior_context)
end

local function signals_wrapper(module, name)
	local prior_context = set_context(LOAD_CONTEXTS.SIGNAL_BUILDING)

	-- Configure the builder for this module
	local builder = Signals:Builder( name )

	-- Pass the builder to the module
	-- The module will use the builder to register its signals
	module:__build_signals(Globals, builder)
	reset_context(prior_context)
end

local function tests_wrapper(module, name)
	local prior_context = set_context(LOAD_CONTEXTS.TESTING)

	-- Configure the builder for this module
	local builder = Tests:Builder( name )

	module:__tests(Globals, builder)
	reset_context(prior_context)
end

local function finalize_wrapper(module, name)
	local prior_context = set_context(LOAD_CONTEXTS.FINALIZE)
	module:__finalize(Globals)
	reset_context(prior_context)
end

local function ui_wrapper(module, name)
	local prior_context = set_context(LOAD_CONTEXTS.RUN)

	local builder = UI:Builder( name )

	-- Note that UI will not exist on server contexts
	if config.LogUIInit then
		print(" -- > UI INIT: " .. name)
	end

	module:__ui(Globals, builder, UI.A, UI.D)
	reset_context(prior_context)
end

local function run_wrapper(module, name)
	local prior_context = set_context(LOAD_CONTEXTS.RUN)

	-- Note that UI will not exist on server contexts
	module:__run(Globals, UI)
	reset_context(prior_context)
end

local function try_init(module, name, astrisk)
	astrisk = astrisk or ""

	if Initialized[name] ~= true then
		Initialized[name] = true
		depth += 1

		if config.LogLoads then
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

local PreLoads: { [string]: script } = { }

--[[
	Some modules return using metatables that allows PreLoad to have side effects
	This avoids indexing
	A string is also required so that naming overrides are processed by the time __raw_load is called
]]
function mod.__raw_load(script: Instance, name: string): any
--[[ 	unwrap_or_warn(
		PreLoads[script.Name] == nil,
		"\n" .. INIT_CONTEXT .. " init: Double pre-load of `" .. script.Name .. "`",
		"\nRequired from:\n" .. debug.traceback(nil, 2)
	) ]]

	local prior_context = set_context(LOAD_CONTEXTS.PRELOAD)

	local module = safe_require(script)

	if config.LogUnfoundLoads then
		if not module then
			warn("\n" .. CONTEXT .. " init: Path to `" .. script.Name .. "` not found during PreLoad" ..
			"\nRequired from:\n" .. format_lazymodules_traceback())
		end
	end

	reset_context(prior_context)
	
	-- Guard against multiple inits on one module
	if Initialized[name] ~= nil then
		return module
	end

	Globals[name] = module
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

	local module = Globals[opt_name] or mod.__raw_load(script, opt_name)

	local s, r = pcall(function() return module.__no_preload end)
	if typeof(module) == "table" and r then
		try_init(module, opt_name, " **FORCED**")
	end

	-- Impl __no_preload
	-- Indicates that a module cannot be required without initialization
--[[ 	unwrap_or_error(
		if typeof(module) == "table" then module.__no_preload == nil else true,
		"\n" .. INIT_CONTEXT .. " init: Module `" .. opt_name .. "` cannot be pre-loaded",
		"Hint: Use `G.Load` during runtime instead"
	) ]]

	return module
end

function mod.Load(script: (string | Instance)): any?
	local module
	if typeof(script) == "string" then
		-- A script's name has been passed in
		module = Globals[script]

		if not module then
			warn(format_load_err(script))
			warn("\tRequired from:\n" .. format_lazymodules_traceback())
			return
		end
	elseif script then
		-- A script has been passed in
		module = mod.__raw_load(script, script.Name)

		if not module then
			warn(format_load_err(script))
			warn("\tRequired from:\n" .. format_lazymodules_traceback())
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
		--warn("\tRequired from:\n" .. format_lazymodules_traceback())
	end

	return module
end




local IsServer = game:GetService("RunService"):IsServer()

--[[
	To support gradually moving to this heirarchy, modules that need an __init call
	but are depended on by only pre-loaded modules, we'll initialize them anyway.

	These modules can be a problem if their parent scripts have no idea that the it might not be ready to do everything
]]
function mod.Begin(G)
	G.LOADING_CONTEXT = mod.CONTEXTS.LOAD_INIT

	try_init(G.Main, "Main")

	for i,v in PreLoads do
		if typeof(v) ~= "table" or not v.__init then continue end

		local did_init = Initialized[i]
		if did_init == false then
			try_init(v, i, " DANGLING!!!")
		end
	end

	-- TODO: a dependency system for the __finalize step
	if not IsServer then
		local ClientReadyEvent = game.ReplicatedStorage:WaitForChild("ClientReadyEvent")
		ClientReadyEvent:FireServer()

		while not (G.LoadedFlags.PlayerStats)
		do
			task.wait()
		end
	end

	mod:__finalize(G)

	mod:__run(G)

	--We do this last so that UI and stuff can be set up too. Even game processes over large periods of time can
	-- potentially be tested
	if config.TESTING ~= false then
		assert(config.TESTING == true or config.TESTING == "CLIENT" or config.TESTING == "SERVER")
		mod:__tests(G)
	end

	--TODO: Clearly something about initialization is still not realized... This is a scuffed post-finalize stage
	if IsServer then
		local ClientReadyEvent = Instance.new("RemoteEvent", game.ReplicatedStorage)
		ClientReadyEvent.Name = "ClientReadyEvent"
		ClientReadyEvent.OnServerEvent:Connect(G.Players.LoadClientData)
	end

	set_context(LOAD_CONTEXTS.FINISHED)
end



mod.API_Values = {
	LightLoad = mod.LightLoad,
	Load = mod.Load,
	PreLoad = mod.PreLoad,
	LazyModules = mod,
	CONTEXT = CONTEXT
}

function mod:__init(G)
	Globals = G

	Globals.LOADING_CONTEXT = -1
	--The one true require tree
	safe_require = require(script.Parent.SafeRequire)
	safe_require:__init(G)
	safe_require = safe_require.require

	Signals = require(script.Signals)
	Signals:__init(G, mod)
	mod.Signals = Signals

	Tests = require(script.Tests)
	Tests:__init(G, mod)
	mod.Tests = Tests

	local err = require(script.Parent.Error)
	unwrap_or_warn = err.unwrap_or_warn
	unwrap_or_error = err.unwrap_or_error

	if CONTEXT == "CLIENT" then
		UI = mod.PreLoad(script.UI)
	end
	self.Initialized = true
end

function mod:__finalize(G)
	-- Signals must be finalized first since it implements the stage which comes before this one.
	-- It really serves no purpose until its finalized
	finalize_wrapper(Signals, "Signals")

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
	print("\n\t\tTESTING\nn")

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
	for i,v in PreLoads do
		if typeof(v == "table") then
			--Roact managed to ruin everything
			local s, r
			if CONTEXT == "CLIENT" then
				s, r = pcall(function() return v.__ui end)
				if s and r then
					ui_wrapper(v, i)
				end
			end
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
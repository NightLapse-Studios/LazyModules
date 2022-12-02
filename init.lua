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

		FINISHED = 1000
	}
}

local LOAD_CONTEXTS = mod.CONTEXTS

local depth = 0

local INIT_CONTEXT = if game:GetService("RunService"):IsServer()  then "SERVER" else "CLIENT"

local Globals
local Signals
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
		unwrap_or_error(
			prior >= LOAD_CONTEXTS.LOAD_INIT,
			"\n" .. INIT_CONTEXT .. " init: Module is attempting to load during pre-loading",
			"Hint: if LazyModules executes an `__init` function, then it must be caused by another module's `__init` function\nExcept for the first module in the init tree"
	   )
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

	ret = "\n" .. INIT_CONTEXT .. " init: Module `" .. name .. "` isn't in the `Game` object\n" ..
	"\nSuggested fix:\nGlobals." .. name .. " = LazyModules.PreLoad(game." .. ret .. ")"

	return ret
end

local Initialized: {[string]: boolean} = { }

local function init_wrapper(module, name)
	if typeof(module) == "table" and module.__init then
		local prior_context = set_context(LOAD_CONTEXTS.LOAD_INIT)
		module:__init(Globals)
		reset_context(prior_context)
	end
end

local function signals_wrapper(module, name)
	if typeof(module) == "table" and module.__build_signals then
		local prior_context = set_context(LOAD_CONTEXTS.SIGNAL_BUILDING)

		-- Configure the builder for this module
		local builder = Signals:Builder( name )

		-- Pass the builder to the module
		-- The module will use the builder to register its signals
		module:__build_signals(Globals, builder)
		reset_context(prior_context)
	end
end

local function finalize_wrapper(module, name)
	if typeof(module) == "table" and module.__finalize then
		local prior_context = set_context(LOAD_CONTEXTS.FINALIZE)
		module:__finalize(Globals)
		reset_context(prior_context)
	end
end

local function run_wrapper(module, name)
	if typeof(module) == "table" and module.__run then
		local prior_context = set_context(LOAD_CONTEXTS.RUN)
		module:__run(Globals)
		reset_context(prior_context)
	end
end

local function try_init(module, name, astrisk)
	astrisk = astrisk or ""
	if Initialized[name] == false then
		Initialized[name] = true
		depth += 1

		print(indent() .. name .. astrisk)

		signals_wrapper(module, name)
		init_wrapper(module, name)

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
	module = unwrap_or_warn(
		module,
		"\n" .. INIT_CONTEXT .. " init: Path to `" .. script.Name .. "` not found during PreLoad",
		"\nRequired from:\n" .. debug.traceback(nil, 2)
	)

	reset_context(prior_context)

	Globals[name] = module
	PreLoads[name] = module
	Initialized[name] = false

	return module
end

--Future API expansion should usually go here
function mod.PreLoad(script: Instance, opt_name: string?): any
	opt_name = opt_name or script.Name

	local module = Globals[opt_name] or mod.__raw_load(script, opt_name)

	if typeof(module) == "table" and module.__no_preload then
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
		module = unwrap_or_warn(
			module,
			format_load_err(script),
			"Required from:\n" .. debug.traceback(nil, 1)
		)

		if not module then
			return
		end
	elseif script then
		-- A script has been passed in
		module = mod.__raw_load(script, script.Name)

		module = unwrap_or_warn(
			module,
			format_load_err(script.Name),
			"Required from:\n" .. debug.traceback(nil, 1)
		)

		try_init(module, script.Name, " **FROM INSTANCE**")

		return module
	end

	try_init(module, script)

	return module
end

--TODO: This is an incomplete interface
-- Feels that the needs of the codebase need to develop around it more before we make more design decisions here
local IsServer = game:GetService("RunService"):IsServer()
local connect_types = {
	--TODO: Other events
	[typeof(Instance.new("RemoteEvent"))] = if IsServer then "OnServerEvent" else "OnClientEvent",
	[typeof(Instance.new("BindableEvent"))] = "Event"
}

function mod.Hook(script: string, event: string, func): RBXScriptConnection?
	local event = mod.GetEvent(script, event)

	if event then
		return event[connect_types[typeof(event)]]:Connect(func)
	end
end

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
			warn("Dangling module init: " .. i)
			init_wrapper(v, i)
		end
	end

	-- TODO: a dependency system for the __finalize step
	if not IsServer then
		local ClientReadyEvent = game.ReplicatedStorage:WaitForChild("ClientReadyEvent")
		ClientReadyEvent:FireServer()

		while not (G.LoadedFlags.PlayerStats and G.LoadedFlags.Settings)
		do
			task.wait()
		end
	end

	mod:__finalize(G)

	mod:__run(G)

	--TODO: Clearly something about initialization is still not realized... This is a scuffed post-finalize stage
	if IsServer then
		local ClientReadyEvent = Instance.new("RemoteEvent", game.ReplicatedStorage)
		ClientReadyEvent.Name = "ClientReadyEvent"
		ClientReadyEvent.OnServerEvent:Connect(G.Players.LoadClientData)
	end

	set_context(LOAD_CONTEXTS.FINISHED)
end

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

	local err = require(script.Parent.Error)
	unwrap_or_warn = err.unwrap_or_warn
	unwrap_or_error = err.unwrap_or_error

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

function mod:__run(G)
	for i,v in PreLoads do
		if typeof(v == "table") then
			--Roact managed to ruin everything
			local s, r = pcall(function() return v.__run end)
			if s and r then
				run_wrapper(v, i)
			end
		end
	end
end

return mod
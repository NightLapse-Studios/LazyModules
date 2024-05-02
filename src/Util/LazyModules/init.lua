--!strict
--!native

local safe_require = require(game.ReplicatedFirst.Util.SafeRequire).require
local Config = require(game.ReplicatedFirst.Util.Config)
local AsyncList = require(game.ReplicatedFirst.Util.AsyncList)

local Enums = require(game.ReplicatedFirst.Util.Enums)

local mod = { }

local LOAD_CONTEXTS = Enums.LOAD_CONTEXTS
local CONTEXT = if game:GetService("RunService"):IsServer()  then ("SERVER" :: ServerContext) else ("CLIENT" :: ClientContext)
local SOURCE_NAME = debug.info(function() return end, "s")



local Signals = require(script.Signals)
local Tests = require(script.Tests)
local Pumpkin = require(game.ReplicatedFirst.Util.Pumpkin)



local Initialized = { }

local function set_context(G, context: number)
	local prior = G.LOADING_CONTEXT

	if (context < prior) then
		error(`\n{CONTEXT} \n LM Init: returning to older startup context than current.\nOld context: {prior}\nNew context: {context}\n\nThis is likely LM misuse or an LM bug`)
	end

	G.LOADING_CONTEXT = context

	return prior
end

local function reset_context(G, prev: number)
	G.LOADING_CONTEXT = prev
end

local function can_init(mod_name)
	if Initialized[mod_name] then
		warn("Module " .. mod_name .. " already initialized (??)")
		return false
	end

	return true
end


-- Convenience function
local depth = 0
local function indent()
	local _indent = ""
	for i = 1, depth, 1 do
		_indent = _indent .. " | "
	end

	return _indent
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

local LMGame = { }
LMGame.__index = LMGame

function mod.newGame()
	local newGame = {
		-- List of modules by name and their return value
		_CollectedModules = { },
		-- Reverse lookup of modules by their value to their name
		_ModuleNames = { },
		_Initialized = { },
		CONTEXT = CONTEXT,
		LOADING_CONTEXT = -1
	}

	setmetatable(newGame, LMGame)

	return (newGame :: any) :: Game
end

local function add_module<O, S, T>(obj: O, name: S, module: T): ItemWith<O, S, T>
	obj[name] = module
	return obj :: ItemWith<O, S, T>
end

function LMGame:_require<M>(script: ModuleScript, name: string)
	local prior_context = set_context(self, LOAD_CONTEXTS.PRE_LOAD)

	local module_value = safe_require(script)

	if typeof(module_value) ~= "table" then
		return
	end

	reset_context(self, prior_context)

	-- Guard against multiple inits on one module
	if self._Initialized[name] ~= nil then
		return module_value
	end

	self._CollectedModules = add_module(self._CollectedModules, name, module_value)
	self._ModuleNames[module_value] = name
	self._Initialized[name] = false

	return module_value
end

local function preload(self, script: ModuleScript, opt_name: string?)
	-- This check was discovered because referencing string.Name doesn't error, but returns nil for some reason
	-- It is common to mistakenly pass a string into thie function
	if typeof(script.Name) ~= "string" then
		error("Value passed into LazyModules.PreLoad must be a script")
	end

	opt_name = (opt_name or script.Name) :: string

	local module = self._CollectedModules[opt_name]
	if not module then
		if Config.LogPreLoads then
			print(opt_name)
		end

		module = self:_require(script, opt_name)
	end

	return module
end

local CollectionBlacklist: {Instance} = Config.ModuleCollectionBlacklist
local ContextCollectionBlacklist: {Instance} = if CONTEXT == "SERVER" then Config.ModuleCollectionBlacklist.Server else Config.ModuleCollectionBlacklist.Client

function LMGame:_recursive_collect(instance: Folder | ModuleScript)
	for _,v: Instance in instance:GetChildren() do
		if table.find(CollectionBlacklist, v) or table.find(ContextCollectionBlacklist, v) then
			continue
		end

		if typeof(v) ~= "Instance" then
			continue
		end

		if v:IsA("Folder") then
			self:_recursive_collect(v)
			continue
		end

		if not v:IsA("ModuleScript") then
			continue
		end

		-- This is kind of flimsy since PreLoad can do this on its own
		-- TODO: A Call to PreLoad before we collect can cause false positives
		if self._CollectedModules[v.Name] ~= nil then
			warn("Error durring module collection:\nModule name already used: " .. v.Name)
		end

		preload(self, v)

		self:_recursive_collect(v)
	end
end


function LMGame:CollectModules()
	for _, dir: Folder in Config.ModuleCollectionFolders do
		self:_recursive_collect(dir)
	end

	return self
end

function LMGame:__init(G)

end


export type ServerContext = "SERVER"
export type ClientContext = "CLIENT"

type ItemWith<O, S, T> = O & { [S]: T }

-- export type InitializingGame = typeof(mod.newGame())
export type Game = typeof(mod.newGame():CollectModules())

--[[ type API = {
	newGame: () -> Game
} ]]


local function try_init(G, module, name)
	if Config.LogLoads then
		print("LM init: " .. name)
	end

	local s, r = pcall(function() return module.__init end)
	if s and r then
		if typeof(module.__init) ~= "function" then
			return
		end
	
		local prior_context = set_context(G, LOAD_CONTEXTS.LOAD_INIT)
		module:__init(G)
		reset_context(G, prior_context)
	end
end

local function try_signals(G, module, name)
	if Config.LogLoads then
		print("LM signals: " .. name)
	end

	local s, r = pcall(function() return module.__build_signals end)
	if s and r then
		if typeof(module.__build_signals) ~= "function" then
			return
		end

		Signals.SetModule(name)
	
		local prior_context = set_context(G, LOAD_CONTEXTS.SIGNAL_BUILDING)
		module:__build_signals(G, Signals)
		reset_context(G, prior_context)
	end
end

local function try_ui(G, module, name)
	if Config.LogLoads then
		print("LM ui: " .. name)
	end

	local s, r = pcall(function() return module.__ui end)
	if s and r then
		if typeof(module.__ui) ~= "function" then
			return
		end
	
		local prior_context = set_context(G, LOAD_CONTEXTS.AWAITING_SERVER_DATA)
		module:__ui(G, Pumpkin, Pumpkin.P, Pumpkin.Roact)
		reset_context(G, prior_context)
	end
end

local function try_run(G, module, name)
	if Config.LogLoads then
		print("LM run: " .. name)
	end

	local s, r = pcall(function() return module.__run end)
	if s and r then
		if typeof(module.__run) ~= "function" then
			return
		end
	
		local prior_context = set_context(G, LOAD_CONTEXTS.LOAD_INIT)
		module:__run(G)
		reset_context(G, prior_context)
	end
end

local function try_tests(G, module, name)
	if Config.LogLoads then
		print("LM TESTING: " .. name)
	end

	local s, r = pcall(function() return module.__tests end)
	if s and r then
		if typeof(module.__tests) ~= "function" then
			return
		end
		
		local tester = Tests.Tester(name)
	
		local prior_context = set_context(G, LOAD_CONTEXTS.TESTING)
		module:__tests(G, tester)
		tester:Finished()
		reset_context(G, prior_context)
	end
end

function LMGame:Begin(Main, name: string)
	for mod_name, module_val in self._CollectedModules do
		if not can_init(mod_name) then
			warn("Module " .. mod_name .. " already initialized (this is probably a huge bug)")
			continue
		end

		try_init(self, module_val, mod_name)
	end

	for mod_name, module_val in self._CollectedModules do
		if not can_init(mod_name) then continue end
		try_signals(self, module_val, mod_name)
	end

	Signals.BuildSignals(self)

	for mod_name, module_val in self._CollectedModules do
		if not can_init(mod_name) then continue end
		try_ui(self, module_val, mod_name)
	end

	for mod_name, module_val in self._CollectedModules do
		if not can_init(mod_name) then continue end
		try_run(self, module_val, mod_name)

		Initialized[mod_name] = true
	end

	for mod_name, module_val in self._CollectedModules do
		try_tests(self, module_val, mod_name)
	end
end

function LMGame:Get(name: string, opt_specific_context: ("CLIENT" | "SERVER")?)
	if self.LOADING_CONTEXT < LOAD_CONTEXTS.LOAD_INIT then
		error("Game:Get before init stage is undefined and non-determinisitic")
	end

	local mod = self._CollectedModules[name]

	if not mod then
		if opt_specific_context and self.CONTEXT == opt_specific_context then
			warn(`Attempt to get unfound module {name}. Provide a context to silence if this is context related`)
		end
	end

	return mod
end

function LMGame:Load(module: ModuleScript)
	if self.LOADING_CONTEXT < LOAD_CONTEXTS.LOAD_INIT then
		error("Game:Get before init stage is undefined and non-determinisitic")
	end

	assert(module:IsA("ModuleScript"))

	local name = module.Name
	local mod_which_shouldnt_exist = self._CollectedModules[name]

	if mod_which_shouldnt_exist then
		error(`Won't load already-collected module {name}!\nGame:Load is intended for uncollected modules.\nTypically you will add a folder of modules to Config.CollectionBlacklist and load them manually`)
	end

	local module_val = safe_require(module)
	try_init(self, module_val, name)
	-- Signals may not resolve until the tick after which this is called
	-- Potentially more but generally contrived situtations are what causes waits of additional ticks
	try_signals(self, module_val, name)
	try_ui(self, module_val, name)
	try_run(self, module_val, name)
	try_tests(self, module_val, name)

	return module_val
end


return mod
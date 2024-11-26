--!strict
--!native

local safe_require = require(game.ReplicatedFirst.Lib.SafeRequire).require
local Config = require(game.ReplicatedFirst.Config)
local Enums = require(game.ReplicatedFirst.Lib.Enums)

local LMTypes = require(game.ReplicatedFirst.Lib.LMTypes)

export type LMGame = LMTypes.LMGame
export type LazyModule = LMTypes.LazyModule
export type LMCallback = (LMGame, (LMGame, ...any) -> ()) -> ()
export type ModuleStage = {
	Type: "Module",
	Priority: number,
	ShouldRunStage: boolean | (() -> boolean),
	Callback: (LMGame, (LMGame, ...any) -> (), module_name: string) -> (),
	FinishedCallback: boolean | (() -> ()),
	StageName: string,
}
export type GlobalStage = {
	Type: "Global",
	Priority: number,
	ShouldRunStage: boolean | (() -> boolean),
	Callback: (LMGame) -> (),
	FinishedCallback: boolean | (() -> ()),
	StageName: string
}

local mod = { }

local Stages: { ModuleStage | GlobalStage } = { }

local LOAD_CONTEXTS = Enums.LoadingContexts
local CONTEXT = if game:GetService("RunService"):IsServer()  then "SERVER" else "CLIENT"
_G.LMSOURCENAME = debug.info(function() return end, "s")

local CollectionBlacklist: {Instance} = Config.ModuleCollectionBlacklist
local ContextCollectionBlacklist: {Instance} = if CONTEXT == "SERVER" then Config.ModuleCollectionBlacklist.Server else Config.ModuleCollectionBlacklist.Client



function mod.RegisterModuleStage(name: string, priority: number, callback, finished_callback, should_run_callback)
	finished_callback = finished_callback or false
	should_run_callback = should_run_callback or false
	table.insert(Stages, {
		Type = "Module",
		Priority = priority,
		ShouldRunStage = should_run_callback,
		Callback = callback,
		FinishedCallback = finished_callback,
		StageName = name
	})
end

function mod.RegisterGlobalStage(name: string, priority: number, callback, finished_callback, should_run_callback)
	finished_callback = finished_callback or false
	should_run_callback = should_run_callback or false
	table.insert(Stages, {
		Type = "Global",
		Priority = priority,
		ShouldRunStage = should_run_callback,
		Callback = callback,
		FinishedCallback = finished_callback,
		StageName = name
	})
end



local Initialized = { }

local function set_context(G: LMGame, context: Enums.LoadingContext)
	local prior = G.LoadingContext

	if (context.Value < prior.Value) then
		error(`\n{CONTEXT} \n LM Init: returning to older startup context than current.\nOld context: {prior}\nNew context: {context}\n\nThis is likely LM misuse or an LM bug`)
	end

	G.LoadingContext = context

	return prior
end

local function reset_context(G: LMGame, prev: Enums.LoadingContext)
	G.LoadingContext = prev
end

local function can_init(mod_name: string)
	if Initialized[mod_name] then
		warn("Module " .. mod_name .. " already initialized (??)")
		return false
	end

	return true
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
		LoadingContext = Enums.LoadingContexts.UNSET,
		RaycastResult = false,
		RaycastResultNP = false,
		LoadedPlayers = { }
	}

	setmetatable(newGame, LMGame)

	return (newGame :: any) :: LMGame
end

local function add_module<O, S, T>(obj: O, name: S, module: T)
	obj[name] = module
	return obj
end

local function _require<M>(self: LMGame, script: ModuleScript, name: string)
	local prior_context = set_context(self, LOAD_CONTEXTS.REQUIRE)

	local module_value = safe_require(script)

	reset_context(self, prior_context)

	if typeof(module_value) ~= "table" then
		return
	end

	-- Guard against multiple inits on one module
	if self._Initialized[name] ~= nil then
		return module_value
	end

	self._CollectedModules = add_module(self._CollectedModules, name, module_value) :: (typeof(self._CollectedModules) & LMTypes.CollectModule<typeof(name), typeof(module_value)>)
	self._ModuleNames[module_value] = name
	self._Initialized[name] = false

	return module_value
end

local function collect(self: LMGame, module: ModuleScript, opt_name: string?)
	-- This check was discovered because referencing string.Name doesn't error, but returns nil for some reason
	-- It is common to mistakenly pass a string into thie function
	if typeof(module.Name) ~= "string" then
		error("Value passed into LazyModules.PreLoad must be a script")
	end

	if self._CollectedModules[module.Name] ~= nil then
		warn("Error durring module collection:\nModule name already used: " .. module.Name)
	end

	local opt_name = (opt_name or module.Name) :: string

	local existing_module = self._CollectedModules[opt_name]
	if not existing_module then
		if Config.LogLMRequires then
			print("LM Require", opt_name)
		end

		existing_module = _require(self, module, opt_name)
	end

	return existing_module
end

local function _recursive_collect(self: LMGame, instance: Folder | ModuleScript)
	for _,v: Instance in instance:GetChildren() do
		if table.find(CollectionBlacklist, v) or table.find(ContextCollectionBlacklist, v) then
			continue
		end

		if typeof(v) ~= "Instance" then
			continue
		end

		if v:IsA("Folder") then
			_recursive_collect(self, v)
			continue
		end

		if not v:IsA("ModuleScript") then
			continue
		end

		collect(self, v)

		_recursive_collect(self, v)
	end
end

function LMGame.CollectModules(self: LMGame)
	set_context(self, LOAD_CONTEXTS.COLLECTION)

	for _, dir: Folder in Config.ModuleCollectionFolders do
		_recursive_collect(self, dir)
	end

	set_context(self, LOAD_CONTEXTS.COLLECTED)

	return self
end



local function try_stage(self: LMGame, module: LazyModule, module_name: string, stage: ModuleStage)
	local stage_name = stage.StageName
	if Config.LogLoads then
		print("LM " .. stage.StageName .. ": " .. stage_name)
	end

	local s, r = pcall(function() return module[stage_name] end)
	if s and r then
		if typeof(r) == "function" then
			stage.Callback(self, r, module_name)
		end
	end
end



function LMGame.Get(self: LMGame, name: string, opt_specific_context: ("CLIENT" | "SERVER")?)
	if self.LoadingContext.Value < LOAD_CONTEXTS.COLLECTED.Value then
		error("Game:Get before collection stage makes no sense")
	end

	assert(typeof(name) == "string")

	local mod = self._CollectedModules[name]

	if not mod then
		if opt_specific_context and self.CONTEXT == opt_specific_context then
			warn(`Attempt to get unfound module {name}. Provide a context to silence if this is context related`)
		end
	end

	return mod
end

function LMGame.Load(self: LMGame, module: ModuleScript)
--[[ 	if self.LoadingContext < LOAD_CONTEXTS.INIT then
		error("Game:Load is not intended for use before init stage. Could work but could be dangerous, here be dragons..")
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

	return module_val ]]
end

function LMGame.Begin(self: LMGame)
	set_context(self, LOAD_CONTEXTS.RUNNING_STAGES)

	for i,v in script.Parent.Stages:GetChildren() do
		local stage_mode = safe_require(v)
		stage_mode.GiveLM(mod)
	end

	table.sort(Stages, function(a, b) return a.Priority < b.Priority end)

	for i = 1, #Stages, 1 do
		local stage = Stages[i]

		local should_run = true
		if stage.ShouldRunStage then
			should_run = stage.ShouldRunStage()
		end

		if not should_run then
			continue
		end

		if stage.Type == "Module" then
			for i,v in self._CollectedModules do
				try_stage(self, v, i, stage)
			end
		elseif stage.Type == "Global" then
			stage.Callback(self)
		else
			error("Unknown LM stage type: " .. stage.Type)
		end

		if stage.FinishedCallback then
			stage.FinishedCallback()
		end
	end

	set_context(self, LOAD_CONTEXTS.FINISHED)
	-- Set context 
	--[[
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

	if CONTEXT == "CLIENT" then
		wait_for_server_game_state(self)
	end

	for mod_name, module_val in self._CollectedModules do
		if not can_init(mod_name) then continue end
		try_ui(self, module_val, mod_name)
	end

	for mod_name, module_val in self._CollectedModules do
		if not can_init(mod_name) then continue end
		try_run(self, module_val, mod_name)

		Initialized[mod_name] = true
	end

	if CONTEXT == "SERVER" then
		setup_data_collectors(self)
	end
	
	if Config.TESTING then
		for mod_name, module_val in self._CollectedModules do
			try_tests(self, module_val, mod_name)
		end
	end ]]
end

return mod
--!strict
--!native

local safe_require = require(game.ReplicatedFirst.Lib.SafeRequire).require
local Config = require(game.ReplicatedFirst.Config)
local AsyncList = require(game.ReplicatedFirst.Lib.AsyncList)
local Enums = require(game.ReplicatedFirst.Lib.Enums)

local LMTypes = require(game.ReplicatedFirst.Lib.LMTypes)

-- local Pumpkin = require(game.ReplicatedFirst.Lib.Pumpkin)

export type LMGame = LMTypes.LMGame
export type LazyModule = LMTypes.LazyModule
export type LMCallback = (LMGame, (LMGame, ...any) -> ()) -> ()
export type ModuleStage = {
	Priority: number,
	Callback: (LMGame, (LMGame, ...any) -> (), module_name: string) -> (),
	FinishedCallback: false | ((LMGame) -> ()),
	StageName: string
}
export type GlobalStage = {
	Priority: number,
	Callback: (LMGame) -> (),
	StageName: string
}

local mod = { }

local Stages: { ModuleStage } = { }
local StageModules: { ModuleScript } = { }

local LOAD_CONTEXTS = Enums.LOAD_CONTEXTS
local CONTEXT = if game:GetService("RunService"):IsServer()  then "SERVER" else "CLIENT"
local SOURCE_NAME = debug.info(function() return end, "s")

local CollectionBlacklist: {Instance} = Config.ModuleCollectionBlacklist
local ContextCollectionBlacklist: {Instance} = if CONTEXT == "SERVER" then Config.ModuleCollectionBlacklist.Server else Config.ModuleCollectionBlacklist.Client



function mod.RegisterModuleStage(name: string, priority: number, callback, finished_callback)
	finished_callback = finished_callback or false
	table.insert(Stages, {
		Priority = priority,
		Callback = callback,
		FinishedCallback = finished_callback,
		StageName = name
	})
end

function mod.RegisterGlobalStage(name: string, priority: number, callback)
	table.insert(Stages, {
		Priority = priority,
		Callback = callback,
		StageName = name
	})
end



local Initialized = { }

local function set_context(G: LMGame, context: number)
	local prior = G.LOADING_CONTEXT

	if (context < prior) then
		error(`\n{CONTEXT} \n LM Init: returning to older startup context than current.\nOld context: {prior}\nNew context: {context}\n\nThis is likely LM misuse or an LM bug`)
	end

	G.LOADING_CONTEXT = context

	return prior
end

local function reset_context(G: LMGame, prev: number)
	G.LOADING_CONTEXT = prev
end

local function can_init(mod_name: string)
	if Initialized[mod_name] then
		warn("Module " .. mod_name .. " already initialized (??)")
		return false
	end

	return true
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



local function try_init(self: LMGame, module: LazyModule, name: string)
	if Config.LogLoads then
		print("LM init: " .. name)
	end
	
	local s, r = pcall(function() return module.__init end)
	if s and r then
		if typeof(module.__init) == "function" then
			local prior_context = set_context(self, LOAD_CONTEXTS.INIT)
			module.__init(self)
			reset_context(self, prior_context)
		end
	end
end

local function try_signals(self: LMGame, module: LazyModule, name: string)
	if Config.LogLoads then
		print("LM signals: " .. name)
	end

	local s, r = pcall(function() return module.__build_signals end)
	if s and r then
		if typeof(module.__build_signals) == "function" then
			Signals.SignalAPI:SetModule(name)
		
			local prior_context = set_context(self, LOAD_CONTEXTS.SIGNALS)
			module.__build_signals(self, Signals.SignalAPI)
			reset_context(self, prior_context)
		end
	end
end

local function try_ui(self: LMGame, module: LazyModule, name: string)
	if Config.LogLoads then
		print("LM ui: " .. name)
	end

	local s, r = pcall(function() return module.__ui end)
	if s and r then
		if typeof(module.__ui) == "function" then
			local prior_context = set_context(self, LOAD_CONTEXTS.UI)
			module.__ui(self, Pumpkin, Pumpkin.P, Pumpkin.Roact)
			reset_context(self, prior_context)
		end
	end
end

local function try_run(self: LMGame, module: LazyModule, name: string)
	if Config.LogLoads then
		print("LM run: " .. name)
	end

	local s, r = pcall(function() return module.__run end)
	if s and r then
		if typeof(module.__run) == "function" then
			local prior_context = set_context(self, LOAD_CONTEXTS.RUN)
			module.__run(self)
			reset_context(self, prior_context)
		end
	end
end

local function try_tests(self: LMGame, module: LazyModule, name: string)
	if Config.LogLoads then
		print("LM TESTING: " .. name)
	end

	local s, r = pcall(function() return module.__tests end)
	if s and r then
		if typeof(module.__tests) == "function" then		
			task.spawn(function()
				local tester = Tests.Tester(name)
				module.__tests(self, tester)
				Tests.Finished(tester)
			end)
		end
	end
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

local function load_gamestate_wrapper(module, module_name, data, loaded_list)
	local loaded_func = function()
		loaded_list:provide(true, module_name)
	end
	local after_func = function(name, callback)
		loaded_list:get(name, callback)
	end

	if not data then
		loaded_func()
	else
		-- @param1, the state returned by __get_gamestate
		-- @param2, a function that you MUST call when you have finished loading, see Gamemodes.lua for a good example.
		-- @param3, a function that you can pass another module name into to ensure its state loades before your callback is called.
		module.__load_gamestate(data, loaded_func, after_func)
	end
end

local function wait_for_server_game_state(self: LMGame)
	local modules_loaded_list = AsyncList.new(1)
	local CanContinue = Instance.new("BindableEvent")

	local ClientReadyEvent = game.ReplicatedStorage:WaitForChild("ClientReadyEvent") :: RemoteEvent
	ClientReadyEvent.OnClientEvent:Connect(function(game_state)
		-- Wait for the server to send us our datastore value, at which point we get inserted into the Game object
		while not self[game.Players.LocalPlayer] do
			task.wait()
		end

		for module_name, data in game_state do
			local module_value = self._CollectedModules[module_name]
			load_gamestate_wrapper(module_value, module_name, data, modules_loaded_list)
		end

		while modules_loaded_list:is_awaiting() do
			print(modules_loaded_list.awaiting.Contents)
			task.wait()
		end

		CanContinue:Fire()
	end)

	ClientReadyEvent:FireServer()
	CanContinue.Event:Wait()
end

local function try_get_game_state(module_value, plr)
	local s, r = pcall(function() return module_value.__get_gamestate end)
	if s and r then
		return module_value:__get_gamestate(plr)
	end
end

local function setup_data_collectors(self: LMGame)
	local ClientReadyEvent = Instance.new("RemoteEvent")
	ClientReadyEvent.Name = "ClientReadyEvent"
	ClientReadyEvent.Parent = game.ReplicatedStorage

	-- This connection exists for the lifetime of the game
	ClientReadyEvent.OnServerEvent:Connect(function(plr)
		while (not self[plr]) or not (self[plr].ServerLoaded) do
			task.wait()
		end

		local game_state = { }
		
		for module_name, module_value in self._CollectedModules do
			game_state[module_name] = try_get_game_state(module_value, plr)
		end

		ClientReadyEvent:FireClient(plr, game_state)
	end)
end

function LMGame.Get(self: LMGame, name: string, opt_specific_context: ("CLIENT" | "SERVER")?)
	if self.LOADING_CONTEXT < LOAD_CONTEXTS.COLLECTED then
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
	if self.LOADING_CONTEXT < LOAD_CONTEXTS.INIT then
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

	return module_val
end

function LMGame.Begin(self: LMGame)
	for i,v in script.Parent.Stages:GetChildren() do
		local stage_mode = require(v)
		stage_mode.GiveLM(mod)
	end

	table.sort(Stages, function(a, b) return a.Priority < b.Priority end)

	for i = 1, #Stages, 1 do
		local stage = Stages[i]
		-- set_context(self, stage.Priority)

		for i,v in self._CollectedModules do
			try_stage(self, v, i, stage)
		end

		if stage.FinishedCallback then
			stage.FinishedCallback()
		end
	end
	-- Set context 
--[[ 	set_context(self, LOAD_CONTEXTS.BEGIN_INIT)
	for mod_name, module_val in self._CollectedModules do
		if not can_init(mod_name) then
			warn("Module " .. mod_name .. " already initialized (this is probably a huge bug)")
			continue
		end

		try_init(self, module_val, mod_name)
	end

	set_context(self, LOAD_CONTEXTS.BEGIN_SIGNALS)
	for mod_name, module_val in self._CollectedModules do
		if not can_init(mod_name) then continue end
		try_signals(self, module_val, mod_name)
	end

	Signals.BuildSignals(self)

	if CONTEXT == "CLIENT" then
		wait_for_server_game_state(self)
	end

	set_context(self, LOAD_CONTEXTS.BEGIN_UI)
	for mod_name, module_val in self._CollectedModules do
		if not can_init(mod_name) then continue end
		try_ui(self, module_val, mod_name)
	end

	set_context(self, LOAD_CONTEXTS.BEGIN_RUN)
	for mod_name, module_val in self._CollectedModules do
		if not can_init(mod_name) then continue end
		try_run(self, module_val, mod_name)

		Initialized[mod_name] = true
	end

	if CONTEXT == "SERVER" then
		setup_data_collectors(self)
	end
	
	set_context(self, LOAD_CONTEXTS.FINISHED)
	if Config.TESTING then
		for mod_name, module_val in self._CollectedModules do
			try_tests(self, module_val, mod_name)
		end
	end ]]
end

return mod
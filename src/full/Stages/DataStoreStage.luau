local IsServer = game:GetService("RunService"):IsServer()

local STAGE_NAME = if IsServer then "__get_gamestate" else "__load_gamestate"
local STAGE_PRIORITY = if IsServer then 5000 else 2000

local AsyncList = require(game.ReplicatedFirst.Lib.AsyncList)

local mod = { }

if IsServer then
	local function try_get_game_state(module_value, plr)
		local s, r = pcall(function() return module_value.__get_gamestate end)
		if s and r then
			return module_value:__get_gamestate(plr)
		end
	end

	local function setup_data_collectors(Game)
		local ClientReadyEvent = Instance.new("RemoteEvent")
		ClientReadyEvent.Name = "ClientReadyEvent"
		ClientReadyEvent.Parent = game.ReplicatedStorage

		-- This connection exists for the lifetime of the game
		ClientReadyEvent.OnServerEvent:Connect(function(plr)
			while (not Game[plr]) or not (Game[plr].ServerLoaded) do
				task.wait()
			end

			local game_state = { }
			
			for module_name, module_value in Game._CollectedModules do
				game_state[module_name] = try_get_game_state(module_value, plr)
			end

			ClientReadyEvent:FireClient(plr, game_state)
		end)
	end

	function mod.GiveLM(lm)
		lm.RegisterGlobalStage(STAGE_NAME, STAGE_PRIORITY, setup_data_collectors)
	end
else
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

	local function wait_for_server_game_state(Game)
		local modules_loaded_list = AsyncList.new(1)
		local CanContinue = Instance.new("BindableEvent")
	
		local ClientReadyEvent = game.ReplicatedStorage:WaitForChild("ClientReadyEvent") :: RemoteEvent
		ClientReadyEvent.OnClientEvent:Connect(function(game_state)
			-- Wait for the server to send us our datastore value, at which point we get inserted into the Game object
			while not Game[game.Players.LocalPlayer] do
				task.wait()
			end
	
			for module_name, data in game_state do
				local module_value = Game._CollectedModules[module_name]
				load_gamestate_wrapper(module_value, module_name, data, modules_loaded_list)
			end
	
			while modules_loaded_list:is_awaiting() do
				-- print(modules_loaded_list.awaiting.Contents)
				task.wait()
			end
	
			CanContinue:Fire()
		end)

		ClientReadyEvent:FireServer()
		CanContinue.Event:Wait()
	end

	function mod.GiveLM(lm)
		lm.RegisterGlobalStage(STAGE_NAME, STAGE_PRIORITY, wait_for_server_game_state)
	end
end

return mod
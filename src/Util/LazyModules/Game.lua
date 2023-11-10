local Game = { }
Game.LOADING_CONTEXT = -100

-- Expose StdLib and etc to any LM-managed modules
_G.Game = Game

local APIUtils = require(game.ReplicatedFirst.Util.APIUtils)

local LazyModules = require(game.ReplicatedFirst.Util.LazyModules)
APIUtils.LOAD_EXPORTS(LazyModules, Game)
LazyModules:__init(Game)

local StdLib = LazyModules.PreLoad(game.ReplicatedFirst.Util.StdLib)
StdLib.LoadExports(Game)

LazyModules.CollectModules(Game)

-- Register modules which have player-based data that will be fed into datastores as well as transmitted to clients
-- Data synced this way will be available by _G.Game[plr][<module_name>]
do
	local Players = Game.PreLoad(game.ReplicatedFirst.Modules.Players)
	Players.RegisterPlayerDataModule(game.ReplicatedFirst.Modules.PlayerStats)
end

if Game.CONTEXT == "CLIENT" then
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	
	local character = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
	character:WaitForChild("Humanoid")
	local fired = false
	local b = Instance.new("BindableEvent")
	Game.PreLoad(game.ReplicatedFirst.Modules.Instances).OnAllLoaded(character, function()
		fired = true
		b:Fire()
	end)

	if not fired then
		b.Event:Wait()
	end
end

function Game.Begin(Main)
	LazyModules.Begin(Game, Main)
end

return Game
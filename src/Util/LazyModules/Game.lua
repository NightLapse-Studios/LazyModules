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

if Game.CONTEXT == "CLIENT" then
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	
	-- Add any additional desired loading delays such as Instances.OnAllLoaded for the clients character
else
	-- Register modules which have player-based data that will be fed into datastores as well as transmitted to clients
	-- Data synced this way will be available by _G.Game[plr][<module_name>]
	
	local Players = Game.PreLoad(game.ReplicatedFirst.Modules.Players)
	--Players.RegisterPlayerDataModule(PathToModule)
end

function Game.Begin(Main)
	LazyModules.Begin(Game, Main)
end

return Game
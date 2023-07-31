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

function Game.Begin(Main)
	LazyModules.Begin(Game, Main)
end

return Game
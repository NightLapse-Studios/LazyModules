local Game = { }
Game.LOADING_CONTEXT = -100

-- Do not access this field unless absolutely necessary
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
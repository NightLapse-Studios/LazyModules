--!strict

local Tests = require(game.ReplicatedFirst.Lib.LazyModules.Stages.TestsStage)
local Enums = require(game.ReplicatedFirst.Lib.Enums)
local StdLib = require(game.ReplicatedFirst.Lib.StdLib)

export type Tester = Tests.Tester

-- Signals that a module with __load_gamestate has done its job
export type LoadedFunc = () -> ()

-- Specifies a module name which also uses __load_gamestate
-- Provides a callback that will be called once the specified module loads its gamestate
export type AfterLoadedFunc = (string, () -> ()) -> ()

export type Module = 	unknown & { [any]: any }
export type GameStateData = { [unknown]: unknown }

export type LazyModule = Module & {
	__init: 			((G: LMGame) -> ())?,
	__ui: 				((G: LMGame, I: Pumpkin, P: PropSet) -> ())?,
	__run: 				((G: LMGame) -> ())?,
	__tests: 			((G: LMGame, T: Tests.Tester) -> ())?,
	__get_gamestate: 	((G: LMGame, plr: Player) -> GameStateData)?,
	__load_gamestate: 	((G: LMGame, data: GameStateData, loaded: LoadedFunc, after: AfterLoadedFunc) -> ())?
}

export type LMGame = {
	Get: (self: LMGame, name: string, opt_specific_context: ("CLIENT" | "SERVER")?) -> LazyModule,
	Load: (self: LMGame, module: ModuleScript) -> LazyModule,
	_CollectedModules: 	{ [string]: LazyModule },
	_ModuleNames: 		{ [LazyModule]: string },
	_Initialized: 		{ [string]: boolean },
	CONTEXT: 			("CLIENT" | "SERVER"),
	LoadingContext: 	Enums.LoadingContext,
	RaycastResult: 		RaycastResult | false,
	RaycastResultNP:	RaycastResult | false,
	LoadedPlayers: 		{ [Player]: boolean? },
} & typeof(StdLib.LoadExports({}))

export type CollectModule<S, T> = { [S]: T }

local pumpkin = game.ReplicatedFirst.Lib:FindFirstChild("Pumpkin")
if not pumpkin then
	return { }
end

local _Pumpkin = require(game.ReplicatedFirst.Lib.Pumpkin)
-- Pumpkin types
-- It is recommended you grab these from this file and import pumpkin via the __ui stage
export type PropSet = _Pumpkin.PropSet
export type Pumpkin = _Pumpkin.PumpkinAPI

return { }
local Tests = require(game.ReplicatedFirst.Shared.LazyModules.Tests)
local Signals = require(game.ReplicatedFirst.Shared.LazyModules.Signals)

export type Tester = Tests.Tester
export type Signals = Signals.SignalAPI

export type Transmitter = Signals.Transmitter
export type Broadcaster = Signals.Broadcaster
export type Event = Signals.Event

-- Signals that a module with __load_gamestate has done its job
export type LoadedFunc = () -> ()

-- Specifies a module name which also uses __load_gamestate
-- Provides a callback that will be called once the specified module loads its gamestate
export type AfterLoadedFunc = (string, () -> ()) -> ()

export type Module = 	unknown & { [any]: any }
export type GameStateData = { [unknown]: unknown }

export type LazyModule = Module & {
	__init: 			((G: LMGame) -> ())?,
	__build_signals: 	((G: LMGame, B: Signals) -> ())?,
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
	LOADING_CONTEXT: 	number,
	[Player]: 			unknown
}

export type CollectModule<S, T> = { [S]: T }

-- Pumpkin types
-- It is recommended you grab these from this file and import pumpkin via the __ui stage
export type PropSet = _Pumpkin.PropSet
export type Pumpkin = _Pumpkin.PumpkinAPI

return { }
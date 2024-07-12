# LazyModules

LazyModules (LM) is an opinionated framework for roblox games. It is based on streamlining issues we (Rusty and Vijet) have encountered making large, complex games in roblox. If you use it the way we have used it, it is transformational in what it feels like to write and debug a roblox game.

# Template file

A [template file](src/full/Modules/BaseLazyModule.luau) that uses all stages supported in the full release with their types.

## How it works

LM does Module-globbing, i.e. it requires all modules (specified by directory whitelist/blacklists in [Config.luau](src/base/Config.luau)). However, you are **never** intended to require LM in your modules, so your game itself still uses `require` trees to form is structure.

Similar to Knit, LM supports an "execution model" which we refer to as startup stages, but they are available everywhere. Through these stages, LM is passed into your modules as long as you define e.g. a `mod.__init(G)` function. The `Game` object, abbreviated as `G`, can be used to solve file-dependency issues with `G:Get("<ModuleName>")`. However this should only be done when necessary to promote type safety in your project.

Some startup stages are used to remove the need for boilerplate when doing common things like networking. The `__build_signals(G, B)` stage provides `B` which can be used to create remote events with context-agnostic usage.

```luau
local MyTransmitter

function mod.__build_signals(G, B)
	MyTransmitter = B:NewTransmitter("MyTransmitter")
		:ServerConnection(function(plr, ...)
		
		end)
		:ClientConnection(function(_, ...)
		
		end)
end
```

A certain startup stage being executed has undefined module-order, so definitions like the example above are provided through callbacks when the stage ends:

```luau
local MyTransmitter

function mod2.__build_signals(G, B)
    B:GetTransmitter("MyTransmitter", function(v), MyTransmitter = v end)
end
```

But wait, how do I know when it's safe to use `MyTransmitter`? This is a problem that tends to crop up in complex/large codebases, not just in the example above, in fact it's exactly the reason we want execution stages to begin with:

```lua
local MyTransmitter

function mod.__init(G)
	MyTransmitter:Transmit("data") -- error: MyTransmitter is nil
end

function mod.__run(G)
	MyTransmitter:Transmit("data") -- OK: __run is after __build_signals which is after __init
end

function mod2.__build_signals(G, B)
	B:GetTransmitter("MyTransmitter", function(v), MyTransmitter = v end)
end
```

Instead of firing signals or putting callbacks everywhere, we use startup stages to synchronize a known "when" for functionality. Advanced use cases can even implement custom startup stages that build the synchronization directly into LM.

## Tests

One of the startup stages available in all tiers is __tests. This allows in-file (or out of file) testing of the game as it is when it runs. In principal, your tests can move the player, use abilities, test datastores, etc. [Broader example](src/base/Lib/CircleBuffer.luau#97)

```lua
function mod.__tests(G, T)
    T:Test("Do this thing", function()
        local a = 1

        T:ForContext("in this context",
            T.Equal, a, 1,
            T.LessThan, a, 2
        )
    end)
end
```

## Release tiers
LM has "tiers" of releases which correspond to different levels of invasiveness or bloat.

* [Minimal](src/minimal/README.md)
	* The barebones of just startup stages, including a tests stage
* [Base](src/base/README.md)
	* Adds DebugMenu and Debug library
	* Adds __ui stage and Pumpkin/Roact
* [Full](src/full/README.md)
	* Adds a Player class accessible from `Game[plr]` after DataStore for associated player is fetched
	* Adds `PlayerDataModules` associated with the Player class
	* Guarantees the player object, game state, and datastore data exists by the time `__run` is running on the client

# Roadmap

* Dedicated Docs
* Improve types
* Add types to dependencies that are missing them
* Investigate the quality of all packaged dependencies
* BIG: Optimize networking library (buffer packing, single remote)
* Re-examine the usage of Pumpkin in place of lighter weight frameworks
* Integrate our replacement for ContextActionSerice and Controllers (requires the default PlayerModule to be overriden)

# Games built with LazyModules

[Clash!](https://www.roblox.com/games/8256020164/Clash)
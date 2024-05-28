# LazyModules

LazyModules (LM) is an opinionated WIP framework for roblox games. It is not strongly principled, instead it is pragmatic and based on solving issues we have faced in making deep, somewhat large, system-based games. If you use it the way we have used it, it is transformational in what it feels like to write and debug a roblox game. I am not trying to sell LM, I'm just pretty satisfied with how it feels and want to show off our work.

## How it works

What has become the LM environment started as a need to report errors from `require` to an off-roblox server, and to see what benefits we can get from there.

LM first searches for all module scripts and `require`s them. It then makes these modules available to other modules by passing them in to standardized callbacks that can be defined in any module script. These standardized callbacks are the bread and butter of LM; they are the foundation of the structure of LM games.

The standardized callbacks are executed across all scripts on a per-callback basis I.E. every `__init` function will be called in every module, and then the next callback, `__build_signals` is called in every module, up to the `__run` step. The order of module execution is undefined.
As a result of this process, each stage sets up an "async fence" where code which runs during each stage can only depend on functionality implemented in previous stages, making race conditions easy to resolve by looking at what stages functionality is defined in.

[LMProtocol.md](LMProtocol.md) describes the callback and startup process more specifically

```lua
local mod = { }

-- This function will be called by LM
function mod:__init(G)
	-- This will work as long as MyModule.lua is visible to LM
	local MyModule = G.Get("MyModule")

	-- The UserInput library is a standard feature of LM
	G.Get("UserInput"):Handler(Enums.KeyCode.M,
		function(input: InputObject)
			print("M pressed")

			return true
		end,
		function(input: InputObject)
			print("M released")

			return true
		end
	)
end

return mod
```

## Feature overview / quick start guide

1) Defined startup routine

	As mentioned above, the LM callbacks follow the rule that they can rely on previously executed callback steps, but code which is run by the same callback step cannot be relied on. So when a module is `require`d (by LM),
	the module-scope code is, of course, executed, but it cannot rely on any other module-level code from any other modules. `__init`-level code can rely on all module-level code, but not on other `__init`-level code, and so on.
	The goal here is to address any moments when we are wondering "When does this run? When is it ready to use and when is it not?"

	It is best to think of module-level code as the "definitions and declarations" stage of startup, somewhat similar to compiling in traditional languages.

2) Any module can depend on any module

	Since LM `require`s all modules, the only time it is possible to enter a `require` loop is if a module attempts to rely on LM core files. That should never happen, as a result, modules cannot enter a `require` loop if they
	depend on eachother via `G.Load`.
	
	**It is still recommended to use `require`** for type safety, but `G.Get` can be used as a generic dependency injector, trivializing complex problems of code/data visibility/dependency

3) Standard library

	The setup time to access powerful but regularly-used features of roblox should be as close to 0 as possible. Common patterns should also be readily available. To accomplish this, LM implements standard libraries which wrap roblox features, so that the boilerplate can be standardized. E.G. Tweens, Audio, UserInput. The libraries are expanded as-needed and are not "core" to LM.

4) The "Game" object

	The standard library isn't tremendously accessible if we have to require each lib 1 by 1. So instead we have [StdLib.lua](src/Util/StdLib.lua), which is loaded alongside LM. Its API values are stored in the Game object, and the Game object is readily accessible.

```lua
-- Modules managed by LM will have access to _G.Game for the stdlib, even at require time
_G.Game.print_c("This will only print on the client")

-- The Game object is abbreviated to G. Think of it as a better _G.
function mod:__init(G)
	-- This code path only runs once, so accessing G for stdlib things in this code path is trivial overhead.
	-- This makes for good ergonomics when you are familiar with the stdlib
	if G.IsMobile then
		print("This is mobile")
	end

	-- Quick access to the Debug library
	G.Debug.DebugModelAxis(--[[Some model]])

	-- When performance matters, we can load it like a regular lib
	local Debug = G.Load("Debug")
	-- While "legal", this form is heavily discouraged for consistency and safety.
	-- A typo in this form can go longer without being caught, and therefore has more damage potential
	local Debug = G.Debug
end
```

5) Signals & single-file all-context paradigm

	Signals are an abstraction on top of remote events which classifies their usage based on communication patterns. Even though there are only two main use cases currently, they have proven helpful in preventing networking
	spaghetti. Transmitters indicate simple client->server or server->client communication. Broadcasters are used for client->server->all-clients communication, and feature "ShouldAccept" functionality that inspects data from the client to give it the go-ahead to continue on to server processing and replication.

	Generally, all libraries are designed to be configured from one file on how to run on any context. We favor locality of behavior over breaking things down into their most general modules. Signals are the primary example. This is probably a controversial decision but it has turned out well in my experience
	so far. This rule is enforced in no way, it is simply a convention

```lua 
function mod:__build_signals(G, B)
	local EGBroadcaster = B:NewBroadcaster("EGBroadcaster")
		:ShouldAccept(function(plr, var1)
			-- NaN check
			if var1 == var1 then
				return true
			end

			return false
		end)
		:ServerConnection(function(plr, var1)
			print(plr.Name .. " got " .. var1 .. " more things")
		end)
		:ClientConnection(function(plr, var1)
			-- Do some UI stuff or something
			-- This does NOT 
		end)

	-- Undefined behavior! Signals aren't valid until the __build_signals stage has finished entirely.
	EGBroadcaster:Broadcast(100)
end

function mod:__run(G)
	-- OK: __run is the final startup step so signals are valid
	EGBroadcaster:Broadcast(100)
end
```

7) Pumpkin

	A wrapper we made for Roact, called Pumpkin (available on its own [here](https://github.com/NightLapse-Studios/Pumpkin)).
	Check [DebugMenu.lua](src/Util/Debug/DebugMenu.lua) for a practical stateful UI example, and [UI.lua](src/Util/Pumpkin/init.lua) for most implementation.

	Pumpkin has its own build step which runs just before `__run` (`__ui` is second to last). UI has its own step because it is nice ergonomically and, in theory, would encourage deep UI integration with systems.
```lua
-- I for IFrame or UI
-- P for Props
function mod:__ui(G, I, P)
	-- P() opens up a new prop set.
	local element = I:Frame(P()
		-- With automatic constructors, we don't have to type UDim2.new anymore :^)
		:Size(0.5, 0, 0.5, 0)
		:BackgroundColor3(0.1, 0.2, 0.1)
		-- Passing in the object directly still works though, passing in bindings directly works as well.
		:BackgroundColor3(Color3.new(0.1, 0.2, 0.1))
		
		-- We can also define custom functions that directly edit this propset.
		:JustifyLeft(0, 5)
		
		-- for advanced custom components, you may need to pass in custom props.
		:Prop("CustomProp", 100)
	):Children(
		-- Inline compatibility with roact for porting easability.
		Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0)
		}, {
			-- you can graduallly port UI with this level of compatibility
			I:Frame(P()
				:Size(1, 0, 1, 0)
			)
		})
	)
	
	
end
```

8) In-file testing

	Another landmark feature for LM is an in-file startup step which can run tests. It runs after `__run` and can be toggled from Config.lua. Like TestEZ, it can focus on specific files.

```lua
function module:__tests(G, T)
	local a,s,d,f,g = 1,2,3,4,5
	local cbuf = module.new(5)

	T:Test( "Handle typical modifications", function()
		cbuf:push(a)
		cbuf:push(s)
		cbuf:push(d)

		T:WhileSituation( "pushing",
			T.Equal, cbuf:__rawRead(1), a,
			T.Equal, cbuf:__rawRead(2), s,
			T.Equal, cbuf:__rawRead(3), d,
			T.Equal, cbuf:__rawRead(4), nil,
			T.Equal, cbuf:__rawRead(5), nil
		)
		--[[
			Other tests truncated...
		]]
	end)
end

-- Outputs (includes truncated tests):
--[[
📃 CircleBuffer should:
  	✅Handle typical modifications
  		✔ While pushing
  		✔ While writing from the front
  		✔ While pushing causes wrap-around
  		✔ While write-from-front after wrap-around
  		✔ While write-from-front causes wrap-around
  		✔ While clearing
  	✅Read
  		✔ While from-front
  		✔ While from-front, after overflow
  	✅Understand its size
  		✔ While empty
  		✔ While pushing
  		✔ While writing-from-front
  		✔ While overflowing
]]
```



## Status

**Note:** This list hasn't been updated in a long time. It is much more mature than when this list was made.

LazyModules is WIP, with some portions of it being more tested than others. Many files are built-to-a-point. Here I give my estimation on which files are most well-formed

	🟢 Stable; Tried & tested, may be expanded
	🟡 Usable; Some things left desired
	🟠 Experimental; May need to be redesigned
	🔴 Experimental; May become deprecated
	⚫ Dependency or unorganized; not really part of LM, just something needed to run it. Likely an idea in its infancy

```
src
	📁 client
		🟢Loader.lua
		🟢Main.lua
		🟢Startup.client.lua
	📁 server
		📁 Lib
			🟡DataStore3.lua
		🟢Main.lua
		🟢Startup.server.lua
	📁 Util
		🟢APIUtils.lua
		🟢AssociativeList.lua
		🟢AsyncList.lua
		🟢Config.lua
		🟢CircleBuffer.lua
		🟢Enums.lua
		🟡Error.lua
		🟢IDList.lua
		instance_list.lua
		🟢Maskables.lua
		🟠Meta.lua
		🟢PlayerRegistry.lua
		🟢Registry.lua
		🟠RelativeData.lua
		🟢SafeRequire.lua
		🟢SparseList.lua
		🟢Stack.lua
		🟢StdLib.lua
		🟢Visualizer.lua
		📁 Debug
			🔴DebugBuf.lua
			🟡DebugMenu.lua
			🟢init.lua
			⚫UITests.lua
		📁 LazyModules
			🟢Game.lua
			🟢init.lua
			🟡Tests.lua
			🟢UI.lua
			LMProtocol.md
			📁 Signals
				🟢init.lua
				🟢Transmitter.lua
				🟢Broadcaster.lua
				🟢__remote_wrapper.lua
				⚫ClassicSignal.lua
				🟠Event.lua
				🔴GameEvent.lua
		📁 UserInput
			🟢init.lua
			🟡GestureDetector.lua
			🟡Mobile.lua
	📁 shared
		
```



## Games built with LazyModules

[Clash!](https://www.roblox.com/games/8256020164/Clash)

-- `require` all modules
print("\n\t\t\tLOADER\n")
local Loader = require(script.Parent:WaitForChild("Loader"))
print("\n\t\t\tCOLLECT\n")
local Main = require(game.StarterPlayer.StarterPlayerScripts.Main)
local Game = require(game.ReplicatedFirst.Util.LazyModules.Game)

-- The __init functions form a dependency tree that will call __init in a depth-first order

print("\n\t\t\tBEGIN\n")
Game.Begin(Main)

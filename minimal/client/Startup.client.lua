
print("\n\t\t\tLOADER\n")
local Loader = require(script.Parent:WaitForChild("Loader"))
print("\n\t\t\tCOLLECT\n")
local Game = require(game.ReplicatedFirst.Shared.LazyModules.Game)

print("\n\t\t\tBEGIN\n")
Game:Begin()

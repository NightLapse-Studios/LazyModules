
-- `require` all modules
print("\n\t\t\tLOADER\n")
local Loader = require(script.Parent:WaitForChild("Loader"))
print("\n\t\t\tPRELOAD\n")
local Game = require(script.Parent:WaitForChild("Globals"))

-- The __init functions form a dependency tree that will call __init in a depth-first order

print("\n\t\t\tINIT\n")
Game.Begin()

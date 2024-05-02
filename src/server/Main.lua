local mod = { }

local DebugMenu = require(game.ReplicatedFirst.Util.Debug.DebugMenu)

DebugMenu.RegisterButton("Press", "Server", function(a)
	print("Server", a)
end)

return mod
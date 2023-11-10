
-- Main is has a special behavior with module-scope execution.
-- In the Startup scripts, Main is required before Game, which means this is the first meaningful code to execute
-- in the entire game, other than the loading screen. Anything done here also runs before LazyModules.
-- But note the __init functions; LazyModules still manages this script.
--
-- _G.Game is not available to module-scope code unless __init caches it in an upvalue

local mod = { }

-- Move Screen GUIs from ReplicatedStorage to PlayerGUI
do
	local PlayerGUI = game.Players.LocalPlayer.PlayerGui
	local GUIDir = game.ReplicatedStorage.GUIs

	for i,v in GUIDir:GetChildren() do
		v.Parent = PlayerGUI
	end
end

function mod:__init(G)
	local Convolution = G.Load("Convolution")
--[[ 	local Cvx = Convolution.new(Vector3.new(-20, 0, -40), Vector3.new(20, 10, 20), Vector3.new(2, 2, 2))
	Cvx:PositionParts()
	Cvx:Run() ]]
end

return mod

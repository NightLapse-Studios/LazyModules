
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

	local BaseInterface = GUIDir.BaseInterface
	local BaseInterface_NoInset = GUIDir.BaseInterface_NoInset
	local ToolTip = GUIDir.ToolTip
	local Windows = GUIDir.Windows

	BaseInterface.Parent = PlayerGUI
	BaseInterface_NoInset.Parent = PlayerGUI
	ToolTip.Parent = PlayerGUI
	Windows.Parent = PlayerGUI
end

function mod:__init(G)
	-- G.Load("Lib1")
end

return mod

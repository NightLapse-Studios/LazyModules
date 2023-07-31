--!strict
local ReplicatedFirst = game.ReplicatedFirst

local Loader = { }

local StarterGui = game:GetService("StarterGui")
StarterGui:ClearAllChildren()

--[[ Start the loading screen ]]
-- @Setup
ReplicatedFirst:RemoveDefaultLoadingScreen()


local function DisableCoreGuis()
	StarterGui:ClearAllChildren()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
end


local Success = pcall(DisableCoreGuis)
if not Success then
	repeat
		task.wait()
		Success = pcall(DisableCoreGuis)
	until Success
end

-- Turn off loading screen
-- @Setup

return Loader

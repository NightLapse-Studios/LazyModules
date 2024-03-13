-- Uncomment as needed.

local ReplicatedFirst = game.ReplicatedFirst
local StarterGui = game:GetService("StarterGui")

local Loader = { }

--[[ Start the loading screen ]]

--ReplicatedFirst:RemoveDefaultLoadingScreen()

local function DisableCoreGuis()
	--StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	--StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Captures, false)
	--StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
	--StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
	--StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	--StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	--StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.SelfView, false)
end


local Success = pcall(DisableCoreGuis)
if not Success then
	repeat
		task.wait()
		Success = pcall(DisableCoreGuis)
	until Success
end

-- Turn off loading screen

return Loader

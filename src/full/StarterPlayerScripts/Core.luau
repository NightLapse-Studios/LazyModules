--!strict

local RunService = game:GetService("RunService")

local LMT = require(game.ReplicatedFirst.Lib.LMTypes)
local UserInput = require(game.ReplicatedFirst.Lib.UserInput)
local RayCastGroups = require(game.ReplicatedFirst.Modules.RayCastGroups)
local Controller = require(game.ReplicatedFirst.Modules.Controllers.Controller)

local Character: Model
local Camera = game.Workspace.CurrentCamera
local Game: LMT.LMGame = _G.Game

local mod = { }

local function OnRender(dt)
	do
		local pos = UserInput.GetMousePos()
		local ray: Ray = Camera:ScreenPointToRay(pos.X, pos.Y)
		local params = RayCastGroups.GetRaycastParamsBL("MouseRay")
		local npParams = RayCastGroups.GetRaycastParamsBL("MouseRay", {Character})
		local mouseTarget = workspace:Raycast(ray.Origin, ray.Unit.Direction * 1000, params)
		local mouseTargetNoPlayer = workspace:Raycast(ray.Origin, ray.Unit.Direction * 1000, npParams)
		
		--print(mouseTarget)
		if mouseTarget then
			Game.RaycastResult = mouseTarget
		else
			Game.RaycastResult = false
		end

		if mouseTargetNoPlayer then
			Game.RaycastResultNP = mouseTargetNoPlayer
		else
			Game.RaycastResultNP = false
		end
	end
end

function mod.__run(G: LMT.LMGame)
	Character = game.Players.LocalPlayer.Character

	RunService.RenderStepped:Connect(OnRender)

	Controller.Instantiate(game.Players.LocalPlayer.Character, "Character")
	Controller.SetActive("Character")
end

return mod
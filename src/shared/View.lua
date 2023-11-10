if _G.Game.CONTEXT == "SERVER" then
	return { }
end


local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")

local Math
local Enums = _G.Game.Enums
local Vectors
local Interpolation
local RayCasting
local Mobile
local Tweens = _G.Game.PreLoad(game.ReplicatedFirst.Modules.Tweens)


-- Variables which may or may not be used by any given update function in here
local GameSettings = UserSettings().GameSettings
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local OriginalFOV = Camera.FieldOfView
local Mouse = LocalPlayer:GetMouse()
local MouseDelta = Vector2.new()
local PlanarOffset = Vector2.new(0, 0)
local OldCameraCF = CFrame.new(Vector3.new(0,0,0), Vector3.new(1,0,0))
local CurrentZoom = 10

-- Used by UpdateChar
local CurrentMouseBehavior
local MouseBehaviorPriorToOverride = false

local mod = {
	CameraMode = nil,
}

local Transitioning = false
local TransitionDur = 0
local TransitionBegan = 0
local TransitioningFrom = 0

function mod:__init(G)
	Math = G.Load("Math")
	Vectors = G.Load("Vectors")
	RayCasting = G.Load("RayCasting")
	Interpolation = G.Load("Interpolation")
	Mobile = G.Load("Mobile")

	local PlayerStatList
	PlayerStatList = G.Load("PlayerStatList")
	PlayerStatList.new_base(0, "HorizontalLookAngle")
	PlayerStatList.new_base(0, "VerticalLookAngle")
	PlayerStatList.new_base(false, "IsAiming")
	PlayerStatList.new_base(0, "cur_torso_ang")
	PlayerStatList.new_base(0, "cur_char_pitch")
	PlayerStatList.new_base(0, "cur_head_ang")
end

function mod:__finalize(G)
	workspace.CurrentCamera.CameraSubject = LocalPlayer.Character.PrimaryPart
	mod.Start(Enums.CameraMode.ThirdPersonLocked)
end

local MIN_Y = math.rad(-75)
local MAX_Y = math.rad(75)

local FRAME_TIME = 0.016666667

local ZOOM_INCRIMENT = 5
local MAX_ZOOM = ZOOM_INCRIMENT * 4
local MIN_ZOOM = ZOOM_INCRIMENT


-- These next two functions were taken from a core script so they may not work as described
local function RotateVector(startVector, xyRotateVector)
	local startCFrame = CFrame.new(Vector3.new(), startVector)
	local resultLookVector = (CFrame.Angles(0, -xyRotateVector.x, 0) * startCFrame * CFrame.Angles(-xyRotateVector.y,0,0)).lookVector
	return resultLookVector, Vector2.new(xyRotateVector.x, xyRotateVector.y)
end

local function rotate_camera(startLook: Vector3, xy_delta: Vector2)
	if VRService.VREnabled then
		local yawRotatedVector, xyRotateVector = RotateVector(startLook, Vector2.new(xy_delta.x, 0))
		return Vector3.new(yawRotatedVector.x, 0, yawRotatedVector.z).unit, xyRotateVector
	else
		local startVertical = math.asin(startLook.Y)
		local deltaVertical = -math.asin(xy_delta.Y)
		startVertical = if startVertical == startVertical then startVertical else 0
		deltaVertical = if deltaVertical == deltaVertical then deltaVertical else 0
		local yTheta = math.clamp(deltaVertical, MIN_Y - startVertical, MAX_Y - startVertical)
		local new_look = CFrame.new(Vector3.new(), startLook) * CFrame.Angles(0, -xy_delta.X, 0) * CFrame.Angles(yTheta, 0, 0)
		return new_look
	end
end

local PITCH_LIMIT = math.rad(90)

local MOUSE_SENSITIVITY = Vector2.new(math.pi*4, math.pi*1.9)
local MOUSE_SENS_MULT = 1

local THUMBSTICK_DEADZONE = 0.08
local CAMERA_THUMBSTICK_SPEED = 2
local CAMERA_THUMBSTICK_ACCEL = 10

function mod.SetMouseSensitivity(mult)
	MOUSE_SENS_MULT = mult
end

local function mouse_translation_to_angle(translationVector)
	local xTheta = (translationVector.x / 1920)
	local yTheta = (translationVector.y / 1200)
	return Vector2.new(xTheta, yTheta) * MOUSE_SENSITIVITY * MOUSE_SENS_MULT
end

local function processDelta(inputDelta)
	inputDelta = Vector2.new(inputDelta.X, inputDelta.Y * GameSettings:GetCameraYInvertValue())

	local desiredXYVector = mouse_translation_to_angle(inputDelta)
	MouseDelta += desiredXYVector
end

local function OnMouseMoved(input, processed)
	processDelta(input.Delta)
end

local accelValue = 0

local function OnThumbstickMoved(input, dt)
	local delta = input.Position
	
	if math.abs(delta.X) < THUMBSTICK_DEADZONE then
		delta *= Vector3.new(0, 1, 1)
	end
	
	if math.abs(delta.Y) < THUMBSTICK_DEADZONE then
		delta *= Vector3.new(1, 0, 1)
	end
	
	if delta.Magnitude > 0 then
		accelValue += CAMERA_THUMBSTICK_ACCEL * dt
	else
		accelValue = 0
	end
	
	delta *= Vector3.new(1, -1, 1)
	delta *= CAMERA_THUMBSTICK_SPEED + accelValue
	processDelta(delta)
end

local RRs = { }
local OCCLUDING_RAY_ANG_DT = math.asin(0.043)
local VERTICAL_CAM_OFFSET_3RD_PERSON = Vector3.new(0, 1, 0)
local ENFORCED_VERTICAL_OFFSET = Vector3.new(0, 2, 0)
local Y_PLANAR_OFFSET = 0.25
local PlanarAdjAmount = 1.2

local defaultRad = ENFORCED_VERTICAL_OFFSET
local HeightTween
function mod.SetCameraHeight(rad)
	if HeightTween then
		HeightTween:Cancel()
	end

	local target = rad and Vector3.new(0, rad, 0) or defaultRad

	HeightTween = Interpolation.TweenServiceCallback(ENFORCED_VERTICAL_OFFSET, target, 0.15, Enum.EasingStyle.Linear, Enum.EasingDirection.In, function(value)
		ENFORCED_VERTICAL_OFFSET = value
	end)
end

local function get_vertical_offset(current_zoom)
	return ENFORCED_VERTICAL_OFFSET + VERTICAL_CAM_OFFSET_3RD_PERSON * (current_zoom / MAX_ZOOM)
end

local function third_person_cam_update(ViewData, PrimaryPart, dt)
	-- We need to use the right vector of the camera after rotation, not before
	local angle_cf = rotate_camera(OldCameraCF.LookVector, MouseDelta)

	local zoom_offset_mul = .75 * ((CurrentZoom + 5) / MIN_ZOOM)
	local shoulder_offset = Vectors.PlanarOffset(angle_cf.LookVector, PlanarOffset * zoom_offset_mul)

	local vertical_offset = get_vertical_offset(CurrentZoom)

	local dist_offset = angle_cf * Vector3.new(0, 0, CurrentZoom)

	local char_pos = Camera.CameraSubject.Position
	local final_pos = char_pos + shoulder_offset + dist_offset + vertical_offset

	-- Ray cast towards the prospective_pos and clamp the zoom to any object in our way
	table.clear(RRs)
	local BL = RayCasting.GetRaycastParamsWL("Invisicam")
	for i = -1, 1, 1 do
		local offset = Vectors.PlanarOffset(angle_cf.LookVector, Vector2.new(i * OCCLUDING_RAY_ANG_DT * dist_offset.Magnitude))
		RRs[i + 2] = workspace:Raycast(char_pos + offset, final_pos - char_pos , BL)
	end

	if RRs[1] and RRs[2] and RRs[3] then
		-- Move towards the char an extra stud, just because :^)
		local applied_zoom = math.clamp(RRs[2].Distance, 0, CurrentZoom)
		dist_offset = angle_cf * Vector3.new(0, 0, applied_zoom)
		final_pos = char_pos + shoulder_offset + dist_offset + get_vertical_offset(applied_zoom)
	end

	return CFrame.new(final_pos, final_pos + angle_cf.LookVector)
end

mod[Enums.CameraMode.ThirdPersonLocked] = {
	MinCameraZoom = 5,
	MaxCameraZoom = 20,
	MouseBehavior = Enum.MouseBehavior.LockCenter,
	Type = Enum.CameraType.Scriptable,
	AutoRotateHumanoid = false,
	Update = third_person_cam_update,
	Enabled = function()

	end
}

mod[Enums.CameraMode.Studio] = {
	W = 0,
	A = 0,
	S = 0,
	D = 0,
	Q = 0,
	E = 0,
	Shift = 1,
	NormalSpeed = 100,
	RightClick = false,
	DragSensitivity = 0.2,
	MouseBehavior = Enum.MouseBehavior.LockCenter,
	cameraRot = Vector2.new(),
	Type = Enum.CameraType.Custom,
	Update = function(ViewData, _, dt)
		if ViewData.RightClick then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
			local mouseDeltainv = Vector2.new(-MouseDelta.Y, -MouseDelta.X)
			ViewData.cameraRot += mouseDeltainv * dt * ViewData.DragSensitivity
			MouseDelta = Vector3.new()
		else
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		ViewData.cameraRot = Vector2.new(math.clamp(ViewData.cameraRot.X, -PITCH_LIMIT, PITCH_LIMIT), ViewData.cameraRot.Y % (2*math.pi))
		return CFrame.new(Camera.CFrame.Position) * CFrame.fromOrientation(ViewData.cameraRot.X, ViewData.cameraRot.Y, 0) * CFrame.new(
			(ViewData.D - ViewData.A) * dt * ViewData.NormalSpeed * ViewData.Shift,
			(ViewData.E - ViewData.Q) * dt * ViewData.NormalSpeed * ViewData.Shift,
			(ViewData.S - ViewData.W) * dt * ViewData.NormalSpeed * ViewData.Shift
		)
	end
}

mod[Enums.CameraMode.Constant] = setmetatable({
	CFrame = nil,
	CFrameValue = nil,
	CFrameObj = nil,

	TransitioningFrom = nil,
	TransitionBegan = nil,
	TransitionDur = nil,

	Type = Enum.CameraType.Scriptable,
	MouseBehavior = Enum.MouseBehavior.Default,
	PopperCam = true,

	DeltaX = 0,
	DeltaY = 0,

	Enabled = function()

	end,
	Update = function(ViewData, _, dt)
		local targetCF = ViewData.CFrame or (ViewData.CFrameValue and ViewData.CFrameValue.Value) or (ViewData.CFrameObj and ViewData.CFrameObj.CFrame)

		if ViewData.TransitioningFrom then
			local curAlpha = (tick() - ViewData.TransitionBegan) / ViewData.TransitionDur

			targetCF = ViewData.TransitioningFrom:Lerp(targetCF, curAlpha)

			if curAlpha >= 0.985 then
				ViewData.TransitioningFrom = nil
				ViewData.TransitionBegan = nil
				ViewData.TransitionDur = nil
			end
		end

		local sensitivity = 0.000025

		ViewData.DeltaX = Math.LerpNum(ViewData.DeltaX, (Mouse.X - Camera.ViewportSize.X / 2) * sensitivity, 0.14 * (dt / FRAME_TIME))
		ViewData.DeltaY = Math.LerpNum(ViewData.DeltaY, (Mouse.Y - Camera.ViewportSize.Y / 2) * sensitivity, 0.14 * (dt / FRAME_TIME))

		return targetCF * CFrame.Angles(-ViewData.DeltaY, -ViewData.DeltaX, 0)
	end
}, {
	__newindex = function(t, k, v)
		rawset(t, k, v)

		-- when you write to one property, the others should be removed.
		local overwrites = {"CFrame", "CFrameValue", "CFrameObj"}
		if table.find(overwrites, k) then
			for _, prop in pairs(overwrites) do
				if prop ~= k then
					rawset(t, prop, nil)
				end
			end
		end
	end,
})

local function SetupTransition(transition_dur)
	Transitioning = true
	TransitioningFrom = Camera.CFrame
	TransitionBegan = tick()
	TransitionDur = transition_dur
end
local function StopTransition()
	Transitioning = nil
	TransitioningFrom = nil
	TransitionBegan = nil
	TransitionDur = nil
end

function mod.SetConstant(cfCompliant, transition_dur)
	local ViewData = mod[Enums.CameraMode.Constant]

	if transition_dur and transition_dur > 0 then
		ViewData.TransitioningFrom = Camera.CFrame
		ViewData.TransitionBegan = tick()
		ViewData.TransitionDur = transition_dur
	end

	local ty = typeof(cfCompliant)
	if ty == "CFrame" then
		ViewData.CFrame = cfCompliant
	elseif ty == "CFrameValue" then
		ViewData.CFrameValue = cfCompliant
	else
		ViewData.CFrameObj = cfCompliant
	end
end

function mod.Start(mode, transition_dur)
	if mod.CameraMode == mode then
		return
	end

	local newview = mod[mode]

	CurrentMouseBehavior = newview.MouseBehavior

	if newview.Enabled then
		newview.Enabled()
	end

	if transition_dur then
		SetupTransition(transition_dur)
	end

	Camera.CameraType = newview.Type or Enum.CameraType.Custom
	mod.CameraMode = mode

	if newview.MinCameraZoom then
		LocalPlayer.CameraMinZoomDistance = newview.MinCameraZoom
	end
	if newview.MaxCameraZoom then
		LocalPlayer.CameraMaxZoomDistance = newview.MaxCameraZoom
	end
end

function mod.GetCameraOffset(fov, extentsSize, multiplier)
	local x, y, z = extentsSize.X, extentsSize.Y, extentsSize.Z
	local maxSize = math.sqrt(x^2 + y^2 + z^2)
	local fac = math.tan(math.rad(fov)/2)
	local depth = 0.5*maxSize/fac
	return depth * multiplier
end

function mod.FitToScreen(fov, primaryCF, boundingBoxCF, boundingBoxSize, angles, multiplier, optModelToCamera_CameraCF, optCameraToModel)
	angles = angles or CFrame.Angles(0,0,0)
	multiplier = multiplier or 1.2

	local cameraOffset = mod.GetCameraOffset(fov, boundingBoxSize, multiplier)


	if optCameraToModel then
		return CFrame.new(boundingBoxCF.Position) * angles * CFrame.new(0, 0, cameraOffset), nil
	elseif optModelToCamera_CameraCF then
		local camcf = optModelToCamera_CameraCF
		local modelcfOffset = CFrame.new(camcf.LookVector * cameraOffset)
		local modelcf = modelcfOffset * angles * (primaryCF * boundingBoxCF:Inverse())

		return nil, modelcf
	else
		local camcf = CFrame.new(Vector3.new(), Vector3.new(0, 0, 1))
		local modelcfOffset = CFrame.new(Vector3.new(0,0,1).Unit * cameraOffset)

		local r = primaryCF:ToObjectSpace(boundingBoxCF)

		local modelcf = modelcfOffset * angles * r:Inverse()

		return camcf, modelcf
	end
end

function mod.IsVisible(position, padding, wpadding)
	padding = padding or 0
	wpadding = wpadding or 0
	
	local screenPos, visible = Camera:WorldToViewportPoint(position)
	
	if not visible then
		return false
	end
	
	local vpSize = Camera.ViewportSize
	
	if screenPos.X < padding or screenPos.Y < padding or (vpSize.X - screenPos.X) < padding or (vpSize.Y - screenPos.Y) < padding then
		return false
	end
	
	local params = RayCasting.GetRaycastParamsBL("Barriers")
	local camPos = Camera.CFrame.Position
	local line = position - camPos
	line = line.Unit * (line.Magnitude - wpadding)
	local result = workspace:Raycast(camPos, line, params)
	
	return not result
end

local fovTweens = {}

function mod.TweenFOV(adj: number, dur: number, skipRet: boolean)
	if skipRet then
		return skipRet
	end
	
	local FOVTweenType = Tweens.new()
		:SetEasingStyle(Enum.EasingStyle.Linear)
		:SetEasingDirection(Enum.EasingDirection.In)
	
	local inst = Instance.new("NumberValue")
	inst.Value = 0
	
	local FOVTween = FOVTweenType
		:SetLength(dur)
		:Run(inst, { Value = adj })
	
	table.insert(fovTweens, FOVTween)

	return FOVTween
end

function mod.SmoothResetFOV(FOVTween)
	if not FOVTween then
		return nil
	end
	
	FOVTween:Pause()
	
	local curAdj = FOVTween.Instance.Value
	
	local resetTween = mod.TweenFOV(-curAdj, 0.15)
	resetTween.Tween.Completed:Connect(function()
		FOVTween:Cancel()
		resetTween:Cancel()
	end)
	
	return nil
end

local function UpdateCamera(dt)
	local sumFOV = OriginalFOV
	
	for i = #fovTweens, 1, -1 do
		local tween = fovTweens[i]
		local adj = tween.Instance.Value
		
		if not tween.Tween then-- tween was canceled
			table.remove(fovTweens, i)
		else
			sumFOV += adj
		end
	end
	
	Camera.FieldOfView = sumFOV
	
	local char = LocalPlayer.Character
	local char_primary_part = char and char.PrimaryPart

	local CameraMode = mod.CameraMode

	if not CameraMode then
		return
	end

	local ViewData = mod[CameraMode]

	local targetCF = ViewData.Update(ViewData, char_primary_part, dt)

	if not targetCF then
		return
	end

	if Transitioning then
		local curAlpha = (tick() - TransitionBegan) / TransitionDur

		targetCF = TransitioningFrom:Lerp(targetCF, curAlpha)

		if curAlpha >= 0.985 then
			StopTransition()
		end
	end

	Camera.CFrame = targetCF
	Camera.Focus = Camera.CFrame

	OldCameraCF = targetCF

	MouseDelta = Vector2.new()
end

function mod.OverrideMouseBehavior(state: Enum<MouseBehavior>)
	local old = CurrentMouseBehavior
	CurrentMouseBehavior = state
	MouseBehaviorPriorToOverride = old

	return old
end

function mod.StopMouseBehaviorOverride()
	if MouseBehaviorPriorToOverride ~= false then
		CurrentMouseBehavior = MouseBehaviorPriorToOverride
		MouseBehaviorPriorToOverride = false
	end
end

local lastThumbstickInput

local function SetLastThumbstickInput(input)
	lastThumbstickInput = input
end

local function HouseKeeping(_, dt)
	if CurrentMouseBehavior then
		UserInputService.MouseBehavior = CurrentMouseBehavior
	end
	
	if lastThumbstickInput then
		OnThumbstickMoved(lastThumbstickInput, dt)
	end
end

function mod:__run(G)
	local UserInput = G.Load("UserInput")
	local Interpolation = G.Load("Interpolation")
	

	UserInput:Hook(Enum.UserInputType.MouseMovement, OnMouseMoved)
	UserInput:Hook(Enum.KeyCode.Thumbstick2, SetLastThumbstickInput)

	local PlanarTween

	local LastOffset
	
	local function CalcXOffset_A(down: boolean)
		LastOffset = "Q"
		return Vector2.new(-PlanarAdjAmount, 0)
	end
	local function CalcXOffset_D(down: boolean)
		LastOffset = "E"
		return Vector2.new(PlanarAdjAmount, 0)
	end

	local function TweenPlanarOffset(goal)
		if PlanarTween then
			PlanarTween:Cancel()
		end

		PlanarTween = Interpolation.TweenServiceCallback(PlanarOffset.X, goal.X, 0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, function(v)
			PlanarOffset = Vector2.new(v, Y_PLANAR_OFFSET)
		end)
	end

	UserInput:Hook(Enum.KeyCode.Q,
		function(input)
			TweenPlanarOffset(CalcXOffset_A(true))
		end)

	UserInput:Hook(Enum.KeyCode.E,
		function(input)
			TweenPlanarOffset(CalcXOffset_D(true))
		end)

	-- initialize over the shoulder as E
	TweenPlanarOffset(CalcXOffset_D(true))
	
	UserInput:Hook(Enum.KeyCode.DPadLeft,
		function(input)
			TweenPlanarOffset(CalcXOffset_A(true))
		end)
		
	UserInput:Hook(Enum.KeyCode.DPadRight,
		function(input)
			TweenPlanarOffset(CalcXOffset_D(true))
		end)
	
	UserInput:Handler(Enum.UserInputType.MouseWheel,
		function(input: InputObject)
			if input.Position.Z > 0 then
				CurrentZoom -= ZOOM_INCRIMENT
			elseif input.Position.Z < 0 then
				CurrentZoom += ZOOM_INCRIMENT
			end

			CurrentZoom = math.clamp(CurrentZoom, MIN_ZOOM, MAX_ZOOM)
		end)
	
	
	UserInput:Hook(Enum.KeyCode.ButtonR3,
		function(input)
			CurrentZoom = (CurrentZoom + ZOOM_INCRIMENT) % (MAX_ZOOM + ZOOM_INCRIMENT)
			CurrentZoom = math.clamp(CurrentZoom, MIN_ZOOM, MAX_ZOOM)
		end)
	
	
	local lastAppliedScale = 1
	local processThisScale = true
	
	UserInputService.TouchPinch:Connect(function(positions, scale: number, velocity: number, state, processed: boolean)
		if state == Enum.UserInputState.Begin then
			processThisScale = true
			lastAppliedScale = 1
			
			for _, v in positions do
				if not Mobile.IsPositionInDetector("CameraMovementDetector", v) then
					processThisScale = false
					return
				end
			end
		end
		
		if not processThisScale then
			return
		end
		
		if math.abs(scale - lastAppliedScale) > 0.25 then
			local direction = -math.sign(scale - lastAppliedScale)
			
			lastAppliedScale = scale
			
			CurrentZoom += ZOOM_INCRIMENT * direction
			CurrentZoom = math.clamp(CurrentZoom, MIN_ZOOM, MAX_ZOOM)
		end
	end)
	
	RunService:BindToRenderStep("CameraAdd", Enum.RenderPriority.Camera.Value + 1, UpdateCamera)
	RunService.Stepped:Connect(HouseKeeping)
end

return mod

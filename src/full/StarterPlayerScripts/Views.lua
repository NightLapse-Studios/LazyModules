--!strict
--!native

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")

local Math = require(game.ReplicatedFirst.Modules.Math)
local Enums = require(game.ReplicatedFirst.Lib.Enums)
local Vectors = require(game.ReplicatedFirst.Modules.Vectors)
local Interpolation = require(game.ReplicatedFirst.Modules.Interpolation)
local UserInput = require(game.ReplicatedFirst.Lib.UserInput)
local Mobile = require(game.ReplicatedFirst.Lib.UserInput.Mobile)
local Tweens = require(game.ReplicatedFirst.Modules.Tweens)
local RayCastGroups = require(game.ReplicatedFirst.Modules.RayCastGroups)


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
local InputUnlocksMouse = false

-- Used by UpdateChar
local CurrentMouseBehavior: Enum.MouseBehavior | false = false
local MouseBehaviorPriorToOverride: Enum.MouseBehavior | false = false

local Views = {
	CameraMode = nil,
}

local ViewConstructors: { [Enums.CameraMode]: (BasePart | Humanoid) -> View } = { }
local CurrentView: View? = nil

local Transitioning: boolean = false
local TransitionDur: number = 0
local TransitionBegan: number = 0
local TransitioningFrom: CFrame = CFrame.new()

local MIN_Y = math.rad(-75)
local MAX_Y = math.rad(75)

local FRAME_TIME = 0.016666667

local ZOOM_INCRIMENT = 5
local MAX_ZOOM = ZOOM_INCRIMENT * 4
local MIN_ZOOM = 0


-- These next two functions were taken from a core script so they may not work as described
local function rotate_vector(startVector: Vector3, xyRotateVector: Vector3)
	local startCFrame = CFrame.new(Vector3.new(), startVector)
	local resultLookVector = (CFrame.Angles(0, -xyRotateVector.X, 0) * startCFrame * CFrame.Angles(-xyRotateVector.Y,0,0)).LookVector
	return resultLookVector, Vector2.new(xyRotateVector.X, xyRotateVector.Y)
end

local function rotate_camera(startLook: Vector3, xy_delta: Vector2): CFrame
	if VRService.VREnabled then
		local yawRotatedVector, xyRotateVector = rotate_vector(startLook, Vector3.new(xy_delta.X, 0, 0))
		return Vector3.new(yawRotatedVector.X, 0, yawRotatedVector.Z).Unit, xyRotateVector
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
local POPPER_ADD = 2
local POPPER_RAY_PAD = 2

local MOUSE_SENSITIVITY = Vector2.new(math.pi*4, math.pi*1.9)
local MOUSE_SENS_MULT = 1

local THUMBSTICK_DEADZONE = 0.14
local CAMERA_THUMBSTICK_SPEED = 2
local CAMERA_THUMBSTICK_ACCEL = 10

function Views.SetMouseSensitivity(mult)
	MOUSE_SENS_MULT = mult
end

local function mouse_translation_to_angle(translationVector: Vector3)
	local xTheta = (translationVector.X / 1920)
	local yTheta = (translationVector.Y / 1200)
	return Vector2.new(xTheta, yTheta) * MOUSE_SENSITIVITY * MOUSE_SENS_MULT
end

local function processDelta(inputDelta: Vector3)
	inputDelta = Vector2.new(inputDelta.X, inputDelta.Y * GameSettings:GetCameraYInvertValue())

	local desiredXYVector = mouse_translation_to_angle(inputDelta)
	MouseDelta += desiredXYVector
end

local function OnMouseMoved(input: UserInput.InputObject2, processed: boolean)
	processDelta(input.Delta)

	return false
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
function Views.SetCameraHeight(rad)
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

local function clamp_algorithm(char_pos, final_pos, angle_cf, dist_offset)
	-- Ray cast towards the prospective_pos and clamp the zoom to any object in our way
	table.clear(RRs)
	local BL = RayCastGroups.GetRaycastParamsBL("Blood")
	
	local targetPositions = {
		Camera:ViewportPointToRay(0, 0, 0).Origin,
		Camera:ViewportPointToRay(Camera.ViewportSize.X, 0, 0).Origin,
		final_pos,
		Camera:ViewportPointToRay(Camera.ViewportSize.X, Camera.ViewportSize.Y, 0).Origin,
		Camera:ViewportPointToRay(0, Camera.ViewportSize.Y, 0).Origin,
	}
	
	-- we will start from 3 different positions near the player
	for i = -1, 1, 1 do
		local offset = Vectors.PlanarOffset(angle_cf.LookVector, Vector2.new(i * OCCLUDING_RAY_ANG_DT * dist_offset.Magnitude))
		
		-- we will cast do 5 different positions near the camera, the center and the corners.
		for o = 1, 5 do
			local target_pos = targetPositions[o]
			local origin = char_pos + offset
			
			local directionVec = target_pos - origin
			-- add an aditional distance to the check
			local rayVec = directionVec.Unit * (directionVec.Magnitude + POPPER_RAY_PAD)
			
			local preDistance = RRs[i + 2] or math.huge
			local rr = workspace:Raycast(origin, rayVec, BL)
			
			--Visualizer:ShowForce(origin, rayVec, tostring(i) .. tostring(o), rr and Color3.new(1, 0, 0) or Color3.new(0, 1, 0))
			
			local distance = rr and rr.Distance or math.huge
			if rr and o ~= 3 then
				-- account for angle of ray
				local angle = Math.AngleBetweenVectors(target_pos, origin, final_pos)
				distance = math.cos(angle) * distance
			end
			
			if rr and distance < preDistance then
				RRs[i + 2] = distance
			end
		end
	end

	if RRs[1] and RRs[2] and RRs[3] then
		-- Move towards the char an extra distance, just because :^)
		local applied_zoom = math.clamp(math.max(RRs[1], RRs[2], RRs[3]) - POPPER_ADD, 0, CurrentZoom)
		
		return applied_zoom
	end
	
	return CurrentZoom
end

type View = {
	MinCameraZoom: number | false,
	MaxCameraZoom: number | false,
	MouseBehavior: Enum.MouseBehavior,
	Update: (BasePart, number) -> CFrame,
	Destroy: () -> nil,
	[any]: nil
}
ViewConstructors[Enums.CameraMode.ThirdPerson] = function()
	return {
		MouseBehavior = Enum.MouseBehavior.LockCenter,
		MinCameraZoom = 0,
		MaxCameraZoom = 200,
		Update = function(PrimaryPart, dt)
			-- We need to use the right vector of the camera after rotation, not before
			local angle_cf: CFrame = rotate_camera(OldCameraCF.LookVector, MouseDelta)
		
			if CurrentZoom == 0 then
				local head = game.Players.LocalPlayer.Character.Head
				local pos = head.Position
			
				local offset = angle_cf * Vector3.new(0, head.Size.Y / 2, head.Size.X / 2)
				pos += offset
		
				return CFrame.new(pos, pos + angle_cf.LookVector)
			end
		
			local zoom_offset_mul = .2 * CurrentZoom
			local shoulder_offset = Vectors.PlanarOffset(angle_cf.LookVector, PlanarOffset * zoom_offset_mul)
		
			local vertical_offset = get_vertical_offset(CurrentZoom)
		
			local dist_offset = angle_cf * Vector3.new(0, 0, CurrentZoom)
		
			local char_pos = Camera.CameraSubject.Position
			local final_pos = char_pos + shoulder_offset + dist_offset + vertical_offset
		
			-- set the camera cframe temporarily for the ViewportPointToRay
			Camera.CFrame = CFrame.new(final_pos, final_pos + angle_cf.LookVector)
			local applied_zoom = clamp_algorithm(char_pos, final_pos, angle_cf, dist_offset)
			
			dist_offset = angle_cf * Vector3.new(0, 0, applied_zoom)
			final_pos = char_pos + shoulder_offset + dist_offset + get_vertical_offset(applied_zoom)
		
			return CFrame.new(final_pos, final_pos + angle_cf.LookVector)
		end,
		Destroy = function()
		end
	}
end
ViewConstructors[Enums.CameraMode.TopDownOrbital] = function()
	local ang = 0
	local OrbitalSpeed = 150
	local QHeld, EHeld = false, false
	local CWHandler = UserInput.Handler(Enum.KeyCode.Q,
		function()
			QHeld = true
			return true
		end,
		function()
			QHeld = false
			return true
		end)
	local CCWHandler = UserInput.Handler(Enum.KeyCode.E,
		function()
			EHeld = true
			return true
		end,
		function()
			EHeld = false
			return true
		end)

	local UnzoomedOffset = Vector3.new(0, 5, 1).Unit

	CurrentZoom = 40

	return {
		MouseBehavior = Enum.MouseBehavior.Default,
		MinCameraZoom = 15,
		MaxCameraZoom = 40,
		Update = function(PrimaryPart, dt)
			local dir = 0
			if QHeld then
				dir += math.pi / 180
			end
			if EHeld then
				dir -= math.pi / 180
			end

			ang += dir * dt * OrbitalSpeed

			local UnrotatedOffset = UnzoomedOffset * CurrentZoom
			local RotatedOffset = Vector3.new(UnrotatedOffset.Z * math.sin(ang), UnrotatedOffset.Y, UnrotatedOffset.Z * math.cos(ang))

			return CFrame.new(PrimaryPart.Position + RotatedOffset, PrimaryPart.Position)
		end,
		Destroy = function()
			CWHandler:Disconnect()
			CCWHandler:Disconnect()
			CWHandler = nil
			CCWHandler = nil
		end
	}
end
ViewConstructors[Enums.CameraMode.FirstPerson] = function(primary_part)
	local HideInstanceTypes = {
		"BasePart",
		"Decal",
		"Beam",
		"ParticleEmitter",
		"Trail",
		"Fire",
		"Smoke",
		"Sparkles",
		"Explosion",
	}

	local model: Instance? = primary_part
	while model and (not model:IsA("Model")) do
		model = model.Parent
	end

	assert(model)

	local hidden_parts = { }
	
	for _, ins in model:GetDescendants() do
		for _, ty in HideInstanceTypes do
			if ins:IsA(ty) then
				ins.LocalTransparencyModifier = 1
				table.insert(hidden_parts, ins)
			end
		end
	end

	model.DescendantAdded:Connect(function(ins)
		for _, ty in HideInstanceTypes do
			if ins:IsA(ty) then
				ins.LocalTransparencyModifier = 1
				table.insert(hidden_parts, ins)
			end
		end
	end)

	return {
		MouseBehavior = Enum.MouseBehavior.LockCenter,
		MinCameraZoom = 0,
		MaxCameraZoom = 0,
		Update = function(PrimaryPart, dt)
			-- We need to use the right vector of the camera after rotation, not before
			local angle_cf: CFrame = rotate_camera(OldCameraCF.LookVector, MouseDelta)
		
			local head = game.Players.LocalPlayer.Character.Head
			local pos = head.Position
		
			local offset = angle_cf * Vector3.new(0, head.Size.Y / 2, head.Size.Z / 2)
			pos += offset

			local pp_pos = PrimaryPart.CFrame.Position
			PrimaryPart.CFrame = CFrame.new(pp_pos, pp_pos + (angle_cf.LookVector * Vector3.new(1, 0, 1)))
	
			return CFrame.new(pos, pos + angle_cf.LookVector)
		end,
		Destroy = function()
			for i,v in hidden_parts do
				v.LocalTransparencyModifier = 0
			end

			hidden_parts = nil
		end
	}
end

--[[ ViewConstructors[Enums.CameraMode.Studio] = {
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
} ]]

local function SetupTransition(transition_dur)
	Transitioning = true
	TransitioningFrom = Camera.CFrame
	TransitionBegan = tick()
	TransitionDur = transition_dur
end
local function StopTransition()
	Transitioning = false
	-- TransitioningFrom = nil
	TransitionBegan = 0
	TransitionDur = 0
end

function Views.Start(mode: Enums.CameraMode, focus_subject: (BasePart | Humanoid), transition_dur: number?)
	Camera.CameraSubject = focus_subject

	if Views.CameraMode == mode then
		return
	end

	local newview = ViewConstructors[mode](focus_subject)

	CurrentView = newview
	CurrentMouseBehavior = newview.MouseBehavior

	if transition_dur and transition_dur > 0 then
		SetupTransition(transition_dur)
	end

	if newview.MinCameraZoom then
		LocalPlayer.CameraMinZoomDistance = newview.MinCameraZoom
	end
	if newview.MaxCameraZoom then
		LocalPlayer.CameraMaxZoomDistance = newview.MaxCameraZoom
	end
end

function Views.GetCameraOffset(fov, extentsSize, multiplier)
	local x, y, z = extentsSize.X, extentsSize.Y, extentsSize.Z
	local maxSize = math.sqrt(x^2 + y^2 + z^2)
	local fac = math.tan(math.rad(fov)/2)
	local depth = 0.5*maxSize/fac
	return depth * multiplier
end

function Views.FitToScreen(fov, primaryCF, boundingBoxCF, boundingBoxSize, angles, multiplier, optModelToCamera_CameraCF, optCameraToModel)
	angles = angles or CFrame.Angles(0,0,0)
	multiplier = multiplier or 1.2

	local cameraOffset = Views.GetCameraOffset(fov, boundingBoxSize, multiplier)


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

function Views.IsVisible(position, padding, wpadding)
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
	
	local params = RayCastGroups.GetRaycastParamsBL("FootSteps")
	local camPos = Camera.CFrame.Position
	local line = position - camPos
	line = line.Unit * (line.Magnitude - wpadding)
	local result = workspace:Raycast(camPos, line, params)
	
	return not result
end

local fovTweens = {}

function Views.TweenFOV(adj: number, dur: number, skipRet: boolean)
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

function Views.SmoothResetFOV(FOVTween)
	if not FOVTween then
		return nil
	end
	
	FOVTween:Pause()
	
	local curAdj = FOVTween.Instance.Value
	
	local resetTween = Views.TweenFOV(-curAdj, 0.15)
	resetTween.Tween.Completed:Connect(function()
		FOVTween:Cancel()
		resetTween:Cancel()
	end)
	
	return nil
end

local CameraFocusOverride = nil

function Views.SetCameraFocusOverride(cf)
	CameraFocusOverride = cf
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

	if not CurrentView then return end

	local targetCF = CurrentView.Update(char_primary_part, dt)

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
	Camera.Focus = CameraFocusOverride or Camera.CFrame

	OldCameraCF = targetCF

	MouseDelta = Vector2.new()
end

function Views.OverrideMouseBehavior(state: Enum.MouseBehavior)
	local old = CurrentMouseBehavior
	CurrentMouseBehavior = state
	MouseBehaviorPriorToOverride = old

	return old
end

function Views.StopMouseBehaviorOverride()
	if MouseBehaviorPriorToOverride ~= false then
		CurrentMouseBehavior = MouseBehaviorPriorToOverride
		MouseBehaviorPriorToOverride = false
	end
end

local lastThumbstickInput: UserInput.InputObject2?

local function SetLastThumbstickInput(input: UserInput.InputObject2, sank: boolean)
	lastThumbstickInput = input

	return false
end

local function HouseKeeping(_, dt)
	if CurrentMouseBehavior then
		UserInputService.MouseBehavior = CurrentMouseBehavior
	end
	
	if lastThumbstickInput then
		OnThumbstickMoved(lastThumbstickInput, dt)
	end
end

function Views.IsFirstPerson()
	return CurrentZoom < 0.00001
end

local alignment
function Views.ToggleLockMouse()
	InputUnlocksMouse = not InputUnlocksMouse
	
	if InputUnlocksMouse then
		-- alignment = CharacterController.PushLookAlignment(Enums.LookAlignment.CharacterFollowsMouseHit)
		Views.OverrideMouseBehavior(Enum.MouseBehavior.Default)
	else
		-- CharacterController.RemoveLookAlignment(alignment)
		Views.StopMouseBehaviorOverride()
	end
end

local function do_zoom_effects()
	local char = game.Players.LocalPlayer.Character
	local function get_armor(name)
		local armors = char:FindFirstChild("Armors")
		
		if armors then
			return armors:FindFirstChild(name)
		end
		
		return nil
	end

	local function set_model_trans(model, trans)
		if model then
			for i,v in model:GetChildren() do
				if v:IsA("BasePart") then
					v.Transparency = trans
				end
			end
		end
	end

	if CurrentZoom == 0 then
		set_model_trans(get_armor("Head_A"), 1)
		set_model_trans(get_armor("UpperTorso_A"), 1)
		set_model_trans(get_armor("RightUpperArm_A"), 1)
		set_model_trans(get_armor("LeftUpperArm_A"), 1)
		char.Head.Transparency = 1
		
		if InputUnlocksMouse then
			Views.ToggleLockMouse()
		end
	else
		set_model_trans(get_armor("Head_A"), 0)
		set_model_trans(get_armor("UpperTorso_A"), 0)
		set_model_trans(get_armor("RightUpperArm_A"), 0)
		set_model_trans(get_armor("LeftUpperArm_A"), 0)
		char.Head.Transparency = 0
	end
end

function Views.__run(G)
	UserInput.Hook(Enum.UserInputType.MouseMovement, OnMouseMoved)
	UserInput.Hook(Enum.KeyCode.Thumbstick2, SetLastThumbstickInput)

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

	-- initialize over the shoulder as E
	TweenPlanarOffset(CalcXOffset_D(true))
	
	UserInput.Hook(Enum.KeyCode.DPadLeft,
		function(input)
			TweenPlanarOffset(CalcXOffset_A(true))
		end)
		
	UserInput.Hook(Enum.KeyCode.DPadRight,
		function(input)
			TweenPlanarOffset(CalcXOffset_D(true))
		end)
	
	UserInput.Handler(Enum.UserInputType.MouseWheel,
		function(input: UserInput.InputObject2, sank: boolean)
			if not CurrentView or (CurrentView.MinCameraZoom == false or CurrentView.MaxCameraZoom == false) then
				return false
			end
			
			if input.Position.Z > 0 then
				CurrentZoom -= ZOOM_INCRIMENT
			elseif input.Position.Z < 0 then
				CurrentZoom += ZOOM_INCRIMENT
			end

			CurrentZoom = math.clamp(CurrentZoom, CurrentView.MinCameraZoom, CurrentView.MaxCameraZoom)

			do_zoom_effects()

			return true
		end)
	
	
	UserInput.Hook(Enum.KeyCode.ButtonR3,
		function(input)
			if Views.CameraMode ~= Enums.CameraMode.ThirdPerson then
				return
			end
			
			CurrentZoom = (CurrentZoom + ZOOM_INCRIMENT) % (MAX_ZOOM + ZOOM_INCRIMENT)
			CurrentZoom = math.clamp(CurrentZoom, MIN_ZOOM, MAX_ZOOM)

			do_zoom_effects()
		end)

	-- TODO @BlockBuster implement bindings?
	-- UserInput.Handler("UnlockMouseBinding", Views.ToggleLockMouse)
	
	local lastAppliedScale = 1
	local processThisScale = true
	
	UserInputService.TouchPinch:Connect(function(positions, scale: number, velocity: number, state, processed: boolean)
		if Views.CameraMode ~= Enums.CameraMode.ThirdPerson then
			return
		end
		
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

			do_zoom_effects()
		end
	end)

	UserInput.Handler(Enum.KeyCode.LeftControl, function(input, handled)
		if handled then
			return false
		end

		Views.ToggleLockMouse()

		return true
	end)
	
	RunService:BindToRenderStep("CameraAdd", Enum.RenderPriority.Camera.Value + 1, UpdateCamera)
	RunService.Stepped:Connect(HouseKeeping)

	local function StartInitView()
		Views.Start(Enums.CameraMode.ThirdPerson, LocalPlayer.Character.PrimaryPart, 0)
	end

	if LocalPlayer.Character then
		StartInitView()
	else
		LocalPlayer.CharacterAdded:Once(StartInitView)
	end
end

function Views.__build_signals(G, B)
--[[ 	B:GetTransmitter("RequestToSpawnTransmitter", function(E)
		E:ClientConnection(function(did_spawn)
			if did_spawn then
				do_zoom_effects()
			end
		end)
	end)

	B:GetTransmitter("DespawnedTransmitter", function(E)
		E:ClientConnection(function(transfer)
			if Views.IsFirstPerson() then
				CurrentZoom = MIN_ZOOM + ZOOM_INCRIMENT
			end
		end)
	end) ]]
end

return Views

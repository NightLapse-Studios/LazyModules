local Players = game:GetService("Players")

local Controllers
local Globals
local Math
local Vectors
local View

local FRAME_TIME = 0.016666667
local max_rotation_degrees = math.rad(100) -- vertical look up angle
local percent_lateral_torso = 0.25
local percent_vertical_torso = 0.65

local JUMP_COOLDOWN = 1
local AIMING = false
local ABOUT_TO_AIM = false

local Camera = workspace.CurrentCamera

local CharacterController = {}
CharacterController.__index = CharacterController

local function ApplyLookDirection(plr, horz_angle, vert_angle, is_aim, dt)
	local char = plr.Character

	if not char then
		return
	end

	-- These won't always be here with dismemberment
	local LeftUpperArm = char:FindFirstChild("LeftUpperArm")
	local RightUpperArm = char:FindFirstChild("RightUpperArm")

	local Waist = char.UpperTorso:FindFirstChild("Waist")
	Waist = Waist and Waist.Transform
	local Neck = char.Head:FindFirstChild("Neck")
	Neck = Neck and Neck.Transform
	local LeftShoulder = LeftUpperArm and LeftUpperArm:FindFirstChild("LeftShoulder")
	LeftShoulder = LeftShoulder and LeftShoulder.Transform
	local RightShoulder = RightUpperArm and RightUpperArm:FindFirstChild("RightShoulder")
	RightShoulder = RightShoulder and RightShoulder.Transform

	local stats = Globals[plr].PlayerStats

	local cur_torso_ang = stats:GetStatValue("cur_torso_ang")
	local cur_char_pitch = stats:GetStatValue("cur_char_pitch")
	local cur_head_ang = stats:GetStatValue("cur_head_ang")

	if is_aim then
		cur_head_ang = Math.LerpAngle(cur_head_ang, 0, 0.11 * (dt / FRAME_TIME))

		if Neck then
			Neck = CFrame.Angles(0, cur_head_ang, 0) * Neck
		end

		cur_torso_ang = Math.LerpAngle(cur_torso_ang, horz_angle, 0.21 * (dt / FRAME_TIME))

		if Waist then
			Waist = CFrame.Angles(0, cur_torso_ang, 0) * Waist
		end

		cur_char_pitch = Math.LerpNum(cur_char_pitch, vert_angle, 0.21 * (dt / FRAME_TIME))

		if Waist then
			Waist = CFrame.Angles(cur_char_pitch * percent_vertical_torso, 0, 0) * Waist
		end

		local absolute_angle = CFrame.fromAxisAngle((Waist:Inverse()).RightVector, cur_char_pitch * (1 - percent_vertical_torso))

		if Neck then
			Neck = absolute_angle * Neck
		end
		if LeftShoulder then
			LeftShoulder = absolute_angle * LeftShoulder
		end
		if RightShoulder then
			RightShoulder = absolute_angle * RightShoulder
		end
	else
		cur_head_ang = Math.LerpAngle(cur_head_ang, horz_angle * (1 - percent_lateral_torso), 0.11 * (dt / FRAME_TIME))
		cur_torso_ang = Math.LerpAngle(cur_torso_ang, horz_angle * percent_lateral_torso, 0.11 * (dt / FRAME_TIME))

		if Waist then
			Waist = CFrame.Angles(0, cur_torso_ang, 0) * Waist
		end
		if Neck then
			Neck = CFrame.Angles(0, cur_head_ang, 0) * Neck
		end

		cur_char_pitch = Math.LerpNum(cur_char_pitch, vert_angle, 0.11 * (dt / FRAME_TIME))

		if Waist then
			Waist = CFrame.Angles(cur_char_pitch * percent_vertical_torso, 0, 0) * Waist
		end

		local absolute_angle = CFrame.fromAxisAngle((Waist:Inverse()).RightVector, cur_char_pitch * (1 - percent_vertical_torso))

		if Neck then
			Neck = absolute_angle * Neck
		end
		if LeftShoulder then
			LeftShoulder = absolute_angle * LeftShoulder
		end
		if RightShoulder then
			RightShoulder = absolute_angle * RightShoulder
		end
	end

	if Waist then
		char.UpperTorso.Waist.Transform = Waist
	end
	if Neck then
		char.Head.Neck.Transform = Neck
	end
	if LeftUpperArm and LeftShoulder then
		LeftUpperArm.LeftShoulder.Transform = LeftShoulder
	end
	if RightUpperArm and RightShoulder then
		RightUpperArm.RightShoulder.Transform = RightShoulder
	end

	stats:ChangeStat("cur_torso_ang", cur_torso_ang, "set")
	stats:ChangeStat("cur_char_pitch", cur_char_pitch, "set")
	stats:ChangeStat("cur_head_ang", cur_head_ang, "set")
end

local function GetLookDirection(plr, cam_look, pos, aim_look)
	local char = plr.Character

	if not char then
		return
	end

	local stats = Globals[plr].PlayerStats

	local cur_char_pitch = stats:GetStatValue("cur_char_pitch")

	local cf = char.PrimaryPart.CFrame

	local horz_angle, vert_angle = 0, 0

	if pos then
		local target_look = CFrame.new(Vector3.new(cf.X, cf.Y + 1, cf.Z), pos).LookVector

		local offset_ang = math.atan2(-aim_look.X, -aim_look.Z)
		local target_ang = math.atan2(-target_look.X, -target_look.Z)

		-- Face the way we are looking, laterally
		local angle_between = Math.ShortestAngle(target_ang, offset_ang)
		angle_between = math.clamp(angle_between, -math.rad(80), math.rad(80))

		-- Face the way we are looking, vertically
		local pitch = cur_char_pitch + Math.ShortestAngle(math.asin(target_look.Y), math.asin(aim_look.Y))
		pitch = math.clamp(pitch, -math.rad(80), math.rad(80))

		horz_angle = angle_between
		vert_angle = pitch
	else
		-- Face the way we are looking, laterally
		local cam_ang = math.atan2(-cam_look.X, -cam_look.Z)
		local char_look = cf.LookVector
		local char_ang = math.atan2(-char_look.X, -char_look.Z)

		local angle_between = Math.ShortestAngle(cam_ang, char_ang)
		angle_between = math.clamp(angle_between, -max_rotation_degrees, max_rotation_degrees)

		-- Face the way we are looking, vertically
		local cam_pitch = math.asin(cam_look.Y)

		horz_angle = angle_between
		vert_angle = cam_pitch
	end

	return horz_angle, vert_angle
end

function CharacterController:__init(G)
	Globals = G
	Controllers = G.Load("Controllers")
	Math = G.Load("Math")
	Vectors = G.Load("Vectors")
	View = G.Load("View")
	local EffectUtil = G.Load("EffectUtil")
	local Config = G.Load("BUILDCONFIG")

	setmetatable(CharacterController, Controllers.ControllerObject)

	Controllers.register("Character")
		:Create(function(self)
			self.Humanoid = self.Model.Humanoid
			self.LastJump = 0

			setmetatable(self, CharacterController)
		end)
		:SetMovementUpdate(function(self, direction, dt)
			self.Humanoid.AutoRotate = false

			Players.LocalPlayer:Move(direction, true)

			local char = self.Model

			local char_look = char.PrimaryPart.CFrame.LookVector
			local char_ang = math.atan2(-char_look.X, -char_look.Z)

			local cam_look = Camera.CFrame.LookVector
			local cam_ang = math.atan2(-cam_look.X, -cam_look.Z)

			local DesiredCharAng

			if direction.Magnitude > 0 or AIMING or ABOUT_TO_AIM then
				DesiredCharAng = cam_ang
			else
				DesiredCharAng = char_ang
			end

			local new_ang = Math.LerpAngle(char_ang, DesiredCharAng, 0.11 * (dt / FRAME_TIME))

			local new_cf = CFrame.new(char.PrimaryPart.Position) * CFrame.Angles(0, new_ang, 0)
			char.PrimaryPart.CFrame = new_cf

			local Waist = char.UpperTorso:FindFirstChild("Waist")
			local turn_rate = Math.ShortestAngle(char_ang, DesiredCharAng)

			-- Use our turning velocity as a way to rotate the torso into the turn
			if Waist then
				Waist.Transform = CFrame.Angles(0, 0, -turn_rate / 5.2) * Waist.Transform
			end
		end)
		:SetJumpCallback(function(self)
			if tick() - self.LastJump > JUMP_COOLDOWN and not self.Humanoid.Jump then
				self.LastJump = tick()
				self.Humanoid.Jump = true
			end
		end)
		:SetSprintCallback(function(self, down)
			if down then
				self.WalkSpeedTicket = EffectUtil.TicketWalkSpeed(1 + Config.SprintSpeed, "Sprint")
				self.FOVTween = View.TweenFOV(13, 0.5, self.FOVTween)
			elseif self.WalkSpeedTicket then
				EffectUtil.RemoveWalkSpeed(self.WalkSpeedTicket)
				self.FOVTween = View.SmoothResetFOV(self.FOVTween)
			end
		end)
		:SetDisableFunc(function(self)
			if self.WalkSpeedTicket then
				EffectUtil.RemoveWalkSpeed(self.WalkSpeedTicket)
				self.FOVTween = View.SmoothResetFOV(self.FOVTween)
			end
		end)
		:SetLookUpdate(function(self, dt, recieve_plr, ...)
			if not recieve_plr then
				local pos
				local aim_look

				local is_aiming = AIMING and true or false

				local cam_look = Camera.CFrame.LookVector
				local char_cf = self.Model.PrimaryPart.CFrame

				if is_aiming then
					if AIMING.GetLookAt then
						pos = AIMING.GetLookAt()
					else
						pos = Globals.RaycastResultNPUnCapped and Globals.RaycastResultNPUnCapped.Position or Camera.CFrame.Position + cam_look * 2000
					end

					if Vectors.IsPosBehindCF(char_cf, pos) then
						pos = Camera.CFrame.Position + cam_look * 2000
					end

					aim_look = AIMING.Effector.WorldCFrame.LookVector
				end

				if ABOUT_TO_AIM and ABOUT_TO_AIM.GetLookAt then
					cam_look = CFrame.new(char_cf.Position, ABOUT_TO_AIM.GetLookAt()).LookVector
				end

				local horz_angle, vert_angle = GetLookDirection(Players.LocalPlayer, cam_look, pos, aim_look)
				ApplyLookDirection(Players.LocalPlayer, horz_angle, vert_angle, is_aiming, dt)

				return horz_angle, vert_angle, is_aiming
			else
				local horz_angle, vert_angle, is_aiming = table.unpack({...})
				ApplyLookDirection(recieve_plr, horz_angle, vert_angle, is_aiming, dt)

				return nil
			end
		end)
		:SetShouldAcceptLookUpdate(function(plr, args)
			return type(args[1]) == "number" and type(args[2]) == "number" and type(args[3]) == "boolean"
		end)
end

local function update_look_alignment(new)
	if not new then
		AIMING = false
		ABOUT_TO_AIM = false
	elseif typeof(new.Effector) == "boolean" then
		AIMING = false
		ABOUT_TO_AIM = new
	elseif typeof(new.Effector) == "Instance" then
		AIMING = new
		ABOUT_TO_AIM = false
	end
end

local ForceLookStack = _G.Game.Maskables.Stack()
	:OnTopValueChanged(update_look_alignment)
	:FINISH()

local function new_look_alignment(obj: Attachment?, getLookAt)
	local t = {
		Effector = obj or false,
		GetLookAt = getLookAt,
	}

	ForceLookStack:set(t)

	return t
end

function CharacterController.PushAimAlignment(effector: Attachment, getLookAt)
	local alignment = new_look_alignment(effector, getLookAt)

	return alignment
end

function CharacterController.PushLookAlignment(getLookAt)
	local alignment = new_look_alignment(nil, getLookAt)

	return alignment
end

function CharacterController.RemoveLookAlignment(alignment)
	if not alignment then
		return
	end

	assert(typeof(alignment) == "table")

	ForceLookStack:remove(alignment)
end

return CharacterController
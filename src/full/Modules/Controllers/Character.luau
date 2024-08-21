--!strict

local Players = game:GetService("Players")

local LMT = require(game.ReplicatedFirst.Lib.LMTypes)
local Game: LMT.LMGame = _G.Game

local Controllers = require(script.Parent.Controller)
local Math = require(game.ReplicatedFirst.Modules.Math)
local Vectors = require(game.ReplicatedFirst.Modules.Vectors)
local Views = if Game.CONTEXT == "CLIENT" then require(game.StarterPlayer.StarterPlayerScripts.Views) else nil
-- local FootSteps = G.Load("FootSteps")
local UserInput = if Game.CONTEXT == "CLIENT" then require(game.ReplicatedFirst.Lib.UserInput) else nil
local EffectUtil = if Game.CONTEXT == "CLIENT" then require(game.StarterPlayer.StarterPlayerScripts.EffectUtil) else nil
local FootSteps = if Game.CONTEXT == "CLIENT" then require(game.StarterPlayer.StarterPlayerScripts.FootSteps) else nil
local Config = require(game.ReplicatedFirst.Config)
local Enums = require(game.ReplicatedFirst.Lib.Enums)
local PlrObjs = require(game.ReplicatedFirst.Modules.Players).Objects

local max_rotation_degrees = math.rad(100) -- vertical look up angle
local percent_lateral_torso = 0.25
local percent_vertical_torso = 0.35

local FRAME_TIME = 0.016666667
local WATER_SLOW_DOWN = 0.6
local JUMP_COOLDOWN = 0.7

local LocalAlignment = false
local Camera = workspace.CurrentCamera

local CharacterController = {}
CharacterController.__index = CharacterController

local function ApplyLookDirection(plr: Player, horz_angle: number, vert_angle: number, alignment_type: Enums.LookAlignment, arms_alpha: number, dt: number)
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
	local LeftShoulder = LeftUpperArm and LeftUpperArm:FindFirstChild("LeftShoulder") :: Motor6D?
	local LeftShoulderCF = LeftShoulder and LeftShoulder.Transform
	local RightShoulder = RightUpperArm and RightUpperArm:FindFirstChild("RightShoulder") :: Motor6D?
	local RightShoulderCF = RightShoulder and RightShoulder.Transform

	local stats = PlrObjs[plr].Stats

	local cur_torso_ang = stats:GetStat("cur_torso_ang")
	local cur_char_pitch = stats:GetStat("cur_char_pitch")
	local cur_head_ang = stats:GetStat("cur_head_ang")

	if alignment_type == Enums.LookAlignment.AimFollowsCamera or alignment_type == Enums.LookAlignment.AimFollowsMouseHit then
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
		if LeftShoulderCF then
			LeftShoulderCF = absolute_angle * LeftShoulderCF
		end
		if RightShoulderCF then
			RightShoulderCF = absolute_angle * RightShoulderCF
		end
	elseif alignment_type == Enums.LookAlignment.AbsolutelyNone then
		-- Yep, do absolutely nothing
	else
		cur_head_ang = Math.LerpAngle(cur_head_ang, horz_angle * (1 - percent_lateral_torso), 0.11 * (dt / FRAME_TIME))
		cur_torso_ang = Math.LerpAngle(cur_torso_ang, horz_angle * percent_lateral_torso, 0.11 * (dt / FRAME_TIME))

		if Waist then
			Waist = CFrame.Angles(0, cur_torso_ang, 0) * Waist
		end
		if Neck then
			Neck = CFrame.Angles(0, cur_head_ang, 0) * Neck
		end

		cur_char_pitch = Math.LerpNum(cur_char_pitch, vert_angle, 0.21 * (dt / FRAME_TIME))

		if Waist then
			Waist = CFrame.Angles(cur_char_pitch * percent_vertical_torso, 0, 0) * Waist
		end

		local absolute_angle = CFrame.fromAxisAngle((Waist:Inverse()).RightVector, cur_char_pitch * (1 - percent_vertical_torso))
		local arms_angle = CFrame.fromAxisAngle((Waist:Inverse()).RightVector, cur_char_pitch * arms_alpha * (1 - percent_vertical_torso))

		if Neck then
			Neck = absolute_angle * Neck
		end
		if LeftShoulderCF then
			LeftShoulderCF = arms_angle * LeftShoulderCF
		end
		if RightShoulderCF then
			RightShoulderCF = arms_angle * RightShoulderCF
		end
	end

	if Waist then
		char.UpperTorso.Waist.Transform = Waist
	end
	if Neck then
		char.Head.Neck.Transform = Neck
	end
	if LeftShoulder and LeftShoulderCF then
		LeftShoulder.Transform = LeftShoulderCF
	end
	if RightShoulder and RightShoulderCF then
		RightShoulder.Transform = RightShoulderCF
	end

	stats:SetStat("cur_torso_ang", cur_torso_ang)
	stats:SetStat("cur_char_pitch", cur_char_pitch)
	stats:SetStat("cur_head_ang", cur_head_ang)
end

local function GetLookDirection(plr: Player, cam_look: Vector3, target_pos: Vector3, aim_look: Vector3)
	local char = plr.Character

	if not char then
		return nil, nil
	end

	local stats = PlrObjs[plr].Stats

	local cur_char_pitch = stats:GetStat("cur_char_pitch")

	local cf = char.PrimaryPart.CFrame

	local horz_angle, vert_angle = 0, 0

	if target_pos then
		local target_look = CFrame.new(Vector3.new(cf.X, cf.Y + 1, cf.Z), target_pos).LookVector

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

local function get_target_pos_from_mouse_hit()
	local char_cf = game.Players.LocalPlayer.Character:GetPivot()
	local target_pos = Game.RaycastResultNP and Game.RaycastResultNP.Position
	
	if (not target_pos) or Vectors.IsPosBehindCF(char_cf, target_pos) then
		local pos = UserInput.GetMousePos()
		local ray: Ray = Camera:ScreenPointToRay(pos.X, pos.Y)
		
		target_pos = ray.Origin + ray.Unit.Direction * 1000
	end

	return target_pos
end

function CharacterController:__init(G)
	local Humanoid: Humanoid
	local LastJump: number = 0
	local FOVTween
	local WalkSpeedTicket
	local WaterSlowDownTicket

	local Controller: Controllers.Controller = {
		Name = "Character",
		EnabledFunc = function(self)
			Humanoid = self.Model.Humanoid
		end,
		DisabledFunc = function(self)
			if WalkSpeedTicket then
				WalkSpeedTicket = EffectUtil.RemoveWalkSpeed(WalkSpeedTicket)
				FOVTween = Views.SmoothResetFOV(FOVTween)
			end
			
			WaterSlowDownTicket = EffectUtil.RemoveWalkSpeed(WaterSlowDownTicket)
		end,
		DestroyFunc = false,
		MovementUpdate = function(self, direction, dt)
			Humanoid.AutoRotate = false

			Players.LocalPlayer:Move(direction, true)

			local char = self.Model

			local char_look = char.PrimaryPart.CFrame.LookVector
			local char_ang = math.atan2(-char_look.X, -char_look.Z)

			local cam_look = Camera.CFrame.LookVector
			local cam_ang = math.atan2(-cam_look.X, -cam_look.Z)

			local DesiredCharAng

			if direction.Magnitude > 0 or LocalAlignment.Type == Enums.LookAlignment.CharacterFollowsCamera or LocalAlignment.Type == Enums.LookAlignment.AimFollowsCamera then
				DesiredCharAng = cam_ang
			elseif LocalAlignment.Type == Enums.LookAlignment.AimFollowsMouseHit then
				local target_pos = get_target_pos_from_mouse_hit()
				local delta = target_pos - LocalAlignment.Effector.WorldPosition
				DesiredCharAng = math.atan2(-delta.X, -delta.Z)
			else
				DesiredCharAng = char_ang
			end

			local new_ang = Math.LerpAngle(char_ang, DesiredCharAng, 0.25 * (dt / FRAME_TIME))

			local new_cf = CFrame.new(char.PrimaryPart.Position) * CFrame.Angles(0, new_ang, 0)
			char.PrimaryPart.CFrame = new_cf

			local Waist = char.UpperTorso:FindFirstChild("Waist")
			local turn_rate = Math.ShortestAngle(char_ang, DesiredCharAng)

			-- Use our turning velocity as a way to rotate the torso into the turn
			if Waist then
				Waist.Transform = CFrame.Angles(0, 0, -turn_rate / 5.2) * Waist.Transform
			end
			
			-- Slow down in water
			local stepper = FootSteps.GetByRootPart(self.Model.PrimaryPart)
			if stepper and stepper:IsInWater() then
				WaterSlowDownTicket = EffectUtil.TicketWalkSpeed(WATER_SLOW_DOWN, "WaterSlowDown")
			else
				WaterSlowDownTicket = EffectUtil.RemoveWalkSpeed(WaterSlowDownTicket)
			end
		end,
		JumpCallback = function(self)
			if tick() - LastJump > JUMP_COOLDOWN and not Humanoid.Jump then
				LastJump = tick()
				
				local oldValue = Humanoid.JumpHeight
				Humanoid.Jump = true
				
				task.delay(0.1, function()
					Humanoid.JumpHeight = oldValue
				end)
			end
		end,
		SprintCallback = function(self, down)
			if down then
				WalkSpeedTicket = EffectUtil.TicketWalkSpeed(1 + Config.SprintSpeed, "Sprint")
				FOVTween = Views.TweenFOV(13, 0.25, FOVTween)
			elseif WalkSpeedTicket then
				WalkSpeedTicket = EffectUtil.RemoveWalkSpeed(WalkSpeedTicket)
				FOVTween = Views.SmoothResetFOV(FOVTween)
			end
		end,
		LocalLookUpdate = function(self, dt)
			-- Local player path
			local target_pos
			local aim_look
			local arms_alpha = LocalAlignment.ArmsAlpha
			local alignment_type = LocalAlignment.Type

			local cam_look = Camera.CFrame.LookVector
			local char_cf = self.Model.PrimaryPart.CFrame
			
			if alignment_type ~= Enums.LookAlignment.None then
				if alignment_type == Enums.LookAlignment.AimFollowsMouseHit then
					target_pos = get_target_pos_from_mouse_hit()
					aim_look = LocalAlignment.Effector.WorldCFrame.LookVector
				elseif alignment_type == Enums.LookAlignment.AimFollowsCamera then
					aim_look = CFrame.new(char_cf.Position, LocalAlignment.Effector.WorldPosition).LookVector
				elseif alignment_type == Enums.LookAlignment.CharacterFollowsMouseHit then
					target_pos = get_target_pos_from_mouse_hit()
					aim_look = self.Model.Head.CFrame.LookVector
				elseif alignment_type == Enums.LookAlignment.CharacterFollowsCallback then
					target_pos = LocalAlignment.Effector()
					aim_look = self.Model.Head.CFrame.LookVector
				end
			end

			local horz_angle, vert_angle = GetLookDirection(Players.LocalPlayer, cam_look, target_pos, aim_look)
			ApplyLookDirection(Players.LocalPlayer, horz_angle, vert_angle, alignment_type, arms_alpha, dt)

			if arms_alpha == 1.0 then
				-- Save some networking
				arms_alpha = nil
			end

			return horz_angle, vert_angle, alignment_type, arms_alpha
		end,
		RemoteLookUpdate = function(dt, plr, horz_angle, vert_angle, alignment_type, arms_alpha)
			arms_alpha = arms_alpha or 1.0

			ApplyLookDirection(plr, horz_angle, vert_angle, alignment_type, arms_alpha, dt)

			return nil
		end,
		ServerLookUpdate = false,
		ShouldAcceptLookUpdate = function(plr, args)
			return type(args[1]) == "number" and type(args[2]) == "number" and type(args[3]) == "number" and (if args[4] then type(args[4]) == "number" else true)
		end,
		PreserveLookStateFor = { },
	}

	Controllers.Register("Character", Controller)
end

local function update_look_alignment(new)
	if not new then
		LocalAlignment = false
	else
		LocalAlignment = new
	end
end

local ForceLookStack = _G.Game.Maskables.Stack()
	:OnTopValueChanged(update_look_alignment)
	:FINISH()

local function new_look_alignment(type: Enums.LookAlignment, obj: Attachment?, arms_rot_alpha: number?)
	local t = {
		Type = type,
		Effector = obj or false,
		ArmsAlpha = arms_rot_alpha or 1.0
	}

	ForceLookStack:set(t)

	return t
end

function CharacterController.PushLookAlignment(type: Enums.LookAlignment, effector: Attachment?, arms_rot_alpha: number?)
	if type == Enums.LookAlignment.CharacterFollowsCamera then
		assert(not effector)
	elseif type == Enums.LookAlignment.CharacterFollowsMouseHit then
	 	assert(not effector)
	elseif type == Enums.LookAlignment.AimFollowsCamera then
		assert(effector)
	elseif type == Enums.LookAlignment.AimFollowsMouseHit then
		assert(effector)
	elseif type == Enums.LookAlignment.CharacterFollowsCallback then
		assert(effector)
	end

	local alignment = new_look_alignment(type, effector, arms_rot_alpha)

	return alignment
end

CharacterController.PushLookAlignment(Enums.LookAlignment.None, nil, 1.0)

function CharacterController.RemoveLookAlignment(alignment)
	assert(typeof(alignment) == "table")

	ForceLookStack:remove(alignment)
end

return CharacterController

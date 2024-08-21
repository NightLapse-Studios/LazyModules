--[[
	Responsible for CHARACTER animations
]]

local RunService = game:GetService("RunService")
local Players = game.Players
local LocalPlayer = Players.LocalPlayer
local Humanoid

-- in studs. Higher values equates to slower animations
local WALK_CYCLE_LENGTH = 6.1
local CLIMB_CYCLE_LENGTH = 6

local DefaultAnims

local LastTrack: AnimationTrack = nil
local CurrentAnimation = nil
local CurrentSet = {}

local Animations = {
	Idle = true,
	Sprint = true,
	Walk = true,
	Jump = true,
	Climb = true,
	Fall = true,
}
local Emotes = {
	Dance = true,
	Dance2 = true,
	Dance3 = true,
	Wave = true,
	Cheer = true,
	Point = true,
	Laugh = true,
}

local Assets = require(game.ReplicatedFirst.Modules.Assets)
local Animation = require(game.ReplicatedFirst.Modules.Animation)

local Animate = {}

function Animate.__init(G)
	Animate.SetDefault()
	Animate.ResetToDefault()
end

local function play(name, force_update)
	if not name then
		return
	end

	local lastAnimation = CurrentAnimation

	if lastAnimation == name and not force_update then
		return
	end

	CurrentAnimation = name

	if LocalPlayer.Character.PrimaryPart.Anchored and name ~= "Idle" then
		return
	end

	if LastTrack and lastAnimation ~= "Jump" then
		LastTrack:Stop(0.25)
	end

	local id = CurrentSet[name]
	if id then
		LastTrack = Animation.Animate(LocalPlayer.Character, id, nil, 1)
	end
end

function Animate.SetAnimations(dict)
	local function set(name)
		local id = dict[name]

		if id ~= nil then
			CurrentSet[name] = id
		end
	end

	for name, _ in Animations do
		set(name)
	end
	for name, _ in Emotes do
		set(name)
	end

	play(CurrentAnimation, true)
end

function Animate.SetDefault(dict)
	DefaultAnims = dict or Assets.Animations.Default
end

function Animate.ResetToDefault()
	Animate.SetAnimations(DefaultAnims)
end


local function canEmote()
	local moveDir = Humanoid.MoveDirection
	local state = Humanoid:GetState()

	if moveDir ~= Vector3.zero then
		return false
	end

	if state ~= Enum.HumanoidStateType.Running then
		return false
	end

	return true
end

local function running(speed)
	if speed > 17 then
		play("Sprint")
	elseif speed > 0.01 then
		play("Walk")
	else
		play("Idle")
	end
end

function Animate.__run()
	Humanoid = LocalPlayer.Character.Humanoid

	Humanoid.Climbing:Connect(function()
		play("Climb")
	end)
	Humanoid.FreeFalling:Connect(function()
		play("Fall")
	end)
	Humanoid.Jumping:Connect(function()
		play("Jump")
	end)
	Humanoid.Running:Connect(function(speed)
		running(speed)
	end)

	LocalPlayer.Character.PrimaryPart:GetPropertyChangedSignal("Anchored"):Connect(function()
		if LocalPlayer.Character.PrimaryPart.Anchored then
			running(0)
		else
			play(CurrentAnimation, true)
		end
	end)

	LocalPlayer.Chatted:Connect(function(msg)
		if not canEmote() then
			return
		end

		msg = string.lower(msg)
		if string.sub(msg, 1, 3) == "/e " then
			local emote = string.sub(msg, 4, -1)
			for e, _ in Emotes do
				if string.lower(e) == emote then
					play(e)

					break
				end
			end
		end
	end)

	local YCANCEL = Vector3.new(1,0,1)

	RunService.RenderStepped:Connect(function()
		if not LocalPlayer.Character then
			return
		end

		if LastTrack and LastTrack.Length and LastTrack.Length > 0 then
			if (CurrentAnimation == "Walk" or CurrentAnimation == "Sprint") then
				local current_speed = (LocalPlayer.Character.PrimaryPart.AssemblyLinearVelocity * YCANCEL).Magnitude
				local cycle_speed = WALK_CYCLE_LENGTH / LastTrack.Length
				LastTrack:AdjustSpeed(current_speed / cycle_speed)
			elseif CurrentAnimation == "Climb" then
				local current_speed = LocalPlayer.Character.PrimaryPart.AssemblyLinearVelocity.Y
				local cycle_speed = CLIMB_CYCLE_LENGTH / LastTrack.Length
				LastTrack:AdjustSpeed(current_speed / cycle_speed)
			end
		end

	end)

	running(0)
end

return Animate
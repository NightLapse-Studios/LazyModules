--[[
	Interpolation.lua

	Author: Gavin Oppegard
	Date: 6/23/2022

	Interpolates literals for use per a callback
]]

local TweenService = game:GetService("TweenService")

local Interpolation = { }
local mt_Interpolation = { __index = Interpolation }

local ToInterpolate = { }

local function lerp(a, b, t)
	return a * (1 - t) + b * t
end

function Interpolation.TweenServiceCallback(start, finish, t, easingStyle, easingDirection, callBack, postAnim)
	local StartTime = tick()

	local newTween = {
		CallBack = callBack,
		Start = start,
		StartTime = StartTime,
		Time = t,
		Finish = finish,
		Value = 0,
		EasingStyle = easingStyle,
		EasingDirection = easingDirection,
		Enabled = true,
		PostAnim = postAnim or false,
		idx = -1
	}

	table.insert(ToInterpolate, newTween)
	newTween.idx = #ToInterpolate
	setmetatable(newTween, mt_Interpolation)

	return newTween
end

function Interpolation:Cancel()
	table.remove(ToInterpolate, self.idx)
end

function Interpolation.Update(postAnim)
	postAnim = postAnim or false

	for i = #ToInterpolate, 1, -1 do
		local tween = ToInterpolate[i]
		if tween.Enabled then

			if postAnim ~= tween.PostAnim then
				continue
			end

			local curTime = tick()

			local newValue = math.clamp((curTime - tween.StartTime) / tween.Time, -1, 1)
			tween.Value = newValue

			local alpha = TweenService:GetValue(newValue, tween.EasingStyle, tween.EasingDirection)

			if newValue >= 1 or newValue <= -1 then
				tween.Enabled = false
			end

			local completed = not tween.Enabled

			tween.CallBack(lerp(tween.Start, tween.Finish, alpha), tween, completed)
		else
			table.remove(ToInterpolate, i)
		end
	end
end

return Interpolation
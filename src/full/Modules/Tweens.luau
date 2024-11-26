--!strict

--[[
	A tween wrapper
	very nice
	very fun :^)
	uses builder pattern
]]

local TweenService = game:GetService("TweenService")

local TweenWrapper = { }
TweenWrapper.__index = TweenWrapper

function TweenWrapper.new( opt_default_instance: Instance?, opt_model_container: Model? )
	if opt_model_container and not opt_default_instance then
		error("You must provide an instance if you pass a model container")
	end

	local t = {
		start_tick = 0,
		length = 1.0,
		-- Prefered usage us to pass this via :Run
		-- but for wrappers which create instances owned entirely by the tween, this makes a lot more sense
		-- E.G. Effects.TweenedDisc
		Instance = opt_default_instance or false,
		-- This model container thing exists because model's sizes cannot be tweened, but we want the caller to still
		-- be able to use the pivot features of models
		Model = opt_model_container or false,

		TweenInfo = false,
		Tween = false,
		Targets = false,

		EasingStyle = Enum.EasingStyle.Linear,
		EasingDirection = Enum.EasingDirection.InOut,
		RepeatCount = 0,
		Reverses = false,
		Delay = 0,
		Cleanup = false,
		-- Make sure you're not storing references if you use this
		__CleanupAfter = 0
	}

	setmetatable(t, TweenWrapper)

	return t
end

function TweenWrapper:SetEasingStyle(style)
	self.EasingStyle = style
	return self
end
function TweenWrapper:SetEasingDirection(dir)
	self.EasingDirection = dir
	return self
end
function TweenWrapper:SetRepeatCount(count)
	self.RepeatCount = count
	return self
end
function TweenWrapper:SetReverses(bool)
	self.Reverses = bool
	return self
end
function TweenWrapper:SetLength(dur)
	self.length = dur
	return self
end
function TweenWrapper:SetDelay(dur: number)
	self.Delay = dur
	return self
end
function TweenWrapper:SetTargets(t)
	self.Targets = t
	return self
end
function TweenWrapper:CleanupAfter(dur)
	self.__CleanupAfter = dur
	return self
end
function TweenWrapper:SetCleanup(func)
	self.Cleanup = func
	return self
end

local function auto_slider(self, i, v, menu_identifier)
	local min, max, inc
	if v < 0 then
		min = v * 10
		max = v/10
		inc = v/100
	elseif v == 0 then
		min = -5
		max = 5
		inc = 5/100
	else
		min = v/10
		max = v * 10
		inc = v/100
	end
	-- TODO @PumpkinRemoval
	-- self[i] = DebugMenu.RegisterOverrideSlider(i, v, min, max, inc, menu_identifier)
end

function TweenWrapper:Sliderify(menu_identifier, targets)
	if not game:GetService("RunService"):IsStudio() then
		return
	end

	menu_identifier = menu_identifier or "TweenWrapper " .. self.Instance.Name
	targets = targets or {}

	for i,v in self do
		if typeof(v) == "number" then
			if i == "start_tick" then continue end
			auto_slider(self, i, v, menu_identifier)
		end
	end

	for i,v in targets do
		if typeof(v) == "number" then
			auto_slider(self.Targets, i, v, menu_identifier)
		end
	end

	self.__Sliderified = true
	return self
end

local RunningTweenWrapper = { }
RunningTweenWrapper.__index = RunningTweenWrapper

function TweenWrapper:Run( instance: Instance, targets: {string: any}?, opt_model_container: Model?, make_targets_real: boolean? )
	-- Reminder: this check applies to NON-library-type use cases such as Effects.TweenedDisc()
	-- This is to say that this check will not apply on Effects.TweenedDisc()
	if not self.Instance then
		assert(typeof(instance) == "Instance")
	end
	
	if make_targets_real == nil and not self.Reverses then
		make_targets_real = true
	end

	-- Clonging the wrapper enables us to set custom funcs on a pre-built type prior to calling :Run
	-- E.G. if we have a cleanup func which needs an upvalue from the parent scope, we can set it and run the tween
	-- and then set it again and run the tween again prior to the first tween completing
	local t = table.clone(self)
	setmetatable(t, RunningTweenWrapper)

	if targets then
		t.Targets = targets
	end

	if t.__Sliderified then
		t.length = self.length:getValue()
		t.RepeatCount = self.RepeatCount:getValue()
		t.Delay = self.Delay:getValue()

		if self.Targets then
			for i,v in self.Targets do
				if typeof(v) ~= "table" then continue end
				local _v = pcall(function() return v:getValue() end)
				if _v then
					t.Targets[i] = _v
				end
			end
		end
	end

	if instance then
		t.Instance = instance
	end
	if opt_model_container then
		t.Model = opt_model_container
	end

	t.TweenInfo = TweenInfo.new(t.length, t.EasingStyle, t.EasingDirection, t.RepeatCount, t.Reverses, t.Delay)
	t.start_tick = tick()
	local tween = TweenService:Create(t.Instance, t.TweenInfo, t.Targets)
	t.Tween = tween

	-- We do a sneaky trick where we pass in the targets as an upvalue so that if something else re-runs a tween
	-- in a .Completed connection, it can still actualize the targets without worrying about the order of
	-- callback execution.
	local old_targets = t.Targets
	tween.Completed:Connect(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed and make_targets_real then
			for i,v in old_targets do
				t.Instance[i] = v
			end
		end

		task.spawn(function()
			if typeof(t.__CleanupAfter) == "number" and t.__CleanupAfter > 0 then
				task.wait(t.__CleanupAfter)
				t:Cleanup()
			elseif t.Cleanup then
				t:Cleanup()
			end
		end)
	end)

	tween:Play()

	return t
end

function RunningTweenWrapper:Cancel()
	self.start_tick = 0

	if not self.Tween then
		return
	end

	self.Tween:Cancel()

	self.Tween = false
end

function RunningTweenWrapper:Pause()
	if self.paused_on then
		return
	end

	self.paused_on = tick()

	self.Tween:Pause()
end

function RunningTweenWrapper:Resume()
	if not self.paused_on then
		return
	end

	local time_ran = self.paused_on - self.start_tick
	self.start_tick = tick() - time_ran
	self.paused_on = nil

	self.Tween:Play()
end

function RunningTweenWrapper:GetElapsedPortion()
	if self.start_tick == 0 then
		return 0
	end

	local t = self.paused_on or tick()

	return math.min(1, (t - self.start_tick) / self.length)
end

function RunningTweenWrapper:GetElapsedTime()
	if self.start_tick == 0 then
		return 0
	end

	local t = self.paused_on or tick()

	return t - self.start_tick
end

function RunningTweenWrapper:GetAlpha()
	local elapsed = self:GetElapsedPortion()
	local alpha = TweenService:GetValue(elapsed, self.EasingStyle, self.EasingDirection)
	return alpha
end

return TweenWrapper

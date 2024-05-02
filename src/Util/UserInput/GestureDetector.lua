--!strict

local mod = {
	IsReady = false,
	LastGesture = _G.Game.Enums.InputGestures.None
}

local UserInput
local Enums = require(game.ReplicatedFirst.Util.Enums)
local CircleBuffer = require(game.ReplicatedFirst.Util.CircleBuffer)

local SIG_SAMPLE_LEN = 32
local DETECTION_SAMPLES = 5
local MIN_GESTURE_MAG = 25 * ((_G.Game.ScreenSizeXRatio + _G.Game.ScreenSizeYRatio) / 2)

-- Used when ConsumeDelta isn't available
local Pos = Vector3.new(0, 0, 0)

local PI = math.pi
local OffsetRange = PI / 5

local function init_signal(sig)
	for i = 1, SIG_SAMPLE_LEN do
		sig.Buffer:push(0)
	end
end

local function NewSignal()
	local t = {
		Buffer = CircleBuffer.new(SIG_SAMPLE_LEN),
		
		FilteredSig = {
			Buffer = CircleBuffer.new(SIG_SAMPLE_LEN),
		}
	}

	init_signal(t)
	init_signal(t.FilteredSig)

	return t
end

local MagSig = NewSignal()
local AngleSig = NewSignal()

local function IsLeft(ang: number)
	return ang > (-PI / 2 - OffsetRange) and ang < (-PI / 2 + OffsetRange)
end
local function IsRight(ang: number)
	return ang > (PI / 2 - OffsetRange) and ang < (PI / 2 + OffsetRange)
end
local function IsUp(ang: number)
	return (ang <= 0 and ang > -OffsetRange) or (ang >= 0 and ang < OffsetRange)
end
local function IsDown(ang: number)
	return (ang <= PI and ang > (PI - OffsetRange)) or (ang >= -PI and ang < (-PI + OffsetRange))
end

local function get_dir(ang)
	if IsLeft(ang) then
		-- print("Left ", ang)
		return Enums.InputGestures.Left
	elseif IsRight(ang) then
		-- print("Right ", ang)
		return Enums.InputGestures.Right
	elseif IsUp(ang) then
		-- print("Up ", ang)
		return Enums.InputGestures.Up
	elseif IsDown(ang) then
		-- print("Down ", ang)
		return Enums.InputGestures.Down
	end

	return false
end

local LastDetectedGestureDir = 0
local function detect_gestures(mag_sig, angle_sig)
	local last_dir = false
	local last_mag = 0
	local total_mag = 0
	for i = 1, DETECTION_SAMPLES, 1 do
		local ang = angle_sig.Buffer:readFromFront(-i + 1)
		local dir = get_dir(ang)
		local mag = mag_sig.Buffer:readFromFront(-i + 1)

		if i > 1 and ((last_dir == false) or last_dir ~= dir or dir == LastDetectedGestureDir) then
			-- print("Dirs: ", ang, last_dir, dir)
			return false, 0
		end

		-- Make sure we're looking at accelerating motion
		-- Deceleration can give false detections in the opposite direction of the intended gesture
		-- It also lets us lower the MIN_GESTURE_MAG significantly (to about 1/3)
		if mag < last_mag and (mag - last_mag) > (mag / 10) then
			return false, 0
		end

		last_dir = dir
		total_mag += mag
	end

	if total_mag < MIN_GESTURE_MAG then
		-- print("Mag: ", total_mag)
		return false, 0
	end

	-- To prevent re-consumption, we'll just 0 the data we based this on
	for i = 1, DETECTION_SAMPLES, 1 do
		angle_sig.Buffer:writeFromFront(-i + 1, 0)
		mag_sig.Buffer:writeFromFront(-i + 1, 0)
	end

	-- Detected, let's ship an event to UserInput
	local input = UserInput.CustomInputObject(last_dir, Enums.AuxiliaryInputCodes.InputGestures.Any, Enum.UserInputState.Change, Enums.UserInputType.Gesture)
	UserInput.TakeCustomInput(input)

	mod.LastGesture = input.KeyCode

	LastDetectedGestureDir = last_dir

	return last_dir, total_mag
end

function mod:__init(G)
	UserInput = G:Get("UserInput")
end

local SMOOTHING_SAMPLE_CT = 6
local SampleConfig = { }
local alphabet = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z" }
for i = 1, SMOOTHING_SAMPLE_CT, 1 do
	if game:GetService("RunService"):IsStudio() then
		--[[ local binding = DebugMenu.RegisterOverrideSlider(alphabet[i] .. "_MUL", 0.25, 0, 1, 0.01, "Z Transform")
		table.insert(SampleConfig, binding) ]]
	end
end

local function apply_z_transform(sig, n: number)
	assert(sig.FilteredSig)

	for _ = n, 1, -1 do
		local l = SIG_SAMPLE_LEN

		local SmoothingMul = 0
		local Sum = 0
		for i = 1, SMOOTHING_SAMPLE_CT, 1 do
			local sample_mul = 0.25
			local o = i - 1
			local sample = sig.Buffer:readFromFront(l - o)
			SmoothingMul += sample_mul
			Sum += sample * sample_mul
		end

		local H = Sum / SmoothingMul
		sig.FilteredSig.Buffer:push(H)
	end
end

local function push_new_dt(dt: Vector3)
	local dt_vec2 = Vector2.new(dt.X, dt.Y)
	MagSig.Buffer:push(dt_vec2.Magnitude)
--[[ 	local ang = math.atan2(dt_vec2.Y, dt_vec2.X)
	print(dt_vec2.Y, dt_vec2.X, "\n" .. ang) ]]
	AngleSig.Buffer:push(math.atan2(dt_vec2.X, dt_vec2.Y))

	if MagSig.Buffer:getSize() < MagSig.Buffer.Length then
		return
	end

	apply_z_transform(MagSig, 1)
	apply_z_transform(AngleSig, 1)

	detect_gestures(MagSig.FilteredSig, AngleSig.FilteredSig)
end

local IsPaused = false
function mod.ConsumePosition(pos: Vector3)
	-- Desktop pathway
	if IsPaused then
		return
	end

	local dt = (pos - Pos)
	Pos = pos
	push_new_dt(dt)
end

function mod.ConsumeDelta(dt: Vector3)
	if IsPaused then
		return
	end

	push_new_dt(dt)
end

function mod:__run()
	mod.IsReady = true
end


function mod:__tests(G, T)
	T:Test("Turn coordinates into directions", function()
		T:WhileSituation("moving Right",
			T.Equal, get_dir(math.atan2(1, 0)), Enums.InputGestures.Right
		)
		T:WhileSituation("moving Left",
			T.Equal, get_dir(math.atan2(-1, 0)), Enums.InputGestures.Left
		)
		T:WhileSituation("moving Up",
			T.Equal, get_dir(math.atan2(0, 1)), Enums.InputGestures.Up
		)
		T:WhileSituation("moving Down",
			T.Equal, get_dir(math.atan2(0, -1)), Enums.InputGestures.Down
		)
	end)

	T:Test("Calculate angle of input", function()
		mod.ConsumeDelta(Vector3.new(0, 1, 0))
		mod.ConsumeDelta(Vector3.new(0, -1, 0))
		mod.ConsumeDelta(Vector3.new(1, 0, 0))
		mod.ConsumeDelta(Vector3.new(-1, 0, 0))

		local b = AngleSig.Buffer
		local a1, a2, a3, a4 = b:readFromFront(-3), b:readFromFront(-2), b:readFromFront(-1), b:readFromFront(0)
		T:WhileSituation("using ConsumeDelta",
			T.Equal, a1, math.atan2(0, 1),
			T.Equal, a2, math.atan2(0, -1),
			T.Equal, a3, math.atan2(1, 0),
			T.Equal, a4, math.atan2(-1, 0)
		)

		local p = Vector3.new(0,0,0)
		mod.ConsumePosition(p)
		p += Vector3.new(0, 1, 0)
		mod.ConsumePosition(p)
		p += Vector3.new(0, -1, 0)
		mod.ConsumePosition(p)
		p += Vector3.new(1, 0, 0)
		mod.ConsumePosition(p)
		p += Vector3.new(-1, 0, 0)
		mod.ConsumePosition(p)

		a1, a2, a3, a4 = b:readFromFront(-3), b:readFromFront(-2), b:readFromFront(-1), b:readFromFront(0)
		T:WhileSituation("using ConsumePosition",
			T.Equal, a1, math.atan2(0, 1),
			T.Equal, a2, math.atan2(0, -1),
			T.Equal, a3, math.atan2(1, 0),
			T.Equal, a4, math.atan2(-1, 0)
		)
	end)

	-- Clear the signal
	for _ = 1, DETECTION_SAMPLES, 1 do
		mod.ConsumeDelta(Vector3.new(0,0,0))
	end

	T:Test("Detect gestures", function()
		local mag_factor = -0.5
		for _ = 1, DETECTION_SAMPLES, 1 do
			mod.ConsumeDelta(Vector3.new(mag_factor * MIN_GESTURE_MAG, 0, 0))
		end

		local dir, mag = detect_gestures(MagSig, AngleSig)

		T:WhileSituation("Minimum number of samples are available",
			T.NotEqual, dir, false
		)
		
		T:WhileSituation("moving left", 
			T.Equal, dir, Enums.InputGestures.Left,
			T.FuzzyEqual(0.01), mag, math.abs(mag_factor * MIN_GESTURE_MAG * 5)
		)
	end)
end

return mod

local abs = math.abs
local ceil = math.ceil
local cos = math.cos
local floor = math.floor
local random = math.random
local sign = math.sign
local sin = math.sin
local sqrt = math.sqrt
local exp = math.exp
local clamp = math.clamp
local atan2 = math.atan2

local Math = {}

local PI = math.pi
local SQRT5 = sqrt(5)
local ONE_OVER_SQRT5 = 1 / SQRT5

local PI_2 = 2 * PI
local PI_3 = 3 * PI

Math.PI = PI
Math.G = 6.674e-11
Math.E = exp(1)
Math.PHI = (1 + SQRT5) * 0.5
Math.MPHI = (1 - SQRT5) * 0.5

function Math.Round(num, Custom)
	Custom = Custom or 1
	
	local mult = 1 / Custom
    return floor(num * mult + 0.5) / mult
end

function Math.Floor(num, Custom)
	Custom = Custom or 1
	
	local mult = 1 / Custom
    return floor(num * mult) / mult
end

function Math.ClampRadians(rad)
	clamp(rad, 0.0, PI_2)
end

function Math.ApplesToCrates(Apples, ApplesPerCrate)
	Apples /= ApplesPerCrate
	local rounded = ceil(Apples)
	return rounded
end

function Math.LerpNum(a, b, t)
	return a * (1 - t) + b * t
end

function Math.ShortestAngle(ang1, ang2)
	return ((((ang1 - ang2) % PI_2) + PI_3) % PI_2) - PI
end	

function Math.LerpAngle(start, finish, amount)
	local shortest_angle = ((((finish - start) % PI_2) + PI_3) % PI_2) - PI
	local final_angle = start + (shortest_angle * amount) % PI_2
	return final_angle
end

function Math.Porportion(OldMax, NewMax, number)
	return (number * NewMax) / OldMax
end

function Math.FlipNumber(num, min, max)
    return (max + min) - num;
end

function Math.AddFromZero(num, add)
	if num == 0 then
		return add
	else
		return num + (add * sign(num))
	end
end

function Math.Map(value, oldMin, oldMax, newMin, newMax)
    local oldSpan = oldMax - oldMin
    local newSpan = newMax - newMin

    local valueScaled = (value - oldMin) / (oldSpan)

    return newMin + (valueScaled * newSpan)
end

function Math.Percent(num, min, max)
	return (num - min) / (max - min)
end

function Math.randomNumber(min, max)
    return random() * (max - min) + min
end

function Math.NumberDistance(a, b)
	return abs(a - b)
end

function Math.GravityForce(mass1, mass2, distance, Const, RangeAffect, soft)
	return (Const * mass1 * mass2) / ((distance ^ RangeAffect) + (soft or 0))
end

function Math.Fibonacci(n)
	return (Math.PHI ^ n - Math.MPHI ^ n) * ONE_OVER_SQRT5
end

function Math.RemoveValueFromAverage(Value, Average, NumValues)
	return ((Average * NumValues) - Value) / (NumValues - 1)
end

function Math.AddValueToAverage(Value, Average, NumValues)
	return Average + ((Value - Average) / NumValues)
end


return Math
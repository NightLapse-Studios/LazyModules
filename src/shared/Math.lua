
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

local Config = _G.Game.Config

local ZEROVEC = Vector3.new()

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
	if Custom then num /= Custom end
	local rounded = floor(num + 0.5)
	return Custom and rounded * Custom or rounded
end

function Math.Floor(num, Custom)
	num /= Custom
	local rounded = floor(num)
	return Custom and rounded * Custom or rounded
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

function Math.IsPointInHoopSlice(x, y, radiusMin, radiusMax, angle1, angle2, cenX, cenY)
	cenX = cenX or 0
	cenY = cenY or 0
	
	x -= cenX
	y -= cenY
	
	angle1 %= PI_2
	angle2 %= PI_2
	
	local maxAngle = math.max(angle1, angle2)
	local minAngle = math.min(angle1, angle2)
	
	local angle = math.atan2(y, x)
	if angle > minAngle and angle < maxAngle then
		local mag = sqrt(x * x + y * y)
		if mag < radiusMax and mag > radiusMin then
			return true
		end
	end
end

function Math.FindCircleCircleIntersections(cx0, cy0, radius0, cx1, cy1, radius1)
	local dx = cx1 - cx0
	local dy = cy1 - cy0
	local dist = sqrt(dx * dx + dy * dy)
	local radii = radius0 + radius1

	if dist > radii then
		return nil
	elseif dist < abs(radius0 - radius1) then
		return nil
	elseif dist == 0 and radius0 == radius1 then
		return nil
	else
		local rad0sq = radius0 * radius0
		local a = (rad0sq - radius1 * radius1 + dist * dist) / (2 * dist)
		local h = sqrt(rad0sq - a * a)

		local dxdist, dydist = dx/dist, dy/dist

		local cx2 = cx0 + a * dxdist
		local cy2 = cy0 + a * dydist

		local xr, yr = h * dxdist, h * dydist

		if dist == radii then
			return (cx2 + yr), (cy2 - xr)
		else
			return (cx2 + yr), (cy2 - xr),  (cx2 - yr), (cy2 + xr)
		end
	end
end

function Math.CCWTangentPoint(target: Vector3, source: Vector3, radius: number)
	local tx, tz, sx, sz = target.X, target.Z, source.X, source.Z
	
	local dx = tx - sx
    local dy = tz - sz
    local D_squared = dx * dx + dy * dy
	local r_squared = radius * radius
	
    if D_squared < r_squared then
        return Vector3.new(sx-dx, Config.GlobalY, sz-dy), false
	end
	
    local L = sqrt(D_squared - r_squared);

    local x0, y0, x1, y1 = Math.FindCircleCircleIntersections(
        tx, tz, radius,
        sx, sz, L)

	return Vector3.new(x0, Config.GlobalY, y0), true
end

function Math.CWTangentPoint(target: Vector3, source: Vector3, radius: number)
	local tx, tz, sx, sz = target.X, target.Z, source.X, source.Z
	
	local dx = tx - sx
    local dy = tz - sz
    local D_squared = dx * dx + dy * dy
	local r_squared = radius * radius
	
    if D_squared < r_squared then
        return Vector3.new(sx-dx, Config.GlobalY, sz-dy), false
	end
	
    local L = sqrt(D_squared - r_squared);

    local x0, y0, x1, y1 = Math.FindCircleCircleIntersections(
        tx, tz, radius,
        sx, sz, L)

	return Vector3.new(x1 or x0, Config.GlobalY, y1 or y0), true
end

function Math.GetRotatedPoint(x,y , AnchorPoint, angle)
	-- theta is the angle of rotation

	-- translate point to origin
	local tempX = x - AnchorPoint.X;
	local tempY = y - AnchorPoint.Y;

	-- now apply rotation
	local c, s = cos(angle), sin(angle)
	
	local rotatedX = tempX * c - tempY * s
	local rotatedY = tempX * s + tempY * c

	-- translate back
	x = rotatedX + AnchorPoint.X;
	y = rotatedY + AnchorPoint.Y;

	return x, y
end

function Math.EvalNumberSequence(ns, time)
	-- If we are at 0 or 1, return the first or last value respectively
	if time <= 0 then return ns.Keypoints[1].Value end
	if time >= 1 then return ns.Keypoints[#ns.Keypoints].Value end
	-- Step through each sequential pair of keypoints and see if alpha
	-- lies between the points' time values.
	for i = 1, #ns.Keypoints - 1 do
		local this = ns.Keypoints[i]
		local next = ns.Keypoints[i + 1]
		if time >= this.Time and time < next.Time then
			-- Calculate how far alpha lies between the points
			local alpha = (time - this.Time) / (next.Time - this.Time)
			-- Evaluate the real value between the points using alpha
			return Math.LerpNum(this.Value, next.Value, alpha)
		end
	end
end

function Math.AngleBetweenXZ(origin, destination)
	local adjacent = origin.X - destination.X
	local opppposite = origin.Z - destination.Z
	local angle = atan2(adjacent, opppposite)

	return angle
end
function Math.AngleBetweenXY(origin, destination)
	local adjacent = origin.X - destination.X
	local opppposite = origin.Y - destination.Y
	local angle = atan2(adjacent, opppposite)

	return angle
end

function Math.XYOnCircle(orgX, orgY, radius: number, angle: number)
	orgX, orgY = (orgX or 0), (orgY or 0)
	radius = radius or 1
	local x, y = cos(angle), sin(angle)
	x *= radius
	y *= radius
	x += orgX
	y += orgY -- pay attention.
	return x, y
end

function Math.AngleBetweenThree(start, mid, finish)
	local v1 = (start - mid)
	local v2 = (finish - mid)
	local v1norm = v1.Unit
	local v2norm = v2.Unit

	local res = v1norm.X * v2norm.X + v1norm.Y * v2norm.Y + v1norm.Z * v2norm.Z
	return math.acos(res)
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

function Math.DistanceToSegment( v, a, b )
	local ab = b - a
	local av = v - a

	if (av:Dot(ab) <= 0.0) then
		return av.Magnitude
	end

	local bv = v - b

	if (bv:Dot(ab) >= 0.0) then
		return bv.Magnitude
	end

	local c = ab:Cross( av )
	return c.Magnitude / ab.Magnitude
end


return Math
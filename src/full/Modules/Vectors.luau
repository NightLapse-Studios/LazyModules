
local abs = math.abs
local cos = math.cos
local random = math.random
local sin = math.sin
local sqrt = math.sqrt
local atan2 = math.atan2
local max = math.max
local acos = math.acos
local pi = math.pi
local PI_2 = pi * 2

local ReplicatedFirst = game.ReplicatedFirst
local Modules = ReplicatedFirst.Modules
local Math = require(Modules.Math)

local ZERO_VEC3 = Vector3.new()

local Vector = {}

local RNG = Random.new()


local function get_axis_rot(axis, vec)
	return math.atan2(axis.X*vec.Z-axis.Z*vec.X, axis.X*vec.X + axis.Z*vec.Z)
end
local function is_finite(num)
	return num == num and num ~= 1/0 and num ~= -1/0
end
local function is_finite_vec3(vec3)
	return is_finite(vec3.x) and is_finite(vec3.y) and is_finite(vec3.z)
end


function Vector.CompsXZ(vec)
	return vec.X, vec.Z
end

function Vector.CompsXY(vec)
	return vec.X, vec.Y
end

function Vector.CompsXYZ(vec)
	return vec.X, vec.Y, vec.Z
end

function Vector.HalfMagnitude(x, y, z)
	if z then
		return x * x + y * y + z * z
	else
		return x * x + y * y
	end
end

function Vector.TaxiMagnitude(x, y, z)
	if z then
		return abs(x) + abs(y) + abs(z)
	else
		return abs(x) + abs(y)
	end
end

function Vector.Magnitude(x, y, z)
	return sqrt(Vector.HalfMagnitude(x, y, z))
end

function Vector.Vec2Distance(x,y, x2,y2)
	return Vector.Magnitude(x - x2, y - y2)
end

function Vector.Vec3Distance(x,y,z, x2,y2,z2)
	return Vector.Magnitude(x - x2, y - y2, z - z2)
end

function Vector.Unit(x, y, z)
	local mag = Vector.Magnitude(x, y, z)
	if mag == 0 then
		return 0, 0, 0-- if you have vec2 then just ingore third return
	end
	if z then
		return x/mag, y/mag, z/mag
	else
		return x/mag, y/mag
	end
end

function Vector.IsPointLeftOfLine(lp1x, lp1y, lp2x, lp2y, px, py)
	return ((lp2x - lp1x)*(py - lp1y) - (lp2y - lp1y)*(px - lp1x)) > 0
end

function Vector.IsPosBehindCF(charCF, pos)
	local point1,point2 = (charCF + charCF.LookVector), (charCF + charCF.LookVector * -1)
	local mag1, mag2 = (point1.Position - pos).Magnitude, (point2.Position - pos).Magnitude
	return not (mag1 <= mag2)
end

function Vector.RandomUnitVector2(lim)
	local theta = Math.randomNumber(0, lim or pi * 2)
	local x,y = Math.XYOnCircle(0, 0, 1, theta)

	return Vector2.new(x, y)
end

function Vector.RandomUnitVector3(lim)-- relative to 0,0,1
	lim = lim or pi
	local theta = Math.randomNumber(0, 2 * pi)
	local z = Math.randomNumber(cos(lim), 1)

	local c = sqrt(1 - z * z)
	return Vector3.new(c * cos(theta), c * sin(theta), z)
end

function Vector.RandomVector2Offset(x, y, maxAngle)
	return Vector.Vector2Offset(x, y, Math.randomNumber(-maxAngle, maxAngle))
end

function Vector.Vector2Offset(x, y, angle)
	local cangle = atan2(x, y)
	x, y = Math.XYOnCircle(0,0,1, cangle + angle)
	return x, y
end

function Vector.RelativeToOther(vec, relativeToVec)
	local cf = CFrame.new(ZERO_VEC3, vec)
	local ocf = CFrame.new(ZERO_VEC3, relativeToVec)

	return -(cf * ocf).LookVector
end

-- Finds the absolute angle between two vectors around an axis vector
function Vector.AxisAngleBetweenVectors(axis, vec1, vec2)
	vec1 -= vec1:Dot(axis) * axis
	vec2 -= vec2:Dot(axis) * axis
	vec1 /= vec1.Magnitude
	vec2 /= vec2.Magnitude

	local ang = acos(vec1:Dot(vec2))

	return ang 
end

function Vector.PointToPlaneDistance(p, p1, p2, p3)
    -- Calculate the normal vector of the plane
    local v1 = p2 - p1
    local v2 = p3 - p1
    local normal = v1:Cross(v2).Unit
    
    local v = p - p1
    local dist = math.abs(v:Dot(normal))

    return dist
end

function Vector.PointToLineDistance(point, linePointA, linePointB)
    local lineVector = linePointB - linePointA

    local pointVector = point - linePointA

    local lineLength = lineVector.Magnitude
    local lineDirection = lineVector.Unit

    local dotProduct = pointVector:Dot(lineDirection)

    local closestPoint
    if dotProduct <= 0 then
        closestPoint = linePointA
    elseif dotProduct >= lineLength then
        closestPoint = linePointB
    else
        closestPoint = linePointA + lineDirection * dotProduct
    end

    local distance = (point - closestPoint).Magnitude

    return distance, closestPoint
end

-- part must be a rectangle
function Vector.ClosestPointOnPrism(pos, part)
	local relPoint = part.CFrame:PointToObjectSpace(pos)
	local clampedPos = Vector3.new(
		math.clamp(relPoint.X, -part.Size.X/2, part.Size.X/2),
		math.clamp(relPoint.Y, -part.Size.Y/2, part.Size.Y/2),
		math.clamp(relPoint.Z, -part.Size.Z/2, part.Size.Z/2)
	)
	local closestPoint = part.CFrame:PointToWorldSpace(clampedPos)
	return closestPoint
end

-- Finds the signed angle between two vectors around an axis vector
-- Much safer for general use, especially in world space
function Vector.SignedAxisAngleBetweenVectors(axis, vec1, vec2)
	vec1 -= vec1:Dot(axis) * axis
	vec2 -= vec2:Dot(axis) * axis
	vec1 /= vec1.Magnitude
	vec2 /= vec2.Magnitude

	local ang = acos(vec1:Dot(vec2))
	ang *= -math.sign(vec1:Cross(axis):Dot(vec2))

	return ang
end

-- Takes in a 3d normal and an angle, then returns a look-vector rotated around the normal. The normal may face any direction and be of any size.
function Vector.VectorRotatedAroundNormal(normal, angle)
	local cf = CFrame.new(Vector3.new(), normal)
	cf *= CFrame.Angles(0, 0, angle)

	return cf.UpVector
end

-- rotate v1 towards v2 by angle theta
function Vector.RotateTowards(v1, v2, theta)
	local D_tick = v1:Cross(v2):Cross(v1).Unit
	local v3 = cos(theta) * v1 + sin(theta) * D_tick
	return v3
end

function Vector.VectorOffset(v, CFrameAngles)
	return (CFrame.new(Vector3.new(), v) * CFrameAngles).LookVector
end

function Vector.RandomVectorOffset(v, maxAngle)
	return (CFrame.new(Vector3.new(), v) * CFrame.Angles(0, 0, random() * PI_2) * CFrame.Angles(acos(Math.randomNumber(cos(maxAngle), 1)), 0, 0)).LookVector
end

function Vector.PlanarOffset(normal: Vector3, offset: Vector2): Vector3
	local new_offset = (CFrame.new(Vector3.new(), normal) * CFrame.new(offset.X, offset.Y, 0)).Position

	return new_offset
end

function Vector.PlanarOffsetRot(normal: Vector3, rot: number): Vector3
	local offset = Vector2.new(math.sin(rot), math.cos(rot))
	local new_offset = (CFrame.new(Vector3.new(), normal) * CFrame.new(offset.X, offset.Y, 0)).Position

	return new_offset
end

function Vector.RandomPlanarOffset(normal: Vector3, dist: number, opt_rng: Random?): Vector3
	local rng = opt_rng or RNG
	local ang = rng:NextNumber() * PI_2
	local offset = Vector2.new(dist * cos(ang), dist * sin(ang))

	return Vector.PlanarOffset(normal, offset)
end

function Vector.PerpendicularBisector(x1, y1, x2, y2)
	local cx = (x1 + x2) * 0.5
	local cy = (y1 + y2) * 0.5

	x1 -= cx
	y1 -= cy
	x2 -= cx
	y2 -= cy

	local xtemp = x1
	local ytemp = y1
	x1 = -ytemp
	y1 = xtemp

	xtemp = x2
	ytemp = y2
	x2 = -ytemp
	y2 = xtemp

	x1 += cx
	y1 += cy
	x2 += cx
	y2 += cy

	return Vector2.new(x1, y1), Vector2.new(x2, y2)
end
--[[ function Vector.InvCross(self, Number)
	return Vector2.new(-Number * self.Y, Number * self.X)
end ]]

function Vector.GetProjectileVelocity(start, finish, angle, gravity)						
	local yComponent = math.sin(angle)
	local hComponent = math.cos(angle)
	local totalDirectionVec = finish - start
	local XandZScale = math.sqrt((1 - yComponent ^ 2) / (totalDirectionVec.X ^ 2 + totalDirectionVec.Z ^ 2))
	local unitDirectionVec = Vector3.new(totalDirectionVec.X * XandZScale, yComponent, totalDirectionVec.Z * XandZScale)
	local height = start.Y - finish.Y
	local range = math.sqrt(totalDirectionVec.X ^ 2 + totalDirectionVec.Z ^ 2)
	
	local discriminant = (2 * height * hComponent ^ 2 + range * math.sin(2 * angle))
	local speed = range * math.sqrt(gravity * discriminant) / discriminant
	
	-- quadratic formula occured, so we must make it make sense just incase
	speed = math.abs(speed)
	
	return unitDirectionVec * speed
end

function Vector.Intersect(xa, ya, xb, yb,  xc, yc, xd, yd)
	local rx, ry = xb - xa, yb - ya
	local sx, sy = xd - xc, yd - yc

	local xcMxa = xc - xa
	local ycMya = yc - ya
	local d = rx * sy - ry * sx

	local u = (xcMxa * ry - ycMya * rx) / d
	if u < 0 or u > 1 then
		return
	end

	local t = (xcMxa * sy - ycMya * sx) / d
	if t < 0 or t > 1 then
		return
	end

	local trx, try = t * rx, t * ry
	return xa + trx, ya + try
end

function Vector.IsInPolygon(x, y, edges)
	local intersections = 0
	local ox = x + 1e20
	for _, edge in pairs(edges) do
		local i, b = edge[1].Value, edge[2].Value
		if Vector.Intersect(x, y, ox, y, i.X, i.Z, b.X, b.Z) then
			intersections += 1
		end
	end

	return intersections % 2 ~= 0
end

function Vector.MaxAxisExtents(self, other)
	local dx = self.X - other.X
	local dy = self.Y - other.Y
    return max(abs(dx), abs(dy))
end

function Vector.ReflectVector(vecIn, NormalVec)
	return vecIn - 2 * vecIn:Dot(NormalVec) * NormalVec
end

function Vector.Round(self, Custom)
	return Vector2.new(Math.Round(self.X, Custom), Math.Round(self.Y, Custom))
end

return Vector
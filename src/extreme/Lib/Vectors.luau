
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

local Math = require(game.ReplicatedFirst.Lib.Math)

local ZERO_VEC3 = Vector3.new()

local Vectors = {}

local RNG = Random.new()

function Vectors.HalfMagnitude(x, y, z)
	if z then
		return x * x + y * y + z * z
	else
		return x * x + y * y
	end
end

function Vectors.TaxiMagnitude(x, y, z)
	if z then
		return abs(x) + abs(y) + abs(z)
	else
		return abs(x) + abs(y)
	end
end

function Vectors.Magnitude(x, y, z)
	return sqrt(Vectors.HalfMagnitude(x, y, z))
end

function Vectors.Vec2Distance(x,y, x2,y2)
	return Vectors.Magnitude(x - x2, y - y2)
end

function Vectors.Vec3Distance(x,y,z, x2,y2,z2)
	return Vectors.Magnitude(x - x2, y - y2, z - z2)
end

function Vectors.Unit(x, y, z)
	local mag = Vectors.Magnitude(x, y, z)
	if mag == 0 then
		return 0, 0, 0-- if you have vec2 then just ingore third return
	end
	if z then
		return x/mag, y/mag, z/mag
	else
		return x/mag, y/mag
	end
end

function Vectors.IsPointLeftOfLine(lp1x, lp1y, lp2x, lp2y, px, py)
	return ((lp2x - lp1x)*(py - lp1y) - (lp2y - lp1y)*(px - lp1x)) > 0
end

function Vectors.IsPosBehindCF(charCF, pos)
	local point1,point2 = (charCF + charCF.LookVector), (charCF + charCF.LookVector * -1)
	local mag1, mag2 = (point1.Position - pos).Magnitude, (point2.Position - pos).Magnitude
	return not (mag1 <= mag2)
end

function Vectors.RandomUnitVector2(lim)
	local theta = Math.randomNumber(0, lim or pi * 2)
	local x,y = Vectors.XYOnCircle(0, 0, 1, theta)

	return Vector2.new(x, y)
end

function Vectors.RandomUnitVector3(lim)-- relative to 0,0,1
	lim = lim or pi
	local theta = Math.randomNumber(0, 2 * pi)
	local z = Math.randomNumber(cos(lim), 1)

	local c = sqrt(1 - z * z)
	return Vector3.new(c * cos(theta), c * sin(theta), z)
end

function Vectors.RandomVector2Offset(x, y, maxAngle)
	return Vectors.Vector2Offset(x, y, Math.randomNumber(-maxAngle, maxAngle))
end

function Vectors.Vector2Offset(x, y, angle)
	local cangle = atan2(x, y)
	x, y = Vectors.XYOnCircle(0,0,1, cangle + angle)
	return x, y
end

function Vectors.RelativeToOther(vec, relativeToVec)
	local cf = CFrame.new(ZERO_VEC3, vec)
	local ocf = CFrame.new(ZERO_VEC3, relativeToVec)

	return -(cf * ocf).LookVector
end

-- Finds the absolute angle between two vectors around an axis vector
function Vectors.AxisAngleBetweenVectors(axis, vec1, vec2)
	vec1 -= vec1:Dot(axis) * axis
	vec2 -= vec2:Dot(axis) * axis
	vec1 /= vec1.Magnitude
	vec2 /= vec2.Magnitude

	local ang = acos(vec1:Dot(vec2))

	return ang 
end

function Vectors.CCWTangentPoint(target: Vector2, source: Vector2, radius: number)
	local tx, tY, sx, sY = target.X, target.Y, source.X, source.Y
	
	local dx = tx - sx
    local dy = tY - sY
    local D_squared = dx * dx + dy * dy
	local r_squared = radius * radius
	
    if D_squared < r_squared then
        return Vector2.new(sx-dx, sY-dy), false
	end
	
    local L = sqrt(D_squared - r_squared);

    local x0, y0, x1, y1 = Vectors.FindCircleCircleIntersections(
        tx, tY, radius,
        sx, sY, L)

	return Vector2.new(x0, y0), true
end

function Vectors.CWTangentPoint(target: Vector2, source: Vector2, radius: number)
	local tx, tY, sx, sY = target.X, target.Y, source.X, source.Y
	
	local dx = tx - sx
    local dy = tY - sY
    local D_squared = dx * dx + dy * dy
	local r_squared = radius * radius
	
    if D_squared < r_squared then
        return Vector2.new(sx-dx, sY-dy), false
	end
	
    local L = sqrt(D_squared - r_squared);

    local x0, y0, x1, y1 = Vectors.FindCircleCircleIntersections(
        tx, tY, radius,
        sx, sY, L)

	return Vector2.new(x1 or x0, y1 or y0), true
end

function Vectors.PointToPlaneDistance(p, p1, p2, p3)
    -- Calculate the normal vector of the plane
    local v1 = p2 - p1
    local v2 = p3 - p1
    local normal = v1:Cross(v2).Unit
    
    local v = p - p1
    local dist = math.abs(v:Dot(normal))

    return dist
end

function Vectors.PointToLineDistance(point, linePointA, linePointB)
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

    return distance
end

-- part must be a rectangle
function Vectors.ClosestPointOnPrism(pos, part)
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
function Vectors.SignedAxisAngleBetweenVectors(axis, vec1, vec2)
	vec1 -= vec1:Dot(axis) * axis
	vec2 -= vec2:Dot(axis) * axis
	vec1 /= vec1.Magnitude
	vec2 /= vec2.Magnitude

	local ang = acos(vec1:Dot(vec2))
	ang *= -math.sign(vec1:Cross(axis):Dot(vec2))

	return ang
end

-- Takes in a 3d normal and an angle, then returns a look-vector rotated around the normal. The normal may face any direction and be of any size.
function Vectors.VectorRotatedAroundNormal(normal, angle)
	local cf = CFrame.new(ZERO_VEC3, normal)
	cf *= CFrame.Angles(0, angle, 0)

	return cf.LookVector
end

-- rotate v1 towards v2 by angle theta
function Vectors.RotateTowards(v1, v2, theta)
	local D_tick = v1:Cross(v2):Cross(v1).Unit
	local v3 = cos(theta) * v1 + sin(theta) * D_tick
	return v3
end

function Vectors.VectorOffset(v, CFrameAngles)
	return (CFrame.new(ZERO_VEC3, v) * CFrameAngles).LookVector
end

function Vectors.RandomVectorOffset(v, maxAngle)
	return (CFrame.new(ZERO_VEC3, v) * CFrame.Angles(0, 0, random() * PI_2) * CFrame.Angles(acos(Math.randomNumber(cos(maxAngle), 1)), 0, 0)).LookVector
end

function Vectors.PlanarOffset(normal: Vector3, offset: Vector2): Vector3
	local new_offset = (CFrame.new(ZERO_VEC3, normal) * CFrame.new(offset.X, offset.Y, 0)).Position

	return new_offset
end

function Vectors.PlanarOffsetRot(normal: Vector3, rot: number): Vector3
	local offset = Vector2.new(math.sin(rot), math.cos(rot))
	local new_offset = (CFrame.new(ZERO_VEC3, normal) * CFrame.new(offset.X, offset.Y, 0)).Position

	return new_offset
end

function Vectors.RandomPlanarOffset(normal: Vector3, dist: number, opt_rng: Random?): Vector3
	local rng = opt_rng or RNG
	local ang = rng:NextNumber() * PI_2
	local offset = Vector2.new(dist * cos(ang), dist * sin(ang))

	return Vectors.PlanarOffset(normal, offset)
end

function Vectors.PerpendicularBisector(x1, y1, x2, y2)
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

function Vectors.Intersect(xa, ya, xb, yb,  xc, yc, xd, yd)
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

function Vectors.IsInPolygon(x, y, edges)
	local intersections = 0
	local ox = x + 1e20
	for _, edge in pairs(edges) do
		local i, b = edge[1].Value, edge[2].Value
		if Vectors.Intersect(x, y, ox, y, i.X, i.Z, b.X, b.Z) then
			intersections += 1
		end
	end

	return intersections % 2 ~= 0
end

function Vectors.MaxAxisExtents(self, other)
	local dx = self.X - other.X
	local dy = self.Y - other.Y
    return max(abs(dx), abs(dy))
end

function Vectors.ReflectVector(vecIn, NormalVec)
	return vecIn - 2 * vecIn:Dot(NormalVec) * NormalVec
end

function Vectors.Round(self, Custom)
	return Vector2.new(Math.Round(self.X, Custom), Math.Round(self.Y, Custom))
end

function Vectors.IsPointInHoopSlice(x, y, radiusMin, radiusMax, angle1, angle2, cenX, cenY)
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
	
	return false
end

function Vectors.FindCircleCircleIntersections(cx0, cy0, radius0, cx1, cy1, radius1)
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

function Vectors.GetRotatedPoint(x,y , AnchorPoint, angle)
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

function Vectors.AngleBetween(x1, y1,  x2, y2)
	local adjacent = x1 - x2
	local opppposite = y1 - y2
	local angle = atan2(adjacent, opppposite)

	return angle
end

function Vectors.XYOnCircle(orgX, orgY, radius: number, angle: number)
	orgX, orgY = (orgX or 0), (orgY or 0)
	radius = radius or 1
	local x, y = cos(angle), sin(angle)
	x *= radius
	y *= radius
	x += orgX
	y += orgY -- pay attention.
	return x, y
end

function Vectors.AngleBetweenThree(start, mid, finish)
	local v1 = (start - mid)
	local v2 = (finish - mid)
	local v1norm = v1.Unit
	local v2norm = v2.Unit

	local res = v1norm:Dot(v2norm)
	return acos(res)
end

return Vectors
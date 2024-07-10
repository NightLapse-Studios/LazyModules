local Math = require(game.ReplicatedFirst.Lib.Math)

local EffectUtil = {
	AssetFormat = "rbxassetid://",
}

function EffectUtil.IsDay(MinutesAfterMidnight)
	if MinutesAfterMidnight >= 6 * 60 and MinutesAfterMidnight < 18 * 60 then
		return true
	end
	return false
end

function EffectUtil.PartForPosition(CForPosition)
	local p = Instance.new("Part")
	p.CFrame = typeof(CForPosition) == "CFrame" and CForPosition or CFrame.new(CForPosition)
	p.Transparency = 1
	p.Anchored = true
	p.Massless = true
	p.CanQuery = false
	p.CanCollide = false

	return p
end

function EffectUtil.EditColorSequence(sequence, funcReplace)
	local newSequence = {}
	for _,v in pairs(sequence.Keypoints) do
		local newTime, newValue, destroy = funcReplace(v.Time, v.Value)
		if not destroy then
			newSequence[#newSequence + 1] = ColorSequenceKeypoint.new(newTime or v.Time, newValue or v.Value)
		end
	end
	return ColorSequence.new(newSequence)
end

function EffectUtil.EditNumberSequence(sequence, funcReplace)
	local newSequence = {}
	for _,v in pairs(sequence.Keypoints) do
		local newTime, newValue, newEnvelope, destroy = funcReplace(v.Time, v.Value, v.Envelope)
		if not destroy then
			newSequence[#newSequence + 1] = NumberSequenceKeypoint.new(newTime or v.Time, newValue or v.Value, newEnvelope or v.Envelope)
		end
	end
	return NumberSequence.new(newSequence)
end

function EffectUtil.GetWeldOffset(p0, p1, o0, o1)
	local cf0, cf1 = o0 or p0.CFrame, o1 or p1.CFrame

	local CJ = CFrame.new( cf0.Position )
	return cf0:Inverse() * CJ, cf1:Inverse() * CJ
end

function EffectUtil.SetWeldOffset(weld, p0, p1, o0, o1)
	local offsetC0, offsetC1 = EffectUtil.GetWeldOffset(p0 or weld.Part0, p1 or weld.Part1, o0, o1)
	weld.C0 = offsetC0
	weld.C1 = offsetC1
end

function EffectUtil.Weld(p0, p1, noOffset, p0cf, p1cf, name)
	local Weld = Instance.new("ManualWeld")
	Weld.Name = name or p0.Name .. "_" .. p1.Name

	Weld.Part0 = p0
	Weld.Part1 = p1

	if not noOffset then
		EffectUtil.SetWeldOffset(Weld, p0, p1, p0cf, p1cf)
	end

	Weld.Parent = p0
	return Weld
end

function EffectUtil.PhysicsWeld(p0, p1, noOffset, p0cf, p1cf)
	-- welds but continues to simulate physics of both parts seperately

	local c0, c1 = CFrame.identity, CFrame.identity
	if not noOffset then
		c0, c1 = EffectUtil.GetWeldOffset(p0, p1, p0cf, p1cf)
	end

	local a0 = Instance.new("Attachment", p0)
	a0.CFrame = c0

	local a1 = Instance.new("Attachment", p1)
	a1.CFrame = c1

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.RigidityEnabled = true
	alignPosition.Attachment0 = a0
	alignPosition.Attachment1 = a1
	alignPosition.Parent = p0

	local AlignOrientation = Instance.new("AlignOrientation")
	AlignOrientation.RigidityEnabled = true
	AlignOrientation.Attachment0 = a0
	AlignOrientation.Attachment1 = a1
	AlignOrientation.Parent = p0

	return alignPosition, AlignOrientation, a0, a1
end

function EffectUtil.PhysicsAnchor(part)
	-- effectively anchors but without the Anchor property
	
	local att = Instance.new("Attachment", part)
	
	local vel = Instance.new("LinearVelocity")
	vel.Attachment0 = att
	vel.MaxForce = 10000
	vel.VectorVelocity = Vector3.zero
	vel.Parent = att
	
	local avel = Instance.new("AngularVelocity")
	avel.Attachment0 = att
	avel.MaxTorque = 10000
	avel.AngularVelocity = Vector3.zero
	avel.Parent = att
	
	return att
end

function EffectUtil.WeldToBone(part, bone)
	local RigidConstraint = Instance.new("RigidConstraint")

	local a0 = Instance.new("Attachment")
	a0.Name = "WeldAttachmentBone"
	a0.Parent = bone
	a0.WorldCFrame = part.CFrame

	local a1 = Instance.new("Attachment")
	a1.Name = "WeldAttachmentPart"
	a1.Parent = part
	a1.WorldCFrame = part.CFrame

	RigidConstraint.Attachment0 = a0
	RigidConstraint.Attachment1 = a1

	RigidConstraint.Parent = part

	return RigidConstraint
end

function EffectUtil.GetNearestBone(rootBone, pos)
	local itterate = rootBone:GetDescendants()
	table.insert(itterate, rootBone)

	local closestBone = nil
	local closestDist = math.huge

	for _, bone: Instance in itterate do
		if bone:IsA("Bone") then
			local dist = (bone.TransformedWorldCFrame.Position - pos).Magnitude
			if dist < closestDist then
				closestDist = dist
				closestBone = bone
			end
		end
	end

	return closestBone
end

function EffectUtil.GetNumbersFromId(asset_str)
	return string.sub(asset_str, 14, -1)
end

function EffectUtil.AddFormatToId(assetid)
	return EffectUtil.AssetFormat .. assetid
end

function EffectUtil.CheckId(asset_str)
	if string.sub(asset_str, 1, 13) == EffectUtil.AssetFormat then
		if not string.find(EffectUtil.GetNumbersFromId(asset_str), "%D") then
			return true
		end
	end
	return false
end

function EffectUtil.NewDiskCylinder(pos, norm, thickness, radius)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(thickness, radius, radius)
	p.CFrame = CFrame.new(pos, pos + norm) * CFrame.Angles(0, math.rad(90), 0)
	return p
end

function EffectUtil.EvalNumberSequence(ns, time)
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

function EffectUtil.EvalColorSequence( cs, time )
	local ClosestLeftValue, ClosestLeftTime
	for i = 1, #cs.Keypoints do
		local point = cs.Keypoints[i]
		if ClosestLeftTime == nil or point.Time <= time then
			ClosestLeftTime = point.Time
			ClosestLeftValue = point.Value
		end
	end

	local ClosestRightValue, ClosestRightTime
	for i = #cs.Keypoints, 1, -1 do
		local point = cs.Keypoints[i]
		if ClosestRightTime == nil or point.Time >= time then
			ClosestRightTime = point.Time
			ClosestRightValue = point.Value
		end
	end

	local alpha = ( time - ClosestLeftTime ) / ( ClosestRightTime - ClosestLeftTime )
	return ClosestLeftValue:Lerp( ClosestRightValue, alpha )
end

-- randomize any ascpect of a color
function EffectUtil.RandomColor(hue: n0to360, saturation: n0to100, value: n0to100, r: Random)
	if r then
		local h = hue or r:NextNumber() * 360
		local s = saturation or r:NextNumber() * 100
		local v = value or r:NextNumber() * 100
		return Color3.fromHSV(h / 360, s / 100, v / 100)
	else
		local h = hue or math.random() * 360
		local s = saturation or math.random() * 100
		local v = value or math.random() * 100
		return Color3.fromHSV(h / 360, s / 100, v / 100)
	end
end

return EffectUtil
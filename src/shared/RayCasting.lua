
local Vectors

local CollectionService = game:GetService("CollectionService")

local RayCasting = {
	__init = function(self, G)
		Vectors = G.Load("Vectors")
	end
}

RayCasting.FilterDescendantsInstances = {}
RayCasting.RayCastParams = {}

local function updateParamsFilter(params, csGroups)
	local tb = {}
	for i = 1, #csGroups do
		tb[i] = RayCasting.FilterDescendantsInstances[csGroups[i]]
	end
	params.FilterDescendantsInstances = tb
end

local function updateAllWithGroup(group)
	for i, v in pairs(RayCasting.RayCastParams)do
		if table.find(v.Groups, group) then
			updateParamsFilter(v.Params, v.Groups)
		end
	end
end

function RayCasting.SetupRaycastTag(CSgroup)
	local RayCastCollisionPartsInit = CollectionService:GetTagged(CSgroup)

	RayCasting.FilterDescendantsInstances[CSgroup] = RayCastCollisionPartsInit
	updateAllWithGroup(CSgroup)

	local function addToRayCastCollisionParts(part)
		table.insert(RayCastCollisionPartsInit, part)
		RayCasting.FilterDescendantsInstances[CSgroup] = RayCastCollisionPartsInit
		updateAllWithGroup(CSgroup)
	end
	local function removeFromRayCastCollisionParts(part)
		table.remove(RayCastCollisionPartsInit, table.find(RayCastCollisionPartsInit, part))
		RayCasting.FilterDescendantsInstances[CSgroup] = RayCastCollisionPartsInit
		updateAllWithGroup(CSgroup)
	end

	CollectionService:GetInstanceAddedSignal(CSgroup):Connect(addToRayCastCollisionParts)
	CollectionService:GetInstanceRemovedSignal(CSgroup):Connect(removeFromRayCastCollisionParts)
end

function RayCasting.CreateRaycastParamsBL(name, csGroups, ignoreWater)
	ignoreWater = ignoreWater or false

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.IgnoreWater = ignoreWater
	updateParamsFilter(params, csGroups)

	RayCasting.RayCastParams[name] = {
		Params = params,
		Groups = csGroups,
		IgnoreWater = ignoreWater,
	}
end

function RayCasting.CreateRaycastParamsWL(name, csGroups, ignoreWater)
	ignoreWater = ignoreWater or false

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Whitelist
	params.IgnoreWater = ignoreWater
	updateParamsFilter(params, csGroups)

	RayCasting.RayCastParams[name] = {
		Params = params,
		Groups = csGroups,
		IgnoreWater = ignoreWater,
	}
end

function RayCasting.GetRaycastParamsBL(name, to_add: table)
	if to_add then
		local data = RayCasting.RayCastParams[name]
		local tb = data.Params.FilterDescendantsInstances

		-- This does not effect future raycasts because the following line returns FALSE
		-- local a = {} local p = RaycastParams.new() p.FilterDescendantsInstances = a print(p.FilterDescendantsInstances == a)
		for _, v in to_add do
			table.insert(tb, v)
		end

		local nparams = RaycastParams.new()
		nparams.FilterType = Enum.RaycastFilterType.Blacklist
		nparams.IgnoreWater = data.IgnoreWater
		nparams.FilterDescendantsInstances = tb

		return nparams
	else
		return RayCasting.RayCastParams[name].Params
	end
end

function RayCasting.GetRaycastParamsWL(name, to_add: table)
	if to_add then
		local data = RayCasting.RayCastParams[name]
		local tb = data.Params.FilterDescendantsInstances

		for _, v in to_add do
			table.insert(tb, v)
		end

		local nparams = RaycastParams.new()
		nparams.FilterType = Enum.RaycastFilterType.Whitelist
		nparams.IgnoreWater = data.IgnoreWater
		nparams.FilterDescendantsInstances = tb

		return nparams
	else
		return RayCasting.RayCastParams[name].Params
	end
end

-- Load and hook tags for instances which are the basis for WL/BL groups
RayCasting.SetupRaycastTag("WorldPart")
RayCasting.SetupRaycastTag("Invisibles")
RayCasting.SetupRaycastTag("Characters")
RayCasting.SetupRaycastTag("HRPs")
RayCasting.SetupRaycastTag("InvisibleBarriers")

RayCasting.CreateRaycastParamsWL("Barriers", 	{"WorldPart", "Characters"})
RayCasting.CreateRaycastParamsWL("Invisicam",   {"WorldPart"})

function RayCasting.ToStringResults(RCR: RaycastResult, field)
	if not RCR then
		return ""
	end

	if field then
		return tostring(RCR[field])
	end

	return tostring(RCR.Instance) .. tostring(RCR.Position) .. tostring(RCR.Material) .. tostring(RCR.Normal)
end

function RayCasting.InclusiveSpherecast(start, radius, direction, params)
	local unitDirection = direction.Unit

	local diameter = radius * 2
	local originalStart = start
	local finish = start + direction
	start = start - unitDirection * diameter

	local result

	local distance = 0

	while true do
		direction = finish - start

		result = workspace:Spherecast(start, radius, direction, params)
		if result then
			local distanceToCapsule = Vectors.PointToLineDistance(result.Position, originalStart, finish)
			local isInCapsule = distanceToCapsule <= radius

			distance += result.Distance

			if isInCapsule then
				result = setmetatable({
					Distance = math.max(distance - diameter, 0),
				}, {__index = result})

				break
			else
				distance += 0.001
				start += (result.Distance + 0.001) * unitDirection
			end
		else
			break
		end
	end

	return result
end

return RayCasting

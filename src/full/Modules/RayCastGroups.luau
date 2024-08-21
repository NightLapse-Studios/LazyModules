--!strict
--!native

local CollectionService = game:GetService("CollectionService")

local mod = { }

local FilterDescendantsInstances = {}
local RayCastParams: { [string]: {
		Params: RaycastParams,
		Groups: string,
		IgnoreWater: boolean,
	}
} = {}

mod.FilterDescendantsInstances = FilterDescendantsInstances
mod.RayCastParams = RayCastParams

local function updateParamsFilter(params, csGroups)
	local tb = {}
	for i = 1, #csGroups do
		tb[i] = FilterDescendantsInstances[csGroups[i]]
	end
	table.insert(tb, workspace.CurrentCamera)
	params.FilterDescendantsInstances = tb
end

local function updateAllWithGroup(group: string)
	for i, v in pairs(RayCastParams)do
		if table.find(v.Groups, group) then
			updateParamsFilter(v.Params, v.Groups)
		end
	end
end

function mod.SetupRaycastParts(tag: string)
	local RayCastCollisionPartsInit = CollectionService:GetTagged(tag)

	FilterDescendantsInstances[tag] = RayCastCollisionPartsInit
	updateAllWithGroup(tag)

	local function addToRayCastCollisionParts(part)
		table.insert(RayCastCollisionPartsInit, part)
		FilterDescendantsInstances[tag] = RayCastCollisionPartsInit
		updateAllWithGroup(tag)
	end
	local function removeFromRayCastCollisionParts(part)
		table.remove(RayCastCollisionPartsInit, table.find(RayCastCollisionPartsInit, part))
		FilterDescendantsInstances[tag] = RayCastCollisionPartsInit
		updateAllWithGroup(tag)
	end

	CollectionService:GetInstanceAddedSignal(tag):Connect(addToRayCastCollisionParts)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(removeFromRayCastCollisionParts)
end

function mod.CreateRaycastParamsBL(name: string, csGroups: { string }, ignoreWater: boolean?)
	ignoreWater = ignoreWater or false

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.IgnoreWater = ignoreWater
	updateParamsFilter(params, csGroups)

	local t = {
		Params = params,
		Groups = csGroups,
		IgnoreWater = ignoreWater,
	}

	RayCastParams[name] = t

	return t.Params
end

function mod.CreateRaycastParamsWL(name: string, csGroups: { string }, ignoreWater: boolean?)
	ignoreWater = ignoreWater or false

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Whitelist
	params.IgnoreWater = ignoreWater
	updateParamsFilter(params, csGroups)

	local t = {
		Params = params,
		Groups = csGroups,
		IgnoreWater = ignoreWater,
	}

	RayCastParams[name] = t

	return t.Params
end

local function add(tb, to_add)
	for _, v in to_add do
		if type(v) == "table" then
			add(tb, v)
		else
			table.insert(tb, v)
		end
	end
end

function mod.GetRaycastParamsBL(name, to_add: { Instance }?)
	if to_add then
		local data = RayCastParams[name]
		local tb = data.Params.FilterDescendantsInstances

		-- This does not effect future raycasts because the following line returns FALSE
		-- local a = {} local p = RaycastParams.new() p.FilterDescendantsInstances = a print(p.FilterDescendantsInstances == a)
		add(tb, to_add)

		local nparams = RaycastParams.new()
		nparams.FilterType = Enum.RaycastFilterType.Blacklist
		nparams.IgnoreWater = data.IgnoreWater
		nparams.FilterDescendantsInstances = tb

		return nparams
	else
		return RayCastParams[name].Params
	end
end

function mod.GetRaycastParamsWL(name, to_add: { Instance }?)
	if to_add then
		local data = RayCastParams[name]
		local tb = data.Params.FilterDescendantsInstances
		
		add(tb, to_add)

		local nparams = RaycastParams.new()
		nparams.FilterType = Enum.RaycastFilterType.Whitelist
		nparams.IgnoreWater = data.IgnoreWater
		nparams.FilterDescendantsInstances = tb

		return nparams
	else
		return RayCastParams[name].Params
	end
end

mod.SetupRaycastParts("Blood")
mod.SetupRaycastParts("Invisibles")
mod.SetupRaycastParts("Bullets")
mod.SetupRaycastParts("Character")
mod.SetupRaycastParts("HRPs")
mod.SetupRaycastParts("CanBuildOn")
mod.SetupRaycastParts("Wall")
mod.SetupRaycastParts("InvisibleBarriers")
mod.SetupRaycastParts("ForceFieldBarrier")

mod.CreateRaycastParamsBL("Blood", 		{"Invisibles", "Bullets", 			"Character", 	"InvisibleBarriers", 	"ForceFieldBarrier"}, 	true)
mod.CreateRaycastParamsBL("CameraDist", {"Blood", 	"Invisibles", "Bullets", 				"Character", 	"InvisibleBarriers", 	"ForceFieldBarrier"}, 	true)
mod.CreateRaycastParamsBL("Bullets", 	{"Invisibles"			 ,  "HRPs", 	 			"InvisibleBarriers"})
mod.CreateRaycastParamsBL("MouseRay", 	{"Invisibles",	"Bullets",  "HRPs", 	 			"InvisibleBarriers"})
mod.CreateRaycastParamsBL("FootSteps", 	{		  "Invisibles", 		    "HRPs", 	 			"InvisibleBarriers", 	"ForceFieldBarrier"})

mod.CreateRaycastParamsWL("Build", {"CanBuildOn"}, true)
mod.CreateRaycastParamsWL("Explosion", {"Wall"})

function mod.ToStringResults(RCR: RaycastResult, field)
	if not RCR then
		return ""
	end

	if field then
		return tostring(RCR[field])
	end

	return tostring(RCR.Instance) .. tostring(RCR.Position) .. tostring(RCR.Material) .. tostring(RCR.Normal)
end

return mod

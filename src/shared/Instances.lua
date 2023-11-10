local CollectionService = game:GetService("CollectionService")

type Array<T> = {[number]: T}

local pcall = pcall

local ReplicatedStorage = game.ReplicatedStorage

local mod = {}

function mod.GetDescendantsWhichIsA(inst, classname)
	local ret = {}
	for _,v in pairs(inst:GetDescendants())do
		if v:IsA(classname) then
			ret[#ret + 1] = v
		end
	end
	return ret
end
function mod.GetChildrenWhichIsA(inst, classname)
	local ret = {}
	for _,v in pairs(inst:GetChildren())do
		if v:IsA(classname) then
			ret[#ret + 1] = v
		end
	end
	return ret
end

function mod.NameContains(inst, str)
	return string.find(string.upper(inst.Name), string.upper(str))
end
function mod.GetDescendantsWhichNamesContain(inst, str)
	local ret = {}
	for _,v in pairs(inst:GetDescendants())do
		if mod.NameContains(inst, str) then
			ret[#ret+1] = v
		end
	end
	return ret
end
function mod.GetChildrenWhichNamesContain(inst, str)
	local ret = {}
	for _,v in pairs(inst:GetChildren())do
		if mod.NameContains(inst, str) then
			ret[#ret+1] = v
		end
	end
	return ret
end

function mod.FollowObjectValues(objValue: ObjectValue)
	while objValue:IsA("ObjectValue") do
		objValue = objValue.Value
	end
	return objValue
end

function mod.NewRemoteEvent(name): RemoteEvent
	local ins = Instance.new("RemoteEvent")
	ins.Name = name
	ins.Parent = ReplicatedStorage
	return ins
end

function mod.NewRemoteFunction(name): RemoteFunction
	local ins = Instance.new("RemoteFunction")
	ins.Name = name
	ins.Parent = ReplicatedStorage
	return ins
end

function mod.GetRemote(name): any
	return ReplicatedStorage:FindFirstChild(name)
end

function mod.FindFirstDescendant(Inst, Name)
	for i,v in pairs(Inst:GetDescendants())do
		if v.Name == Name then
			return v
		end
	end
	return nil
end

function mod.FindFirstDescendantWhichIsA(Inst, Class)
	for i,v in pairs(Inst:GetDescendants()) do
		if v.ClassName == Class or v:IsA(Class) then
			return v
		end
	end

	return nil
end

local function hasp(inst, prop)
	return inst[prop]
end

function mod.HasProperty(Inst, PropertyName) -- Do not name anything that is also a property name.
	local suc, ret = pcall(hasp, Inst, PropertyName)
	if suc then
		return ret
	end
	return nil
end

--[[ `Match` functions look for `Instance` objects that contain certain properties
]]--
function mod.MatchDescendants(Inst, PropertiesTbl) -- Standard: {Name = "Part", Anchored = true} etc...
	local Matched = { }

	local Increment = 0
	for _,v in pairs(Inst:GetDescendants()) do
		local HasValue = true

		for Property, Value in pairs(PropertiesTbl) do
			local CheckValue = mod.HasProperty(v, Property)
			if CheckValue ~= Value then
				HasValue = false
				break
			end
		end

		if HasValue == true then
			Increment += 1
			Matched[Increment] = v
		end
	end

	return Matched
end

function mod.GetParentWhichHasParent(Inst, Parent)
	while Inst.Parent ~= Parent do
		if Inst.Parent == nil then
			return nil-- game.Parent is nil
		end
		Inst = Inst.Parent
	end
	return Inst
end

function mod.GetParentWhichHasTag(Inst, tag)
	while not CollectionService:HasTag(Inst, tag) do
		if Inst.Parent == nil then
			return nil-- game.Parent is nil
		end
		Inst = Inst.Parent
	end
	return Inst
end

function mod.GetParentWhichHasProperties(Inst, PropertiesTbl)
	while Inst.Parent and Inst.Parent.Parent and Inst.Parent.Parent ~= game do
		Inst = Inst.Parent

		for Property, Value in pairs(PropertiesTbl) do
			local CheckValue = mod.HasProperty(Inst, Property)
			if CheckValue == Value then
				return Inst
			end
		end
	end
	return nil
end

function mod.MatchChildren(Inst, PropertiesTbl) -- Standard: {Name = "Part", Anchored = true} etc...
	local Matched = { }

	local Increment = 0
	for i,v in pairs(Inst:GetChildren()) do
		local HasValue = false

		for Property, Value in pairs(PropertiesTbl) do
			local CheckValue = mod.HasProperty(v, Property)
			if CheckValue == Value then
				HasValue = true
				break
			end
		end

		if HasValue == true then
			Increment += 1
			Matched[Increment] = v
		end
	end

	return Matched
end

function mod.BuildPath(paths: table, typeToBuild: string)
	for _,v in pairs(paths)do
		local split = string.split(v, ".")
		local fold = game
		for _,q in pairs(split) do
			local find = fold:FindFirstChild(q)
			if find then
				fold = find
				continue
			end
			local folder = Instance.new(typeToBuild)
			folder.Name = q
			folder.Parent = fold
			fold = folder
		end
	end
end

local pointerValues = {"Part1", "Part0", "Attachment0", "Attachment1", "Value", "Parent"}
function mod.SetMeshId(meshPart, meshId, SizeFitMesh: boolean)-- READ BEFORE USE
	local part = game.ReplicatedStorage.MeshIds[meshId]:Clone()

	if not SizeFitMesh then
		part.Size = meshPart.Size
	end

	part.Transparency = meshPart.Transparency
	part.Color = meshPart.Color
	part.Material = meshPart.Material
	part.CFrame = meshPart.CFrame
	part.Name = meshPart.Name
	part.Parent = meshPart.Parent
	part.Reflectance = meshPart.Reflectance
	part.CastShadow = meshPart.CastShadow
	part.Anchored = meshPart.Anchored
	part.CanCollide = meshPart.CanCollide

	if meshPart.Parent and mod.HasProperty(meshPart.Parent, "PrimaryPart") then
		meshPart.Parent.PrimaryPart = part
		for _, v in pairs(meshPart.Parent:GetDescendants())do
			if v == meshPart then continue end
			for _, q in pairs(pointerValues) do
				if mod.HasProperty(v, q) and v[q] == meshPart then
					v[q] = part
				end
			end
		end
	else
		for _,v in pairs(meshPart:GetChildren()) do
			v.Parent = part
		end
	end

	meshPart:Destroy()

	return part
end

--[[ A "Cousin" is an object that shares a parent with another object.
	Cousins deeper than the first ones found will not be returned.

	Very slow; use sparingly!
]]--

function mod.MatchCousins(Inst, PropertiesTbl) -- e.g:{Name = "Humanoid"}
	local Matched = { }

	while true do
		if Inst.Parent == nil or Inst.Parent == workspace then
			Inst = nil
			break
		end

		local Children = mod.MatchChildren(Inst.Parent, PropertiesTbl)
		if #Children > 0 then
			Matched = Children
			break
		else
			Inst = Inst.Parent
		end
	end

	return Matched
end

function mod.ApplyProperties(Part, Preset--[[Preset Or Your own.]])
	for i,v in pairs(Preset)do
		Part[i] = v
	end
end

-- takes a full name (:GetFullName() > "Workspace.thing.thing")
-- waits for all things
function mod.WaitForChildPath(startInstance, path, serperator)
	serperator = serperator or "."

	local objects = string.split(path, serperator)
	local lastObject = startInstance
	for _, q in pairs(objects)do
		lastObject = lastObject:WaitForChild(q)
		if not lastObject then
			return nil
		end
	end
	return lastObject
end
function mod.FindFirstChildPath(startInstance, path, serperator)
	serperator = serperator or "."

	local objects = string.split(path, serperator)
	local lastObject = startInstance
	for _, q in pairs(objects)do
		lastObject = lastObject:FindFirstChild(q)
		if not lastObject then
			return nil
		end
	end
	return lastObject
end

function mod.GetFullName(inst, serperator)
	if not inst then
        return ""
    end

	serperator = serperator or "."

    local fullName = inst.Name
    local parent = inst.Parent

    while parent and parent ~= game do
        fullName = parent.Name .. serperator .. fullName
        parent = parent.Parent
    end

    return fullName
end

function mod.FindParentWhichIsA(inst, class)
	while inst and inst.Parent do
		if inst.Parent:IsA(class) == false then
			return inst
		end

		inst = inst.Parent
	end

	return nil
end

local LOADED_TIMEOUT = 6

function mod.WaitForPrimaryPart(inst)
	local primary = inst.PrimaryPart

	if not primary then
		local fired = false
		task.spawn(function()
			task.wait(LOADED_TIMEOUT)
			if not fired then
				warn("PrimaryPart not a part of ", inst:GetFullName())
			end
		end)

		inst:GetPropertyChangedSignal("PrimaryPart"):Wait()
		fired = true
		primary = inst.PrimaryPart
	end

	return primary
end

function mod.OnPrimaryPart(inst, callback)
	local primary = inst.PrimaryPart

	if not primary then
		local fired = false
		task.spawn(function()
			task.wait(LOADED_TIMEOUT)
			if not fired then
				warn("PrimaryPart not a part of ", inst:GetFullName())
			end
		end)

		inst:GetPropertChangedSignal("PrimaryPart"):Once(function()
			fired = true
			callback(inst.PrimaryPart)
		end)
	end

	task.spawn(callback, primary)
end

local clientNeedIncrement = 0

function mod.ClientsNeed(inst, descendants)
	clientNeedIncrement += 1
	local thisinc = tostring(clientNeedIncrement)
	
	for i, v in descendants do
		v:SetAttribute("DescNum" .. thisinc, i)
	end

	-- Number of Descendants Replicating
	inst:SetAttribute("NumDescRep", tostring(#descendants) .. ":" .. thisinc)
end

function mod.OnAllLoaded(inst: Instance, callback)
	task.spawn(function()
		local start = tick()

		local numToLoad = inst:GetAttribute("NumDescRep")
		if not numToLoad then
			inst:GetAttributeChangedSignal("NumDescRep"):Wait()
			numToLoad = inst:GetAttribute("NumDescRep")
		end
		
		local tb = string.split(numToLoad, ":")
		numToLoad = tonumber(tb[1])
		local increment = tb[2]
		
		
		local descName = "DescNum" .. increment
		
		local numLoaded = 0
		local loadedList = {}
		local function tryAdd(v)
			local descNum = v:GetAttribute(descName)
			if descNum then
				numLoaded += 1
				loadedList[descNum] = v
			end
		end

		for _, v in inst:GetDescendants() do
			tryAdd(v)
		end

		if numLoaded < numToLoad then
			local c;c = inst.DescendantAdded:Connect(function(v)
				tryAdd(v)

				if numLoaded >= numToLoad then
					c:Disconnect()

					callback(loadedList)
				elseif tick() - start > LOADED_TIMEOUT then
					warn("Load instances timedout on", inst:GetFullName())
					c:Disconnect()
				end
			end)
		else
			callback(loadedList)
		end
	end)
end

return mod

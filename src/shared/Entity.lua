--[[
		:SpawnFunc(function(target_entity)

		end)
		:DamageFunc(function(target_entity, source_entity, amount)

		end)
		:HealFunc(function(target_entity, source_entity, amount)

		end)
		:RepairFunc(function(target_entity, source_entity, amount)

		end)
		:KillFunc(function(target_entity, source_entity)

		end)
		:HitFunc(function(target_entity, proj, position, offset, hit_dir, instance)

		end)
		:InExplosionFunc(function(target_entity, source_entity, position, percentDistance)

		end)
		:CheckForLimbKillFunc(function(target_entity, source_entity)

		end)
		:CanBeHurtFunc(function(target_entity)

		end)
		:DoesPartConnectFunc(function(target_entity, part)

		end)
		:DestroyFunc(function(target_entity)

		end)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Instances
local Game

local ImpulseTransmitter

local AddedCallbacks = {}
local EntityTypes = {}
local Entities = {}
local EntitiesByID = {}

local lastId = 0

local Meta = _G.Game.Meta

local NO_HEALTH_BARS = {
	Character = true,
	RagDoll = true,
	Horse = true,
	Tree = true,
}

local Entity = {}

local mt_EntityBuilder = Meta.FUNCTIONAL_METATABLE()
	:METHOD("SpawnFunc", function(self, func)
		self.__Spawn = func
		return self
	end)
    :METHOD("DamageFunc", function(self, func)
		self.__Damage = func
		return self
	end)
	:METHOD("HealFunc", function(self, func)
		self.__Heal = func
		return self
	end)
	:METHOD("RepairFunc", function(self, func)
		self.__Repair = func
		return self
	end)
	:METHOD("KillFunc", function(self, func)
		self.__Kill = func
		return self
	end)
	:METHOD("HitFunc", function(self, func)
		self.__Hit = func
		return self
	end)
	:METHOD("InExplosionFunc", function(self, func)
		self.__InExplosion = func
		return self
	end)
	:METHOD("CheckForLimbKillFunc", function(self, func)
		self.__CheckForLimbKill = func
		return self
	end)
	:METHOD("CanBeHurtFunc", function(self, func)
		self.__CanBeHurt = func
		return self
	end)
	:METHOD("DoesPartConnectFunc", function(self, func)
		self.__DoesPartConnect = func
		return self
	end)
	:METHOD("DestroyFunc", function(self, func)
		self.__Destroy = func
		return self
	end)
	:METHOD("DefaultMaxHealth", function(self, maxHealth)
		self.__MaxHealth = maxHealth
		return self
	end)
    :FINISH()

function Entity.registerType(name)
	assert(EntityTypes[name] == nil, "Reused entity type name: " .. name)
    local entityType = {

    }

    EntityTypes[name] = entityType
    setmetatable(entityType, mt_EntityBuilder)

    return entityType
end

function Entity.new(model, sourcePlayer, entityType, ...)
	lastId += 1

	model:SetAttribute("EntityID", lastId)
	model:SetAttribute("EntityType", entityType)

	if sourcePlayer then
		model:SetAttribute("SourcePlayer", sourcePlayer.Name)
	end

	model:SetAttribute("MaxHealth", EntityTypes[entityType].__MaxHealth)
	model:SetAttribute("Health", EntityTypes[entityType].__MaxHealth)

	CollectionService:AddTag(model, entityType)
	CollectionService:AddTag(model, "Entity")

	local newEntity = {
		ID = lastId,
		Type = entityType,

		Model = model,

		Team = false,
		SourcePlayer = sourcePlayer,

		-- BOID AI, change as needed.
		Radius = 1,
		Weight = 1,

		Events = {
			Killed = {},
		}
	}

	setmetatable(newEntity, {
		__index = EntityTypes[entityType],
	})

	Entities[model] = newEntity
	EntitiesByID[newEntity.ID] = newEntity

	if newEntity.__Spawn then
		newEntity:__Spawn(...)
	end

	return newEntity
end

function Entity.GetByID(id)
	return EntitiesByID[id]
end

function Entity.PoolPlayer(sourcePlayer, entityType, subType)
	local ret = {}

	for model, entity in pairs(Entities) do
		if sourcePlayer and entity.SourcePlayer ~= sourcePlayer then
			continue
		end
		if entityType and entity.Type ~= entityType then
			continue
		end
		if subType and not CollectionService:HasTag(entity.Model, subType) then
			continue
		end

		table.insert(ret, entity)
	end

	return ret
end

local function fireEvents(name, target_entity, ...)
	for _, event in target_entity.Events[name] do
		event:Fire()
	end
end

function Entity.Distance(entity, other_entity)
	return (entity.Model.PrimaryPart.Position - other_entity.Model.PrimaryPart.Position).Magnitude
end

function Entity.Impulse(target_entity, direction, speed)
	local part = target_entity.Model.PrimaryPart

	local impulse = part.AssemblyMass * direction * speed

	local function get_network_owner(part)
		return part:GetNetworkOwner()
	end

	local success, owner = pcall(get_network_owner, part)
	if not success then return end

	if owner == nil then
		part:ApplyImpulse(impulse)
	else
		ImpulseTransmitter:Transmit(owner, part, impulse)
	end
end

function Entity.ImpulseSimple(target_entity, impulse)
	local part = target_entity.Model.PrimaryPart

	local owner = part:GetNetworkOwner()
	if owner == nil then
		part:ApplyImpulse(impulse)
	else
		ImpulseTransmitter:Transmit(owner, part, impulse)
	end
end

function Entity.ClampHeal(maxHealth, health, amount)
	return math.ceil(math.min(maxHealth - health, amount))
end

function Entity.IsMaxHealth(entity)
	return entity.Model:GetAttribute("Health") >= entity.Model:GetAttribute("MaxHealth")
end

function Entity.Damage(target_entity, source_entity, amount)
	if target_entity.__Damage then
		if Entity.CanEntitysInteract(target_entity, source_entity) then

			if CollectionService:HasTag(target_entity.Model, "Cloaked") then
				CollectionService:RemoveTag(target_entity.Model, "Cloaked")
			end

			local health = target_entity.Model:GetAttribute("Health")
			local newHealth
			
			amount = math.ceil(amount)
			
			if amount >= health then
				amount = health
				newHealth = 0
			else
				newHealth = health - amount
			end

			target_entity.Model:SetAttribute("Health", newHealth)

			local isKill = newHealth <= 0

			target_entity:__Damage(source_entity, amount, isKill)

			local killRet
			if isKill then
				killRet = Entity.Kill(target_entity, source_entity)
			end

			return amount, killRet
		end
	end
end

function Entity.Heal(target_entity, source_entity, amount)
	if target_entity.__Heal then
		if Entity.CanEntitysInteract(target_entity, source_entity) then
			local maxHealth = target_entity.Model:GetAttribute("MaxHealth")
			local health = target_entity.Model:GetAttribute("Health")

			amount = Entity.ClampHeal(maxHealth, health, amount)

			target_entity.Model:SetAttribute("Health", health + amount)

			target_entity:__Heal(source_entity, amount)

			return amount
		end
	end
end

-- this function is the same as heal, but the callers are different
function Entity.Repair(target_entity, source_entity, amount)
	if target_entity.__Repair then
		local maxHealth = target_entity.Model:GetAttribute("MaxHealth")
		local health = target_entity.Model:GetAttribute("Health")

		amount = Entity.ClampHeal(maxHealth, health, amount)

		target_entity.Model:SetAttribute("Health", health + amount)

		target_entity:__Repair(source_entity, amount)

		return amount
	end
end

function Entity.Kill(target_entity, source_entity)
	fireEvents("Killed", target_entity)

	if target_entity.__Kill then
		return target_entity:__Kill(source_entity)
	end
end

function Entity.KilledEvent(target_entity)
	local event = Instance.new("BindableEvent")
	table.insert(target_entity.Events.Killed, event)

	return event.Event
end

function Entity.Hit(target_entity, source_entity, proj, position, offset, hit_dir, instance)
	if target_entity.__Hit then
		if Entity.CanEntitysInteract(target_entity, source_entity) then
			target_entity:__Hit(source_entity, proj, position, offset, hit_dir, instance)
		end
	end
end


function Entity.InExplosion(target_entity, source_entity, position, percentDistance)
	if target_entity.__InExplosion then
		if Entity.CanEntitysInteract(target_entity, source_entity) then
			target_entity:__InExplosion(source_entity, position, percentDistance)
		end
	end
end

function Entity.CheckForLimbKill(target_entity, source_entity)
	if target_entity.__CheckForLimbKill then
		local ret = target_entity:__CheckForLimbKill(source_entity)
		if ret then
			return true, ret
		end
		return false
	end
end

function Entity.DoesPartConnect(target_entity, part)
	if target_entity.__DoesPartConnect then
		return target_entity:__DoesPartConnect(part)
	end
	return true
end

function Entity.CanBeHurt(target_entity)
	if target_entity.Model:FindFirstChildWhichIsA("ForceField") then
		return false
	end

	if target_entity.__CanBeHurt then
		local success, result = pcall(function()
			return target_entity:__CanBeHurt()
		end)

		if success then
			return result
		end
		return false
	end
	return true
end

function Entity.Destroy(target_entity)
	if target_entity.Destroyed == true then
		warn("Multi-delete of an entity\n", debug.traceback())
		return
	end

	target_entity.Destroyed = true
	Entities[target_entity.Model] = nil
	EntitiesByID[target_entity.ID] = nil
	
	CollectionService:RemoveTag(target_entity.Model, "Entity")
	CollectionService:RemoveTag(target_entity.Model, target_entity.Type)
	
	if target_entity.__Destroy then
		target_entity:__Destroy()
	end
	
	target_entity.Model:Destroy()
	target_entity.Model = nil

	for _, t in pairs(target_entity.Events) do
		for i, e in pairs(t) do
			t[i] = nil
			e:Destroy()
		end
	end
end

function Entity.GetAll()
	--[[ for i,v in Entities do
        if v.Model.PrimaryPart == nil then
            warn(v.Model.Name, v.Model.Parent)
        end
    end ]]
	
	return Entities
end

function Entity.GetFromPlayer(plr)
	return Entities[plr.Character]
end

function Entity.GetFromPart(part, optType)
	-- if optType is passed, an entity will only be returned if the part belongs to an entity of that type.
	local model

	if optType then
		model = Instances.GetParentWhichHasTag(part, optType)
	else
		for name, v in pairs(EntityTypes) do
			model = Instances.GetParentWhichHasTag(part, name)
			if model then
				break
			end
		end
	end

	if model then
		local entity = Entities[model]
		if Entity.DoesPartConnect(entity, part) then
			return entity
		end
	end
end

function Entity.CanEntitysInteract(target_entity, source_entity)
	if source_entity then
		local source_team = source_entity.Team

		if not source_team.CanHurt then
			return false
		end
	end

	if not Game.GameState.CanHurt then
		return false
	end

	if not Entity.CanBeHurt(target_entity) then
		return false
	end

	return true
end

function Entity.MakeInvincible(char, t)
	local ff = char:FindFirstChildWhichIsA("ForceField")
	local ffh = char:FindFirstChild("InvincibleHighlight")

	if t == 0 then
		if ff then
			ff:Destroy()
		end
		if ffh then
			ffh:Destroy()
		end

		return
	end

	local newff = Instance.new("ForceField")
	newff.Visible = false
	newff.Parent = char

	local newffh = ReplicatedStorage.InvincibleHighlight:Clone()
	newffh.Parent = char

	if ff then
		ff:Destroy()
	end
	if ffh then
		ffh:Destroy()
	end

	Debris:AddItem(newff, t)
	Debris:AddItem(newffh, t)
end

function Entity.RemoveAll()
	for model, entity in pairs(Entities) do
		if entity.Type ~= "Character" then
			Entity.Destroy(entity)
		end
	end
end

function Entity.Added(tag, callback)
	if Game.CONTEXT ~= "CLIENT" then
		return
	end

	table.insert(AddedCallbacks, {
		Tag = tag,
		Callback = callback,
	})

	for model, entity in Entities do
		if CollectionService:HasTag(model, tag) then
			task.spawn(callback, entity)
		end
	end
end

function Entity:__init(G)
	Game = G
	Instances = G.Load("Instances")
end

function Entity:__run(G)
	if G.CONTEXT ~= "CLIENT" then
		return
	end

	local function entity_model_added(model)
		local ty = model:GetAttribute("EntityType")	
		-- a little sloppy, but just so we know on the client types worth itterating over, lazily.
		EntityTypes[ty] = true

		local healthBar
		if (not NO_HEALTH_BARS[ty]) then-- overall types

			-- subtypes
			local noBar = false
			for tag, _ in NO_HEALTH_BARS do
				if CollectionService:HasTag(model, tag) then
					noBar = true
					break
				end
			end

			if not noBar then
				healthBar = HealthBars.new(model)
			end
		end

		local t = {
			ID = model:GetAttribute("EntityID"),
			SourcePlayer = model:GetAttribute("SourcePlayer"),
			Model = model,

			Cleanups = {},
			HealthBar = healthBar,
		}
		Entities[model] = setmetatable(t, mt_Entity)

		for _, obj in pairs(AddedCallbacks) do
			if CollectionService:HasTag(model, obj.Tag) then
				obj.Callback(Entities[model])
			end
		end
	end

	--CollectionService:GetInstanceAddedSignal("Entity"):Connect(entity_model_added)
	CollectionService:GetAttributeChangedSignal("EntityType"):Connect(entity_model_added)

	for _, model in pairs(CollectionService:GetTagged("Entity")) do
		task.spawn(entity_model_added, model)
	end

	-- Also fires when model with the tag is destroyed
	CollectionService:GetInstanceRemovedSignal("Entity"):Connect(function(model)
		local entity = Entities[model]

		if entity then
			Entities[model] = nil

			if entity.HealthBar then
				entity.HealthBar:Destroy()
			end

			for _, cleanup in entity.Cleanups do
				cleanup(entity)
			end
		end
	end)
end

function Entity:__build_signals(G, B)
	ImpulseTransmitter = B:NewTransmitter("ImpulseTransmitter")
		:ClientConnection(function(part, impulse)
			part:ApplyImpulse(impulse)
		end)
end

return Entity


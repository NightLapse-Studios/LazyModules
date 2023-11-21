local RunService = game:GetService("RunService")
local ReplicatedFirst = game.ReplicatedFirst

local Game
local Entity
local Abilities
local Vectors = _G.Game.PreLoad(ReplicatedFirst.Modules.Vectors)
local RayCasting = _G.Game.PreLoad(ReplicatedFirst.Modules.RayCasting)
local Config = _G.Game.PreLoad(ReplicatedFirst.Util.BUILDCONFIG)
local SL = _G.Game.PreLoad(ReplicatedFirst.Util.SparseList)
local CRC = _G.Game.PreLoad(ReplicatedFirst.Util.CRC32)

local module = {
	Debug = false,
	TimeScale = 1,

	Presets = {
		Generic = 1,
		AoE = 2,
		Unmanaged = 3
	},

	Generics = {
		MoveFn = function (cmpnt, dt)
			local old_cf: CFrame = cmpnt.Model.PrimaryPart:GetPivot()

			local rot = (cmpnt.RotVel * dt)
			rot = cmpnt.AccumulatedRotation * CFrame.Angles(rot.X, rot.Y, rot.Z)
			cmpnt.AccumulatedRotation = rot

			local vel: Vector3 = cmpnt.Velocity * dt

			local old_pos = old_cf.Position
			local new_pos = old_pos + vel
			local delta_pos = new_pos - old_pos

			local new_cf = CFrame.new(new_pos, new_pos + (delta_pos.Unit)) * rot

			cmpnt.Model:PivotTo(new_cf)

			return old_cf, new_cf
		end,

		CollisionCheckFn = function(cmpnt, old_cf, new_cf)
			local exclude = { }
			if cmpnt.__Usage then
				local addexclude = {cmpnt.__Usage.Ability:ResolveState("Exclude", cmpnt.__Usage.Owner, cmpnt.__Usage, cmpnt)}
				exclude = { cmpnt.__Usage.Owner.Character, table.unpack(addexclude) }
				for _,v in cmpnt.StickExcludes do
					table.insert(exclude, v)
				end
			end

			local to, from = old_cf.Position, new_cf.Position

			local params = RayCasting.GetRaycastParamsBL("Barriers", exclude)
			local result = workspace:Raycast(to, from - to, params)

			return result
		end,

		IsFinishedFn = function(cmpnt)
			return cmpnt.Model.PrimaryPart.Position.Y < -300
		end,

		CleanupFn = function(cmpnt)
			cmpnt.Model:Destroy()
		end
	}
}

local ComponentHitTransmitter
local ComponentFiredTransmitter
local ProjFiredGE

local ComponentTypes = { }

local Component = { }
Component.__index = Component

local Cmpnts = SL.new()

local ComponentFolder = Instance.new("Folder", workspace)
local ServerComponentFolder = Instance.new("Folder", game.ServerStorage)
ComponentFolder.Name = "Components"
ServerComponentFolder.Name = "Components"

local META_CONTEXTS = _G.Game.Enums.META_CONTEXTS
local ComponentBuilder = _G.Game.Meta.CONFIGURATOR(Component)
	:SETTER(META_CONTEXTS.BOTH, "MoveFn", "__MoveFn")
	:SETTER(META_CONTEXTS.BOTH, "VelocityUpdate", "__VelocityUpdateFn")
	:SETTER(META_CONTEXTS.BOTH, "CollisionCheckFn", "__CollisionCheckFn")
	:SETTER(META_CONTEXTS.AUTO, "CleanupFn", "__CleanupFn")
	:SETTER(META_CONTEXTS.AUTO, "CollisionHandlerFn", "__CollisionHandlerFn")
	:SETTER(META_CONTEXTS.AUTO, "CollisionEffectFn", "__CollisionEffectFn")
	:SETTER(META_CONTEXTS.BOTH, "IsFinishedFn", "__IsFinishedFn")
	:SETTER(META_CONTEXTS.CLIENT, "LifeCycleFn", "__LifeCycleFn")
	:SETTER(META_CONTEXTS.SERVER, "IsHitValidFn", "__IsHitValid")
	:SETTER(META_CONTEXTS.AUTO, "OnHitFn", "__OnHitFn")
	:FINISH()

function Component:Fire(opt_usage, model, speed: number, rot_velocity: Vector3, opt_proj_id: number?)
	if opt_proj_id then
		assert(Game.CONTEXT == "SERVER")
		assert(typeof(opt_proj_id) == "number")
	end

	local cmpnt = table.clone(self)

	local primary_part: BasePart = model.PrimaryPart
	
	if not primary_part then
		warn("Component fired with invalid or destroyed model: " .. model.Name)
		return
	end
	
	local origin_cf = primary_part:GetPivot()

	cmpnt.Model = model
	cmpnt.Speed = speed
	cmpnt.Velocity = origin_cf.LookVector * speed
	cmpnt.RotVel = rot_velocity
	cmpnt.Origin = origin_cf
	cmpnt.CreationTime = tick()
	cmpnt.LastUpdateTime = tick()

	cmpnt.StickExcludes = {}-- exclude from raycasting ragdolls that we stuck to our cmpnt
	cmpnt.StickTransfers = {}-- server side

	if opt_usage then
		cmpnt.ID = opt_usage:OwnComponent(cmpnt, opt_proj_id)
		cmpnt.__Usage = opt_usage
	end

	if Game.CONTEXT == "CLIENT" then
		if not model.Parent then-- doesnt anchor swords for example
			model.Parent = ComponentFolder
			model.PrimaryPart.Anchored = true
		end
	else
		-- This is used to trigger cmpnt deleting in the case that a usage is canceled
		-- The cancelation will destroy the model, causing it to be detected as an invalid cmpnt
		opt_usage:OwnInstance(cmpnt.Model)
		model.Parent = ServerComponentFolder
	end

	cmpnt.Idx = Cmpnts:insert(cmpnt)

	if (cmpnt.__Usage and Game.CONTEXT == "CLIENT") and (cmpnt.__Usage.Owner == game.Players.LocalPlayer) then
		ProjFiredGE:Fire(cmpnt, cmpnt.__Usage.Owner)
		assert(cmpnt.ID ~= -1)
		ComponentFiredTransmitter:Transmit(cmpnt.__UUID, cmpnt.__Usage.ID, cmpnt.ID, cmpnt.Origin, cmpnt.Speed, cmpnt.RotVel)
	end

	return cmpnt
end

function Component:SetUsage(usage)
	self.__Usage = usage

	return self
end

local function apply_preset(cmpnt, preset)
	if preset == module.Presets.Unmanaged then
		cmpnt.__Move = Game.no_op_func
		cmpnt.__UpdateVelocity = Game.no_op_func
		cmpnt.__ServerCollisionEffect = false
	end

	cmpnt.Preset = preset
end

function Component:SetPreset(preset)
	apply_preset(self, preset)
	return self
end

function Component:Destroy(opt_collision)
	assert(self.Idx)
	Cmpnts:remove(self.Idx)

	self.Collided = true

	if self.__CleanupFn then
		self:__CleanupFn(opt_collision)
	end

	if self.__Usage then
		self.__Usage:DisownComponent(self.ID)
	end
end

local function new_soft_proj(preset)
	local cmpnt = {
		ID = -1,
		Idx = -1,
		Preset = preset,
		Model = false,

		Speed = false,
		Velocity = false,
		RotVel = false,

		Damage = 0,

		CreationTime = -1,
		LastUpdateTime = -1,

		-- This cannot be relied on to get the orientation of a projetile's direction
		-- However it does determine the orientation of the model as it is originally placed
		Origin = false,
		AccumulatedRotation = CFrame.Angles(0,0,0),
		Collided = false,

		--A buffer to save some data such that the below functions see as fit
		-- e.g. forming a list of players that have already been hit, so as to not hit them again
		-- not intended for server use
		ScratchBuffer = { },

		__MoveFn = generic_move_func,
		__CollisionCheckFn = generic_collision_check,
		__IsFinishedFn = generic_is_finished,

		__CleanupFn = false,
		__VelocityUpdateFn = false,
		__CollisionHandlerFn = false,
		__CollisionEffectFn = false,
		__LifeCycleFn = false,
		__OnHitFn = false,
		__IsHitValid = false,

		__Usage = false,
		__UUID = -1,
	}

	apply_preset(cmpnt, preset)

	if RunService:IsServer() then
		cmpnt.__CleanupFn = cleanup_server_proj
	end

	return setmetatable(cmpnt, ComponentBuilder)
end

--[[
	A model is expected to be placed at its starting position and orientation prior to calling this function
	if `opt_usage` is not supplied, then the component will remain local and can only interact with the world
		cosmetically i.e. `Effects.BloodSplash`
]]
function module.new(preset, opt_salt)
	preset = preset or module.Presets.Generic
	opt_salt = opt_salt or ""
	local cmpnt = new_soft_proj(preset)

	local src: string, line: string, num: string = debug.info(2, "sln")
	src = opt_salt .. src .. line .. num
	local uuid = CRC.Hash(src)

	local existing_type = ComponentTypes[uuid]
	assert(existing_type == nil,
		"If this happens, it means we need to upgrade the hash function, or come up with a scheme to modify the hash that will stay in sync across client and server")
	ComponentTypes[uuid] = cmpnt

	cmpnt.__UUID = uuid

	return cmpnt
end

local use_dbg_step = false
local dbg_step = true
local function dbg_ticker()
	dbg_step = false
	task.wait(0.25)
	dbg_step = true
end

function module.Update(_dt)
	local t = tick()
	if use_dbg_step then
		if dbg_step == false then
			return
		end
		coroutine.resume(coroutine.create(dbg_ticker))
	end

	for i, cmpnt in Cmpnts.Contents do
		if not cmpnt.Model.Parent then
			-- Components which are unparented without destruction might be a big issue
			Cmpnts:remove(i)
			continue
		end

		local dt = t - cmpnt.LastUpdateTime
		cmpnt.LastUpdateTime = t

		-- Custom __VelocityUpdateFn func, otherwise gravity is applied by default
		if cmpnt.__VelocityUpdateFn then
			cmpnt:__VelocityUpdateFn(dt)
		else
			cmpnt.Velocity += Config.Gravity * dt
		end
		-- How to move
		local old_cf, new_cf = cmpnt:__MoveFn(dt)

		-- The server only tracks positioning
		if Game.CONTEXT == "SERVER" then
			continue
		end

		--_G.Game.TempMarkSpotDbg(new_cf.Position, 1, nil, Vector3.new(0.2, 0.2, 0.2))

		-- How to determine if the component has collided
		local collision: RaycastResult? = cmpnt:__CollisionCheckFn(old_cf, new_cf)

		--Two types of behavior below
		-- 1. A cmpnt may finish if it has collided and __CollisionHandlerFn returns true
		--	  (default is to finish if it has collided)
		-- 2. A cmpnt may finish for some reason that it calculates with __IsFinishedFn
		--	  (not necessary if the only dependency is if the component has collided)
		local should_finish = false
		if collision and collision.Position then
			should_finish = true
			
			local collision_normal
			-- Some components don't move so they don't return anything from __Move
			-- but they still collide and junk
			if new_cf and old_cf then
				collision_normal = new_cf.Position - old_cf.Position
			else
				collision_normal = collision.Normal
			end

			if cmpnt.__CollisionHandlerFn then
				should_finish = cmpnt:__CollisionHandlerFn(collision, collision_normal)
			end

			if cmpnt.__CollisionEffectFn then
				cmpnt:__CollisionEffectFn(collision, collision_normal, should_finish)
			end

			if cmpnt.__OnHitFn then
				cmpnt:__OnHitFn(collision, collision_normal, should_finish)
			end
		end

		-- __IsFinishedFn has the ability to finish the component for ADDITIONAL reasons, but will not override a case
		-- where collision has decided it will finish the component
		if cmpnt.__IsFinishedFn then
			should_finish = if should_finish then true else cmpnt:__IsFinishedFn(collision)
		end

		-- Clean up based on the the above steps
		-- The __CleanupFn function should make sure anything within Proj.__Usage.Allocated is destroyed
		-- Proj.__Usage.Allocated is expected to be filled with instances, but this behavior is not enforced
		if should_finish then
			cmpnt:Destroy()
		elseif cmpnt.__LifeCycleFn then
			-- Modifies the component in arbitrary ways.
			-- The intent is to arbitrarily change how the component looks, not behaves
			cmpnt:__LifeCycleFn(dt)
		end
	end
end


function module:__init(G)
	Game = G
	Abilities = G.Load("Abilities")
	Entity = G.Load("Entity")

	local UserInput

	local function make_dbg_stepper()
		local Input = game:GetService("UserInputService")
		Input.InputBegan:Connect(function(thing)
			if thing.KeyCode == Enum.KeyCode.Y then
				use_dbg_step = true
			end
		end)
	end

	local stepper = G.ContextVar(false, make_dbg_stepper, false, false)
	if stepper then stepper() end

--[[ 	if RunService:IsStudio() then
		-- Debug feature that shoots a component infront of you aimed at you.

		local ProjType = module.new(module.Presets.Generic)
			:SetCleanup(function(cmpnt)
				cmpnt.Model:Destroy()
			end)
			:SetCollisionFunc(function(cmpnt, old_cf, new_cf)
				local to, from = old_cf.Position, new_cf.Position

				local exclude = {}
				for _,v in cmpnt.StickExcludes do
					table.insert(exclude, v)
				end

				local params = RayCasting.GetRaycastParamsBL("Barriers", exclude)
				local result = workspace:Raycast(to, from - to, params)

				return result
			end)

		module.DebugAbility = Abilities.new("DebugAbility", "idk")
			:ArmFunc(_G.Game.Enums.META_CONTEXTS.CLIENT, function(self)

				UserInput:Handler(
					Enum.KeyCode.Seven,
					function()
						self:Use()
					end
				)
			end)
			:UseFunc(_G.Game.Enums.META_CONTEXTS.CLIENT, function(usage, use_args)
				local new_model = game.ReplicatedStorage.BuildModels.Ballista.ProjModel:Clone()

				new_model:SetPrimaryPartCFrame(use_args[1])

				ProjType:Fire(usage, new_model, use_args[2], Vector3.new(0, 0, math.pi * 6))
			end)
			:GetUseArgs(function(plr, usage)
				local cf = plr.Character.PrimaryPart.CFrame

				local pos = CFrame.new((cf * CFrame.new(0, 0, -20)).Position, cf.Position)
				local speed = 100

				return pos, speed
			end)
			:AddResolvableState("Damage", function(self, plr, usage, hit_pos, hit_distance)
				return 20
			end)
			:AddResolvableState("DismembermentMultiplier", function(self, plr, usage, hit_pos)
				return -0.5
			end)
			:AddResolvableState("StickOnDeath", function(self, plr, usage, target_entity)
				local yes = target_entity and CollectionService:HasTag(target_entity.Model, "Character")
				return yes
			end)
			:ShouldAccept(function(plr, ability, args)
				return true
			end)
			:SetCooldown(1.0)
			:ChecksWeaponCompatibility(false)
			:GetComponentModel(function()
				return game.ReplicatedStorage.BuildModels.Ballista.ProjModel
			end)
			:FINISH()

		if RunService:IsClient() then
			module.DebugAbility:Arm(Players.LocalPlayer)
		end
	end ]]
end

function module:__build_signals(G, B)
	-- This transmitter is only used to associate projectiles with usages
	ComponentHitTransmitter = B:NewTransmitter("ComponentHit")
		:ServerConnection(function(plr, instance, pos_of_hit, usage_id, cmpnt_id, offset)
			local usage = Abilities.Usages:get(plr)[usage_id]
			if not usage then
				warn("No usage", plr.UserId, usage_id, cmpnt_id)
				return
			end

			--print(usage)
			local cmpnt = usage.Components[cmpnt_id]
			if not cmpnt then
				warn("No component", plr.UserId, usage_id, cmpnt_id)
				return
			end

			if not instance then
				warn("No Hit part", plr.UserId, usage_id, cmpnt_id)
				return
			end

			local timeToTravel = tick() - cmpnt.CreationTime
			local directionCF: CFrame = cmpnt.Origin

			local originDir = directionCF.LookVector
			local cosmetic_hit_dir =
				Vector3.new(
					originDir.X * cmpnt.Speed,
					(originDir.Y * cmpnt.Speed + Config.Gravity.Y * timeToTravel),
					originDir.Z * cmpnt.Speed
				).Unit

			local target_entity = Entity.GetFromPart(instance)

			local ping = Game[plr].PlayerStats.Ping.Value / 1000

			-- Check the error caused by ping.
			local server_proj_pos = cmpnt.Model:GetPivot().Position

			local distanceToCalculated = (server_proj_pos - pos_of_hit).Magnitude

			local wiggle_room = usage.Ability:ResolveState("WiggleRoom", plr, usage, timeToTravel) or 0

			local speed = cmpnt.Speed
			
			if speed == 0 then
				speed = 16-- about walk speed for melee
			end
			
			local ping_wiggle_room = wiggle_room + speed * math.min(ping + 0.2, 1)
			if distanceToCalculated > ping_wiggle_room then
	--[[ 			if RunService:IsStudio() then
					G.MarkSpotDbg(calculatedPosition).Color = Color3.new(0,1,0)
					G.MarkSpotDbg(position).Color = Color3.new(1,0,0)
				end ]]

				warn("Proj rejected for innacuracy", plr.UserId, usage.Ability.Name, distanceToCalculated, ping_wiggle_room, ping)
				return
			end

			-- If the component actually moves (so, not swords), then ensure alignment at least
			local wiggle_room2 = usage.Ability:ResolveState("AlignmentWiggleRoom", plr, usage, timeToTravel) or 0

			if cmpnt.Speed > 0 then
				local p1 = directionCF.Position
				local p2 = directionCF.Position + originDir
				local p3 = directionCF.Position + directionCF.UpVector

				local roundingError = Vectors.PointToPlaneDistance(pos_of_hit, p1, p2, p3)

				if roundingError > (0.2 + wiggle_room2) then
	--[[ 				if RunService:IsStudio() then
						G.VisualizePlane(p1, p2, p3, pos_of_hit)
					end ]]

					warn("Proj rejected for fake direction", plr.UserId, usage.Ability.Name, roundingError)
					return
				end
			end

			local simulationContinues = cmpnt.__CollisionHandlerFn(plr, cmpnt, pos_of_hit, offset, cosmetic_hit_dir, instance, target_entity)

			if simulationContinues then
				return
			end

			if cmpnt.__CollisionEffectFn then
				cmpnt.__CollisionEffectFn(plr, cmpnt, pos_of_hit, offset, cosmetic_hit_dir, instance, target_entity)
			end

			if cmpnt.__OnHitFn then
				cmpnt:__OnHitFn(instance, cosmetic_hit_dir)
			end
		end)

	ComponentFiredTransmitter = B:NewTransmitter("ComponentFired")
		:ServerConnection(function(plr, cmpnt_type_id, usage_id, proj_id, proj_cf, speed, rot_velocity)
			local usage = Abilities.Usages:get(plr)[usage_id]
			if not usage then
				warn("No usage", plr.UserId, usage_id, proj_id)
				return
			end

			local componenet_model = usage:GetComponentModel()
			local model = componenet_model:Clone()

			model:PivotTo(proj_cf)

			local cmpnt = ComponentTypes[cmpnt_type_id]
			assert(cmpnt)
			cmpnt = cmpnt:Fire(usage, model, speed, rot_velocity, proj_id)

			if usage.Ability.Interface then
				usage.Ability.Interface.ConsumeComponentAbilities(usage)
			end
		end)

	ProjFiredGE = B:NewGameEvent("Fired", "Component")
end


local Camera = workspace.CurrentCamera
local VectorLib = _G.Game.PreLoad(game.ReplicatedFirst.Modules.Vectors)
local PlayerStats = _G.Game.PreLoad(game.ReplicatedFirst.Modules.PlayerStats)

function module.GetWorldSpaceVelocity(cf: CFrame, speed: number): Vector3
	local velocity = cf.LookVector * speed
	return velocity
end

function module.GetDirectionFromMouseHit(pos: Vector3, hitless: boolean?)
	local hit = if hitless then false else (Game.RaycastResultNPUnCapped and Game.RaycastResultNPUnCapped.Position)
	local hitpos = hit or Camera.CFrame.Position + Camera.CFrame.LookVector * 2000

	if VectorLib.IsPosBehindCF(game.Players.LocalPlayer.Character.PrimaryPart.CFrame, hitpos) then
		hitpos = Camera.CFrame.Position + Camera.CFrame.LookVector * 2000
	end

	local cf: CFrame = CFrame.new(pos, hitpos)

	return cf
end

function module.GetSpreadRadiusAtTime(t: number, spread_amount: number)
	local spread = t * spread_amount
	return spread
end

-- The worldspace vel is derived from dir and speed; spread_amount is *maximum distance* planarly-relative to the tip of the worldspace vel
function module.SpreadDirection(dir: CFrame, speed: number, spread_amount: number?, opt_rng): CFrame
	spread_amount = spread_amount or PlayerStats:GetStat("TargetSpread")
	local worldspace_vel = module.GetWorldSpaceVelocity(dir, speed)
	local offset = VectorLib.RandomPlanarOffset(worldspace_vel, spread_amount, opt_rng)

	local origin = dir.Position
	local point = origin + worldspace_vel + offset

	return CFrame.new(origin, point)
end

function module.ReportHit(cmpnt, rr: RaycastResult, dir: Vector3)
	local cf = CFrame.new(rr.Position, rr.Position + dir)
	local offset = rr.Instance.CFrame:ToObjectSpace(cf)
	ComponentHitTransmitter:Transmit(rr.Instance, rr.Position, cmpnt.__Usage.ID, cmpnt.ID, offset)
end

return module

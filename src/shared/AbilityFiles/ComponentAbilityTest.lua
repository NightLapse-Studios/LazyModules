--[[
	This file makes a component which uses all config options
	as well as an ability which uses all config options

	This file is useful for testing that the full configuration set is working
]]

local mod = { }

local Ability

local ComponentModel = Instance.new("Model")
local Part = Instance.new("Part", ComponentModel)
Part.Size = Vector3.new(1, 1, 1)
Part.Anchored = true
ComponentModel.PrimaryPart = Part

function mod:__tests(G, T)
	local Abilities = G.Load("Abilities")
	local Component = G.Load("Component")
	local UserInput = G.Load("UserInput")
	local Enums = G.Load("Enums")
	local META_CONTEXTS = Enums.META_CONTEXTS
	
	local Handler

	local ComponentType = Component.new()
		:MoveFn(function(cmpnt, dt)
			-- print("MoveFn")
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
		end)
		:VelocityUpdate(function(cmpnt, dt)
			-- print("VelocityUpdate")
		end)
		:CollisionCheckFn(function(cmpnt, old_cf, new_cf)
			-- print("CollisionCheckFn")
		end)
		:CleanupFn(META_CONTEXTS.CLIENT, function(cmpnt, collision: RaycastResult)
			cmpnt.Model:Destroy()
			-- print("Cleanup")
		end)
		:CleanupFn(META_CONTEXTS.SERVER, function(cmpnt, collision: RaycastResult)
			-- print("Cleanup")
		end)
		:CollisionHandlerFn(META_CONTEXTS.CLIENT, function(cmpnt, collision: RaycastResult, normal: Vector3)
			-- print("CollisionHandlerFn")
		end)
		:CollisionHandlerFn(META_CONTEXTS.SERVER, function(cmpnt, collision: RaycastResult, normal: Vector3)
			-- print("CollisionHandlerFn")
		end)
		:CollisionEffectFn(META_CONTEXTS.CLIENT, function(cmpnt, collision: RaycastResult, normal: Vector3, did_finish: boolean)
			-- print("CollisionEffectFn")
		end)
		:CollisionEffectFn(META_CONTEXTS.SERVER, function(cmpnt, collision: RaycastResult, normal: Vector3, did_finish: boolean)
			-- print("CollisionEffectFn")
		end)
		:IsFinishedFn(function(cmpnt, collision: RaycastResult)
			-- print("IsFinishedFn")

			if tick() - cmpnt.CreationTime > 2 then
				return true
			end

			return false
		end)
		:LifeCycleFn(function(cmpnt, dt)
			-- print("LifeCycleFn")
		end)
		:OnHitFn(META_CONTEXTS.CLIENT, function()
			-- print("OnHitFn")
		end)
		:OnHitFn(META_CONTEXTS.SERVER, function()
			-- print("OnHitFn")
		end)
		:IsHitValidFn(function()
			-- print("IsHitValidFn")
		end)
		:FINISH()

	Ability = Abilities.new("TestAbility", "yep")
		:SetCooldown(1.5)
		:ArmFn(META_CONTEXTS.CLIENT, function(ability, arm_args)
			-- print("ArmFn")
			Handler = UserInput:Handler(Enum.KeyCode.Q,
				function()
					Ability:Use()
				end
			)
		end)
		:ArmFn(META_CONTEXTS.SERVER, function(ability, arm_args)
			-- print("ArmFn")
			
		end)
		:DisarmFn(META_CONTEXTS.CLIENT, function(ability, arm_args)
			-- print("DisarmFn")
			Handler:Disconnect()
			Handler = nil
		end)
		:DisarmFn(META_CONTEXTS.SERVER, function(ability, arm_args)
			-- print("DisarmFn")
		
		end)
		:CanArmFn(function(ability, plr)
			-- print("CanArmFn")
			-- You can test out-of-sync abilities by making this return false
			-- It will be usable on the client, but instantly canceled when the server rejects the usage
			return true
		end)
		:ShouldAcceptFn(function(plr, ability, args)
			-- print("ShouldAccept")
			return true
		end)
		:UseFn(META_CONTEXTS.CLIENT, function(usage, args)
			-- print("UseFn")
			local cf = args[1]
			local model = ComponentModel:Clone()
			model:PivotTo(cf)
			ComponentType:Fire(usage, model, 100, Vector3.new(0, 0, 0))
		end)
		:UseFn(META_CONTEXTS.SERVER, function(usage, args)
			-- print("UseFn")
		end)
		:LateUseFn(function()
			-- print("LateUseFn")
		end)
		:GetUseArgsFn(function(plr, usage, external_args: {any})
			-- print("GetUseArgsFn")
			local cam_look = workspace.CurrentCamera.CFrame.LookVector
			local pos = plr.Character:GetPivot().Position
			local dir = pos + Vector3.new(cam_look.X, 0, cam_look.Z)
			local cf = CFrame.new(pos, dir)
			return cf
		end)
		:UpdateFn(function(usage, dt)
			-- print("UpdateFn")
		end)
		:CleanupFn(META_CONTEXTS.CLIENT, function(usage)
			-- print("CleanupFn")
		end)
		:CleanupFn(META_CONTEXTS.SERVER, function(usage)
			-- print("CleanupFn")
		end)
		:CancelOnDeath(true)
		:GetComponentModelFn(function()
			return ComponentModel
		end)
		-- :AddResolvableStateFn()
		:NoAutoReplication(false)
		:FINISH()

	if G.CONTEXT == "CLIENT" then
		-- Just use the ability to test it
		Ability:Arm()
	end
end

return mod
--[[
	This file makes a component which uses all config options
	as well as an ability which uses all config options

	This file is useful for testing that the full configuration set is working
]]

local mod = { }

local Ability

local FlowerModel = Instance.new("Model")
local Part = Instance.new("Part", FlowerModel)
Part.Size = Vector3.new(1, 1, 1)
Part.Anchored = true
Part.CanCollide = false
FlowerModel.PrimaryPart = Part

function mod:__init(G)
	local Abilities = G.Load("Abilities")
	local Component = G.Load("Component")
	local UserInput = G.Load("UserInput")
	local Enums = G.Load("Enums")
	local FieldSelector = G.Load("FieldSelector")
	local Style = G.Load("Style")

	local META_CONTEXTS = Enums.META_CONTEXTS
	
	local Selector
	local Handler

	Ability = Abilities.new("PlantSeeds", "yep")
		:SetCooldown(1.5)
		:ArmFn(META_CONTEXTS.CLIENT, function(ability, arm_args)
			local SelectorModel = FlowerModel:Clone()
			Selector = FieldSelector.new(game.Players.LocalPlayer, Enum.UserInputType.MouseButton1, SelectorModel, 5, 50)
			:SetCallback(function(self)
				if self:IsInRange() then
					Ability:Use()
					return true
				end

				return false
			end)
			:SetInRangeCallback(function(self, dist)
				self.SelectorModel.PrimaryPart.Color =  Style.FieldSelectorGreen
			end)
			:SetOutOfRangeCallback(function(self, dist)
				self.SelectorModel.PrimaryPart.Color =  Style.FieldSelectorRed
			end)
		end)
		:ArmFn(META_CONTEXTS.SERVER, function(ability, arm_args)
			
		end)
		:DisarmFn(META_CONTEXTS.CLIENT, function(ability, arm_args)
			Handler:Destroy()
			Selector:Destroy()
			Handler = nil
			Selector = nil
		end)
		:DisarmFn(META_CONTEXTS.SERVER, function(ability, arm_args)
		
		end)
		:CanArmFn(function(ability, plr)
			return true
		end)
		:ShouldAcceptFn(function(plr, ability, args)
			return true
		end)
		:UseFn(META_CONTEXTS.CLIENT, function(usage, args)
			local cf = args[1]
			local model = FlowerModel:Clone()
			model:PivotTo(cf)
			ComponentType:Fire(usage, model, 100, Vector3.new(0, 0, 0))
		end)
		:UseFn(META_CONTEXTS.SERVER, function(usage, args)
		end)
		:LateUseFn(function()
		end)
		:GetUseArgsFn(function(plr, usage, external_args: {any})
			local cam_look = workspace.CurrentCamera.CFrame.LookVector
			local cf = CFrame.new(plr.Character:GetPivot().Position, Vector3.new(cam_look.X, 0, cam_look.Z))
			return cf
		end)
		:UpdateFn(function(usage, dt)
		end)
		:CleanupFn(META_CONTEXTS.CLIENT, function(usage)
		end)
		:CleanupFn(META_CONTEXTS.SERVER, function(usage)
		end)
		:CancelOnDeath(true)
		:GetComponentModelFn(function()
			return FlowerModel
		end)
		:NoAutoReplication(false)
		:FINISH()
end

return mod
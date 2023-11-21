local Game
local Entity
local Items

local GroundItemPickupTransmitter
local PickUpDeniedTransmitter

local mod = { }

local GroundItems = { }

function mod:__init(G)
	Game = G
	Entity = G.Load("Entity")
	Items = G.Load("Items")

	Entity.registerType("GroundItem")
		:OnAddedFn(function(target_entity)
			GroundItems[target_entity.ID] = target_entity
		end)
		:OnSpawnFn(function(target_entity)
			GroundItems[target_entity.ID] = target_entity
		end)
		:OnDestroyFn(function(target_entity)
			GroundItems[target_entity.ID] = nil
		end)
		:CanBeHurtFn(function(target_entity)
			return false
		end)
end


function mod:__finalize(G)
	if G.CONTEXT == "CLIENT" then
		game:GetService("RunService").RenderStepped:Connect(function()
			for i,v in GroundItems do
				if v.Awaiting == true then
					continue
				end

				if (v.Model:GetPivot().Position - game.Players.LocalPlayer.Character:GetPivot().Position).Magnitude < 50 then
					mod.PickUp(game.Players.LocalPlayer, v.ID)
				end
			end
		end)
	end	
end

function mod.PickUp(plr, entity_id)
	local ground_entity = Entity.GetByID(entity_id)
	print("YEPPERS")
	if Game.CONTEXT == "CLIENT" then
		if ground_entity.Awaiting then
			return
		end

		ground_entity.Awaiting = true
		GroundItemPickupTransmitter:Transmit(entity_id)
	else
		local is_ok = Entity.CanEntitysInteract(ground_entity, Entity.GetFromPlayer(plr))

		if is_ok then
			local model = ground_entity.Model
			local item_id = model:GetAttribute("Item")
			local stack = model:GetAttribute("Stack")
			Game[plr].PlayerInventory:AddSync(Items.FromID[item_id], stack)

			Entity.Destroy(ground_entity)
		else
			PickUpDeniedTransmitter:Transmit(plr, entity_id)
		end
	end
end

local DebugTransmitter
local FlowerModel = Instance.new("Model")
local Part = Instance.new("Part", FlowerModel)
Part.Size = Vector3.new(1, 1, 1)
Part.Anchored = true
Part.CanCollide = false
FlowerModel.PrimaryPart = Part

function mod.Spawn(item_type, item_stack)
	local model = FlowerModel:Clone()
	model.Parent = game.Workspace
	model:PivotTo(CFrame.new(Vector3.new()))
	model:SetAttribute("Item", item_type.ID)
	model:SetAttribute("Stack", item_stack)
	Entity.new(model, nil, "GroundItem")
end

function mod:__build_signals(G, B)
	GroundItemPickupTransmitter = B:NewTransmitter("GroundItemPickupTransmitter")
		:ServerConnection(mod.PickUp)

	PickUpDeniedTransmitter = B:NewTransmitter("PickUpDeniedTransmitter")
		:ClientConnection(function(entity_id)
			local entity = Entity.GetByID(entity_id)
			entity.Awaiting = false
		end)

	DebugTransmitter = B:NewTransmitter("DebugTransmitter")
		:ServerConnection(function(plr) 
			mod.Spawn(Items.FromID[1], 2)
		end)

	if Game.CONTEXT == "CLIENT" then
		G.Load("UserInput"):Handler(Enum.KeyCode.E, function()
			DebugTransmitter:Transmit()
		end)
	end
end

return mod

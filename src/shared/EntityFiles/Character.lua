local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")

local Game
local Enums = _G.Game.Enums
local Instances
local Config
local SpawnHandler
local Entity

local PlayerKilled

local ResetRemoteRequest = Instance.new("RemoteEvent", game.ReplicatedStorage)
ResetRemoteRequest.Name = "ResetRemoteRequest"

local Character = {
	BuildingStageBounds = { },
}

function Character:__build_signals(G, B)
	PlayerKilled = B:NewBroadcaster("PlayerKilled")
end

local REGEN_RATE = 1/100 -- Regenerate this fraction of MaxHealth per second.
local REGEN_STEP = 1 -- Wait this long between each regeneration step.
local REGEN_DELAY = 3 - REGEN_STEP -- time before healing begins

function Character:__init(G)
	Game = G
	Entity = G.Load("Entity")
	Instances = G.Load("Instances")
	Config = G.Load("BUILDCONFIG")
	SpawnHandler = G.Load("SpawnHandler")

	Entity.registerType("Character")
		:DefaultMaxHealth(100)
		:OnSpawnFn(function(target_entity)
			local plr = target_entity.SourcePlayer
			local char = plr.Character

			local HRP = char:WaitForChild("HumanoidRootPart")
			local Humanoid: Humanoid = char:WaitForChild("Humanoid")

			Humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)

			Humanoid.WalkSpeed = Config.BaseWalkSpeed

			Humanoid.BreakJointsOnDeath = false
			Humanoid.RequiresNeck = false
			Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

			Instance.new("Animator", Humanoid)

			local handles = {}
			for limb, _ in pairs(handles) do
				local ToolJoint = Instance.new("Motor6D")
				ToolJoint.Name = "Handle"
				ToolJoint.Part0 = char:WaitForChild(limb)
				ToolJoint.Parent = char[limb]
			end

			-- The only place SetPrimaryPartCFrame should be used is when the
			-- character is not a descendant of the dataModel (welds don't work).

			for _, part in pairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide == true then
					PhysicsService:SetPartCollisionGroup(part, "Players")
				end
			end

			plr.ReplicationFocus = HRP

			CollectionService:AddTag(HRP, "HRPs")
			CollectionService:AddTag(char, "Characters")
			
			target_entity.DamagedBy = {}
		end)
		:OnDamageFn(function(target_entity, source_entity, amount)
			if source_entity and source_entity.SourcePlayer then
				local plr_tbl = Game[source_entity.SourcePlayer]
				if plr_tbl then
					target_entity.DamagedBy[source_entity.SourcePlayer] = target_entity.DamagedBy[source_entity.SourcePlayer] or 0
					target_entity.DamagedBy[source_entity.SourcePlayer] += amount
				end
			end
			
			local char = target_entity.Model
			
			local lastHealth = char:GetAttribute("Health")
			
			task.spawn(function()
				task.wait(REGEN_DELAY)
				if char:GetAttribute("Health") < lastHealth then
					return
				end
				
				if target_entity.Healing then
					return
				end
				
				target_entity.Healing = true
				
				target_entity.DamagedBy = {}
				
				while char:GetAttribute("Health") < char:GetAttribute("MaxHealth") do
					local dt = task.wait(REGEN_STEP)
					
					if char:GetAttribute("Health") < lastHealth then
						break
					end
					
					local dh = math.ceil(dt * REGEN_RATE * char:GetAttribute("MaxHealth"))
					local newHealth = math.min(char:GetAttribute("Health") + dh, char:GetAttribute("MaxHealth"))
					
					lastHealth = newHealth
					char:SetAttribute("Health", newHealth)
				end
				
				target_entity.Healing = false
			end)
		end)
		:KillFn(function(target_entity, source_entity)
			local killer = (source_entity or target_entity).SourcePlayer
			local plr = target_entity.SourcePlayer

			local deadStats = Game[plr].PlayerStats

			if killer then
				PlayerKilled:Broadcast(killer, plr)
			else
				PlayerKilled:Broadcast(plr, plr)
			end

			plr.Character.PrimaryPart.Anchored = false

			SpawnHandler.DespawnPlayer(plr, true)
			deadStats:ChangeStat("CanRespawn", false, "set", false)

			deadStats:Wipe(Enums.ResetType.OnDeath)

			plr.Character:ScaleTo(1)

			-- this is just light server verification, the client time is when the menu shows up again, which is different.
			task.delay(2.5, function()
				deadStats:ChangeStat("CanRespawn", true, "set", false)
			end)
		end)
		:CanBeHurtFn(function(target_entity)
			local player = target_entity.SourcePlayer
			local char = Game[player]
			local stats = char.PlayerStats
			return not stats.IsDead.Value
		end)
		:DoesPartConnectFn(function(target_entity, part)
			local limb = part

			local to = Instances.GetParentWhichHasParent(part, target_entity.Model.Armors)
			if to then
				limb = target_entity.Model[string.sub(to.Name, 1, -3)]
			end

			if limb then
				return true
			end

			return false
		end)
end


function Character:__finalize(G)
	if G.CONTEXT == "SERVER" then
		ResetRemoteRequest.OnServerEvent:Connect(function(plr)
			Entity.Kill(Entity.GetFromPlayer(plr), Entity.GetFromPlayer(plr))
		end)
	end	
end

-- We need this function for when the character is despawned or killed.
function Character.CleanupEffects(character, transfer)
	-- TODO: Reimplmenet a generic version of this
end

function Character.PlayerTeleport( plr: Player, auxPlr: Player )
	local character, auxCharacter = plr.Character, auxPlr.Character

	if character and auxCharacter then
		character.PrimaryPart.CFrame = auxCharacter.PrimaryPart.CFrame * CFrame.new(0, 2, 0)
	end
end

return Character

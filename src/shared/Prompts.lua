--[[
	Prompts are an extension of Abilites.

	Certain verifications are already built in, and use is called when the UI is interacted with.
	Only one Usage can be Active at a time.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Game
local Instances

local Abilities

local Prompts = {}
Prompts.__index = Prompts

local lastId = 0

local created = {}

local function getCenter(model)
	local isModel = model:IsA("Model")

	if isModel then
		return Instances.WaitForPrimaryPart(model), model:GetBoundingBox()
	else
		return model, model.CFrame
	end
end

local function getInfo(part, center, model)
	local attachment, realPrompt, id

	if RunService:IsServer() then
		lastId += 1

		id = lastId

		attachment = Instance.new("Attachment")
		attachment.Name = "_PromptAttachment"
		attachment:SetAttribute("ID", id)

		realPrompt = Instance.new("ProximityPrompt")
		realPrompt.Name = "_Prompt"
		realPrompt.ClickablePrompt = true
		realPrompt.HoldDuration = 0
		realPrompt.KeyboardKeyCode = Enum.KeyCode.E
		realPrompt.MaxActivationDistance = 6
		realPrompt.RequiresLineOfSight = false
		realPrompt.UIOffset = Vector2.new(0,-50)
		realPrompt.Parent = attachment

		attachment.Parent = part
		attachment.WorldCFrame = center
	else
		attachment = part:WaitForChild("_PromptAttachment")
		realPrompt = attachment:WaitForChild("_Prompt")
		id = attachment:GetAttribute("ID")
	end

	return attachment, realPrompt, id
end

local function canUse(self, plr, alreadyCheckedRange)
	if Game[plr].PlayerStats:GetStat("IsDead") then
		return false
	end

	if (not alreadyCheckedRange) and not self:IsInRange(plr) then
		return false
	end

	-- a prompt can only have one active usage at a time.
	if Abilities.GetActiveUsage(self.Ability) then
		return false
	end

	-- a person can only be in one active vehicle at time
	if plr.Character.Humanoid.Sit then
		return false
	end

	return true
end

local mt_ability_override = {}

-- Overrides of abilites, have the prompt passed in as the first parameter.
-- GetUseArgs usage is nil when it is being called to check if the UI should show up or not.

function mt_ability_override:ShouldAccept(func)
	self._prompt.__PromptCanUseServer = func
	return self
end

function mt_ability_override:GetUseArgs(func)
	self._prompt.__PromptGetUseArgs = func
	return self
end

function mt_ability_override:FINISH()
	setmetatable(self, self._prompt._abilityOldMetaTable)
	self:FINISH()

	return self._prompt
end

type ValidPromptParent = Model | BasePart
function Prompts.new(model: ValidPromptParent)
	local part, center = getCenter(model)

	local attachment, realPrompt, id = getInfo(part, center, model)

	local self

	local ability

	ability = Abilities.new("Prompts" .. id, "idk", Prompts)
		:GetUseArgs(function(plr, usage)
			if not canUse(self, plr) then
				return "CANCEL"
			end

			if self.__PromptGetUseArgs then
				return self:__PromptGetUseArgs(plr, usage)
			end

			return nil
		end)
		:ShouldAccept(function(plr, ability, args)
			if not canUse(self, plr) then
				return false
			end

			if self.__PromptCanUseServer and not self:__PromptCanUseServer(plr, ability, args) then
				return false
			end

			return true
		end)
		:ChecksWeaponCompatibility(false)
		:CancelOnDeath(true)

	local oldmeta = getmetatable(ability)

	self = setmetatable({
		RealPrompt = realPrompt,
		Attachment = attachment,
		Model = model,
		ID = id,
		Ability = ability,

		_abilityOldMetaTable = oldmeta,

		__PromptCanUseServer = nil,
		__PromptGetUseArgs = nil,

	}, {__index = Prompts})

	ability._prompt = self

	created[model] = self

	setmetatable(ability, {__index = function(self, key)
		return mt_ability_override[key] or oldmeta.__index[key]
	end})

	if RunService:IsClient() then
		realPrompt.Triggered:Connect(function(plr)
			if plr ~= Players.LocalPlayer then
				return
			end

			self.Ability:Use()
		end)
	end

	return ability
end

function Prompts.CancelActive(plr)
	for _, prompt in created do
		local usage = Abilities.GetActiveUsage(prompt.Ability, plr)
		if usage then
			usage:Cancel(true)
		end
	end
end

function Prompts:Destroy()
	created[self.Model] = nil
	self.Ability:Destroy()
	self.Attachment:Destroy()
end


function Prompts:ObjectText(objectText)
	self.RealPrompt.ObjectText = objectText
	return self
end

function Prompts:ActionText(actionText)
	self.RealPrompt.ActionText = actionText
	return self
end

function Prompts:HoldDuration(duration)
	self.RealPrompt.HoldDuration = duration
	return self
end


function Prompts.GetByID(id)
	for _, prompt in created do
		if prompt.ID == id then
			return prompt
		end
	end
end

function Prompts:IsInRange(plr)
	plr = plr or Players.LocalPlayer

	local serverPadding = RunService:IsServer() and 2 or 0

	if not self.Attachment then
		return false
	end

	local char = plr.Character
	if char then
		local primaryPart = char.PrimaryPart
		if primaryPart then
			return (self.Attachment.WorldCFrame.Position - primaryPart.Position).Magnitude < self.RealPrompt.MaxActivationDistance + serverPadding
		end
	end
end

function Prompts:IsInUseBy(plr)
	local usage = Abilities.GetActiveUsage(self.Ability)
	return usage and usage.Owner == plr
end

function Prompts:GetUsage()
	return Abilities.GetActiveUsage(self.Ability)
end


function Prompts:__init(G)
	Game = G
	Abilities = G.Load("Abilities")
	Instances = G.Load("Instances")
end

function Prompts:__run()
	if RunService:IsClient() then
		RunService.RenderStepped:Connect(function()
			for _, prompt in pairs(created) do
				-- no need to update the Enabled property if its not in range, roblox handles UI range for us.
				if prompt:IsInRange() then
					local useable = canUse(prompt, Players.LocalPlayer, true) and Abilities.isConsumeable(prompt.Ability, Players.LocalPlayer)
					if not useable then
						prompt.RealPrompt.Enabled = false
						continue
					end

					useable = (not prompt.__PromptGetUseArgs) or prompt:__PromptGetUseArgs(Players.LocalPlayer, nil) ~= "CANCEL"

					prompt.RealPrompt.Enabled = useable
				end
			end
		end)
	end
end

return Prompts

local FieldSelectors = { }

local mod = { }

local FieldSelector = { }
FieldSelector.__index = FieldSelector

local UserInput
local LocalPlayer = game.Players.LocalPlayer
local Style = _G.Game.PreLoad(game.ReplicatedFirst.Modules.GUI.Style)
local Globals
local RunService = game:GetService("RunService")

function mod:__init(G)
	Globals = G
	UserInput = G.Load("UserInput")
end

function mod.new(plr: Instance, keycode, model, min_range, max_range)
	assert(model and model.Parent, "Custom field selector without an initial parent cannot use `SetModel`")

	local t = {
		SelectorModel = model,
		Player = plr,

		__PostUpdateFn = false,
		__Radius = 5, -- unused in this type
		__MinRange = min_range or 20,
		__MaxRange = max_range or 100,

		__IsSelectionEnabledFn = false,
		__OnSelectedFn = false,
		__OnInRangeFn = false,
		__OnOutOfRangeFn = false,
		__KeyCode = keycode or Enum.UserInputType.MouseButton1,
		-- Hook MUST be set if the effect is running, and it MUST NOT be set if the effect has been paused/destroyed
		__Hook = false,
		__OnDisconnectFn = false,
		-- Note that -1 is used instead of a bool so that the model will change appearence on first update, guaranteed
		__was_in_range = -1,

		idx = -1
	}

	setmetatable(t, FieldSelector)

	return t

end

function mod:SetModel(mdl)
	local old_parent = self.SelectorModel.Parent
	mdl.Parent = old_parent
	self.SelectorModel:Destroy()
	self.SelectorModel = mdl
	self.__was_in_range = -1
	return self
end
function mod:OnDisconnectFn(func)
	self.__OnDisconnectFn = func
	return self
end
function mod:IsSelectionEnabledFn(func)
	self.__IsSelectionEnabledFn = func
	return self
end
function mod:OnSelectedFn(cb)
	self.__OnSelectedFn = cb
	return self
end
function mod:OnInRangeFn(func)
	self.__OnInRangeFn = func
	return self
end
function mod:OnOutOfRangeFn(func)
	self.__OnOutOfRangeFn = func
	return self
end
function mod:SetHookKey(keycode)
	self.__KeyCode = keycode
	return self
end
function mod:SetRadius(radius)
	self.__Radius = radius
	return self
end
function mod:SetMinRange(min_range)
	self.__MinRange = min_range
	return self
end
function mod:SetMaxRange(max_range)
	self.__MaxRange = max_range
	return self
end
function mod:PostUpdateFn(post_update)
	self.__PostUpdateFn = post_update
	return self
end

function mod:Run()
	assert(self.__OnSelectedFn, "FieldSelector:Run() - Callback not set")

	if self.idx > 0 then
		-- This has already been run
		-- We don't want the caller to worry about if they already ran the selector
		return
	end

	self.__Hook = UserInput:Intercept(self.__KeyCode, function(input)
		local did_accept = self:__OnSelectedFn(input)
		if did_accept then
			self:Pause()
			return true
		else
			return false
		end
	end)
	:SetDisconnectCallback(function()
		self.__Hook = false
	end)

	table.insert(FieldSelectors, self)
	self.idx = #FieldSelectors
end
function mod:Pause()
	self.SelectorModel.Parent = nil

	if self.__Hook then
		self.__Hook:Disconnect()
		table.remove(FieldSelectors, self.idx)
		self.idx = -1
	end
end
function mod:Destroy()
	self.SelectorModel:Destroy()

	if self.__Hook then
		self.__Hook:Disconnect()
		table.remove(FieldSelectors, self.idx)
		self.idx = -1
	end
end

function mod:IsInRange()
	local SelectorPos = self.SelectorModel:GetPivot().Position
	local char_pos = LocalPlayer.Character.HumanoidRootPart.Position
	local pos_a, pos_b = Vector2.new(SelectorPos.X, SelectorPos.Z), Vector2.new(char_pos.X, char_pos.Z)
	local dist = (pos_a - pos_b).Magnitude

	return ((dist > self.__MinRange) and (dist < self.__MaxRange)), dist
end

local redFieldColor = Style.FieldSelectorRed
local greenFieldColor = Style.FieldSelectorGreen

local function UpdateFieldSelectors(dt)
	-- There should really only be one of these at a time
	for i,v in FieldSelectors do
		if v.Player ~= game.Players.LocalPlayer then
			continue
		end

		local MouseHit = Globals.RaycastResultNPUnCapped

		local SelectorModel = v.SelectorModel
		if MouseHit then
			if SelectorModel.Parent == nil then
				SelectorModel.Parent = workspace
			end

			local cf = CFrame.new(MouseHit.Position) * CFrame.Angles(math.pi,0,0)
			SelectorModel:PivotTo(cf)
		else
			SelectorModel.Parent = nil
			continue
		end

		if SelectorModel.PrimaryPart then
			local is_in_range, dist = v:IsInRange()
			if v.__IsSelectionEnabledFn then
				is_in_range = is_in_range and v:__IsSelectionEnabledFn()
			end

			if is_in_range ~= v.__was_in_range then
				v.__was_in_range = is_in_range

				if is_in_range then
					if v.__OnInRangeFn then
						v:__OnInRangeFn(dist)
					else
						SelectorModel.PrimaryPart.Color = greenFieldColor
					end
				else
					if v.__OnOutOfRangeFn then
						v:__OnOutOfRangeFn(dist)
					else
						SelectorModel.PrimaryPart.Color = redFieldColor
					end
				end
			end 
		end

		if v.__PostUpdateFn then
			v:__PostUpdateFn(dt)
		end
	end
end

function mod:__run(G)
	if G.CONTEXT == "SERVER" then
		return
	end

	RunService.RenderStepped:Connect(UpdateFieldSelectors)
end

return mod
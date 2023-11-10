--[[
	Controllers handle Movement designed input.
	W,A,S,D, Space, MouseMovement
	Thumbstick, buttons.

	you register a type of controller
]]

local RunService = game:GetService("RunService")

local UserInput
local Enums

local UpdateLookDirectionBroadcaster
local StopLookDirectionBroadcaster

local UPDATE_LOOK_INTERVAL = 0.1

local THUMBSTICK_DEADZONE = 0.08

local ActiveController = nil

local ControllerFiles = {}

local Controller = {}
Controller.__index = Controller

function Controller:__init(G)
	UserInput = G.Load("UserInput")
	Enums = G.Load("Enums")

	for _, mod in script:GetChildren() do
		local name = string.sub(mod.Name, 1, -#"Controller"-1)
		ControllerFiles[name] = G.Load(mod.Name)
	end
end

local types = {}

function Controller.register(name)
	local newControllerType = {
		Name = name,

		CreateFunc = nil,
		DisableFunc = nil,
		DestroyFunc = nil,
		MovementUpdate = nil,
		JumpCallback = nil,
		SprintCallback = nil,
		LookUpdate = nil,
		ServerLookUpdate = nil,
		ShouldAcceptLookUpdate = nil,
		WillPreserveLookStateFor = {},
	}

	setmetatable(newControllerType, Controller)

	types[name] = newControllerType

	return newControllerType
end

function Controller:SetMovementUpdate(func)
	self.MovementUpdate = func
	return self
end

function Controller:SetJumpCallback(func)
	self.JumpCallback = func
	return self
end

function Controller:SetSprintCallback(func)
	self.SprintCallback = func
	return self
end

function Controller:SetLookUpdate(func)
	self.LookUpdate = func
	return self
end

function Controller:Create(func)
	self.CreateFunc = func
	return self
end

function Controller:SetDisableFunc(func)
	self.DisableFunc = func
	return self
end

function Controller:SetDestroyFunc(func)
	self.DestroyFunc = func
	return self
end

function Controller:SetShouldAcceptLookUpdate(func)
	self.ShouldAcceptLookUpdate = func
	return self
end

function Controller:PreserveLookStateFor(...)
	self.WillPreserveLookStateFor = {...}
	return self
end

function Controller:SetServerLookUpdate(func)
	self.ServerLookUpdate = func
	return self
end


local ControllerObject = {}
ControllerObject.__index = ControllerObject

Controller.ControllerObject = ControllerObject

local created = {}

-- model can actually be anything. a projectile, an entity, etc
function Controller.new(model, type_)
	if created[type_] then
		error("Only one controller can be created per type")
	end

	assert(types[type_], "Type is not registered: " .. type_)

	local newController = {
		Model = model,
		Type = type_,

		Enabled = false,

		SpaceHook = false,
		ShiftHook = false,
		
		ControllerSpaceHook = false,
		ControllerShiftHook = false,
		
		WHook = false,
		AHook = false,
		SHook = false,
		DHook = false,
		PadHandler = false,
		JoystickHandler = false,
		MoveStep = false,
		LookStep = false,
		UpdateHook = false,

		W = 0,
		A = 0,
		S = 0,
		D = 0,

		LastUpdatedLook = tick(),
	}

	if types[type_].CreateFunc then
		types[type_].CreateFunc(newController)
	else
		setmetatable(newController, ControllerObject)
	end


	created[type_] = newController

	return newController
end

-- For each thing which blocks sprinting, we lengthen the table
-- When everything that has blocked sprinting is done, #SprintingBlocked == 0
local TryingToSprint = false

local function BeginSprint()
	local active = ActiveController
	if active then
		if types[active.Type].SprintCallback then
			types[active.Type].SprintCallback(active, true)
		end
	end
end

local function EndSprint()
	local active = ActiveController
	if active then
		if types[active.Type].SprintCallback then
			types[active.Type].SprintCallback(active, false)
		end
	end
end

local SprintingBlocked = _G.Game.Maskables.Stack()
	:OnTopValueChanged(function(wrapper)
		if TryingToSprint then
			BeginSprint()
		else
			EndSprint()
		end
	end)
	:FINISH()

function _G.Game.BlockSprinting()
	local key = {}
	SprintingBlocked:set(key)
	return key
end

function _G.Game.UnblockSprinting(key)
	SprintingBlocked:remove(key)
end

function ControllerObject:_toggle(state, preserveLook)
	if self.Enabled == true and state == true then
		return
	end

	self.Enabled = state

	local typeData = types[self.Type]

	if state then
		self.SpaceHook = UserInput:Hook(Enum.KeyCode.Space, function()
			self.SpaceHeld = true

			if typeData.JumpCallback then
				typeData.JumpCallback(self)
			end
		end, function()
			self.SpaceHeld = false
		end)

		self.ShiftHook = UserInput:Hook(Enum.KeyCode.LeftShift, function()
			TryingToSprint = true
			SprintingBlocked:forceUpdate()
		end, function()
			TryingToSprint = false
			SprintingBlocked:forceUpdate()
		end)
		
		self.ControllerSpaceHook = UserInput:Hook(Enum.KeyCode.ButtonA, function()
			self.SpaceHeld = true

			if typeData.JumpCallback then
				typeData.JumpCallback(self)
			end
		end, function()
			self.SpaceHeld = false
		end)
		
		self.ControllerShiftHook = UserInput:Hook(Enum.KeyCode.ButtonL3, function()
			TryingToSprint = not TryingToSprint
			SprintingBlocked:forceUpdate()
		end)
		
		if UserInput.IsMobile then
			self.PadHandler = UserInput:Handler(Enums.UserInputType.DPad, function(input)
				local ang = math.atan2(input.Position.Y, input.Position.X)

				local magnitude = input.Position.Magnitude / 20
				
				local rf = math.sin(ang)
				local rs = math.cos(ang)

				if magnitude < 1 then
					rf *= magnitude
					rs *= magnitude
				end

				if magnitude > 5 then
					if not TryingToSprint then
						TryingToSprint = true
						SprintingBlocked:forceUpdate()
					end
				elseif TryingToSprint then
					TryingToSprint = false
					SprintingBlocked:forceUpdate()
				end
				
				self.W = rf
				self.S = 0

				self.A = rs
				self.D = 0
			end)
			
			UserInput.AddMobileButton("Jump", "Meta", function()
				self.SpaceHeld = true

				if typeData.JumpCallback then
					typeData.JumpCallback(self)
				end
			end, function()
				self.SpaceHeld = false
			end)
		else
			self.WHook = UserInput:Hook(Enum.KeyCode.W, function() self.W = -1 end, function() self.W = 0 end)
			self.AHook = UserInput:Hook(Enum.KeyCode.A, function() self.A = -1 end, function() self.A = 0 end)
			self.SHook = UserInput:Hook(Enum.KeyCode.S, function() self.S = 1 end, function() self.S = 0 end)
			self.DHook = UserInput:Hook(Enum.KeyCode.D, function() self.D = 1 end, function() self.D = 0 end)
			
			self.JoystickHandler = UserInput:Handler(Enum.KeyCode.Thumbstick1, function(input)
				local y = -input.Position.Y
				if math.abs(y) < THUMBSTICK_DEADZONE then
					y = 0
				end
				self.W = y
				
				self.S = 0
				
				local x = input.Position.X
				if math.abs(x) < THUMBSTICK_DEADZONE then
					x = 0
				end
				self.A = x
				
				self.D = 0
				
				if math.abs(x) + math.abs(y) <= 0 and TryingToSprint then
					TryingToSprint = false
					SprintingBlocked:forceUpdate()
				end
			end)
		end

		self.MoveStep = true
		self.LookStep = true

		self.UpdateHook = self.UpdateHook or RunService.Stepped:Connect(function(_, dt)
			if self.SpaceHeld then
				if typeData.JumpCallback then
					typeData.JumpCallback(self)
				end
			end

			if typeData.MovementUpdate and self.MoveStep then
				local direction = Vector3.new(self.A + self.D, 0, self.W + self.S)

				-- preserve smaller than 1 for thumbstick
				if direction.Magnitude > 1 then
					direction = direction.Unit
				end

				typeData.MovementUpdate(self, direction, dt)
			end

			if typeData.LookUpdate and self.LookStep then
				local updateValues = {typeData.LookUpdate(self, dt, false)}
				if tick() - self.LastUpdatedLook > UPDATE_LOOK_INTERVAL then
					self.LastUpdatedLook = tick()
					UpdateLookDirectionBroadcaster:Broadcast(updateValues, self.Type)
				end
			end
		end)
	else
		if self.SpaceHook then
			self.SpaceHook:Disconnect()
			self.SpaceHook = false
		end

		if self.ShiftHook then
			self.ShiftHook:Disconnect()
			self.ShiftHook = false
		end
		
		if self.ControllerSpaceHook then
			self.ControllerSpaceHook:Disconnect()
			self.ControllerSpaceHook = false
		end
		if self.ControllerShiftHook then
			self.ControllerShiftHook:Disconnect()
			self.ControllerShiftHook = false
		end
		
		if self.WHook then
			self.WHook:Disconnect()
			self.WHook = false
		end
		if self.AHook then
			self.AHook:Disconnect()
			self.AHook = false
		end
		if self.SHook then
			self.SHook:Disconnect()
			self.SHook = false
		end
		if self.DHook then
			self.DHook:Disconnect()
			self.DHook = false
		end
		if self.PadHandler then
			self.PadHandler:Disconnect()
			self.PadHandler = false
		end
		if self.JoystickHandler then
			self.JoystickHandler:Disconnect()
			self.JoystickHandler = false
		end
		
		if UserInput.DoesMobileButtonExist("Jump", "Meta") then
			UserInput.RemoveMobileButton("Jump", "Meta")
		end
		
		if self.MoveStep and typeData.DisableFunc then
			typeData.DisableFunc(self)
		end

		self.MoveStep = false

		if not preserveLook then
			StopLookDirectionBroadcaster:Broadcast(self.Type)
			self.LookStep = false
		end
	end
end

function ControllerObject:Destroy()
	self:_toggle(false)
	created[self.Type] = nil
	self.UpdateHook:Disconnect()
	self.UpdateHook = false

	if types[self.Type].DestroyFunc then
		types[self.Type].DestroyFunc(self)
	end
end

function Controller:DestroyAll()
	for name, controller in created do
		controller:Destroy()
	end
end

function Controller.Get(name)
	return created[name]
end

function Controller.GetActive()
	return ActiveController
end

function Controller.SetActive(name)
	print("SetActive:", name, debug.traceback())
	
	if ActiveController then
		for otherName, controller in created do
			if controller.LookStep and otherName ~= name then
				local preserveLook = name and table.find(types[name].WillPreserveLookStateFor, controller.Type)
				ActiveController:_toggle(false, preserveLook)
			end
		end
	end

	if not name then
		return
	end

	ActiveController = created[name]
	ActiveController:_toggle(true)
end

local storeRecievedUpdates = {}

function Controller:__build_signals(G, B)
	UpdateLookDirectionBroadcaster = B:NewBroadcaster("UpdateLookDirectionBroadcaster")
		:ClientConnection(function(plr, args, type_)
			storeRecievedUpdates[plr] = storeRecievedUpdates[plr] or {}
			storeRecievedUpdates[plr][type_] = args
		end)
		:ShouldAccept(function(plr, args, type_)
			return types[type_].ShouldAcceptLookUpdate(plr, args)
		end)
		:ServerConnection(function(plr, args, type_)
			if types[type_].ServerLookUpdate then
				types[type_].ServerLookUpdate(plr, args)
			end
		end)

	StopLookDirectionBroadcaster = B:NewBroadcaster("StopLookDirectionBroadcaster")
		:ShouldAccept(function(plr, type_)
			if types[type_] then
				return true
			end

			return false
		end)
		:ClientConnection(function(plr, type_)
			if storeRecievedUpdates[plr] then
				storeRecievedUpdates[plr][type_] = nil
			end
		end)
end

function Controller:__run(G, B)
	RunService.Stepped:Connect(function(_, dt)
		for plr, t in storeRecievedUpdates do
			if not plr:IsDescendantOf(game) then
				storeRecievedUpdates[plr] = nil
				continue
			end

			if not plr.Character then
				continue
			end

			for type_, args in t do
				types[type_].LookUpdate(nil, dt, plr, table.unpack(args))
			end
		end
	end)
end

return Controller
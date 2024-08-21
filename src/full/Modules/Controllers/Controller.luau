--!strict

--[[
	Controllers handle Movement designed input.
	W,A,S,D, Space, MouseMovement
	Thumbstick, buttons.

	you register a type of controller
]]

local RunService = game:GetService("RunService")

local LMT = require(game.ReplicatedFirst.Lib.LMTypes)
local Game: LMT.LMGame = _G.Game
local UserInput = if Game.CONTEXT == "CLIENT" then require(game.ReplicatedFirst.Lib.UserInput) else nil
local Mobile = if Game.CONTEXT == "CLIENT" then require(game.ReplicatedFirst.Lib.UserInput.Mobile) else nil
local Enums = require(game.ReplicatedFirst.Lib.Enums)
local Signals = require(game.ReplicatedFirst.Lib.Signals)
local Config = require(game.ReplicatedFirst.Config)

local UpdateLookDirectionBroadcaster = Signals.NewBroadcaster("UpdateLookDirectionBroadcaster")
	:UpConnectionType(function(plr, args: { number }, type_: string) end)
	:DownConnectionType(function(plr, args: { number }, type_: string) end)

local StopLookDirectionBroadcaster = Signals.NewBroadcaster("StopLookDirectionBroadcaster")
	:UpConnectionType(function(plr, type_: string) end)
	:DownConnectionType(function(plr, type_: string) end)

local MovementEnabled = true
local LastMovementDirection

local UPDATE_LOOK_INTERVAL = 0.1
local THUMBSTICK_DEADZONE = 0.14

local ActiveController: ControllerInstance? = nil

local mod = {}
mod.__index = mod

local W, A, S, D, SpaceHeld = 0, 0, 0, 0, false

export type Controller = {
	Name: string,

	-- Hooks when the controller is toggled on
	EnabledFunc: false | (ControllerInstance) -> (),
	-- Hooks when a controller is toggled off
	DisabledFunc: false | (ControllerInstance) -> (),
	-- Hooks destruction
	DestroyFunc: false | (ControllerInstance) -> (),
	MovementUpdate: false | (ControllerInstance, Vector3, number) -> (),
	JumpCallback: false | (ControllerInstance) -> (),
	SprintCallback: false | (ControllerInstance, boolean) -> (),
	LocalLookUpdate: false | (ControllerInstance, number) -> (number, number, number, number),
	RemoteLookUpdate: false | (number, Player, number, number, number, number) -> (),
	ServerLookUpdate: false | (ControllerInstance, number, number, number, number) -> (),
	ShouldAcceptLookUpdate: false | (ControllerInstance, number, number, number, number) -> boolean,
	-- This will prevent setting this controller as active from stopping look update functions being called
	-- on the ones that are no longer active as a result of that call
	-- A concrete example is if a character rides a horse, you may want the character and the horse to both respond
	-- to look direction, but only the horse controller should be active
	PreserveLookStateFor: { string },
}

export type ControllerInstance = {
	Model: any,
	Type: Controller,
	Enabled: boolean,
	LookStep: boolean,
	LastUpdatedLook: number,
}

local RegisteredControllers: { [string]: Controller } = {}

function mod.Register(name, controller: Controller)
	RegisteredControllers[name] = controller

	return controller
end

local InstancedController = {}
InstancedController.__index = InstancedController

local Instances: { [string]: ControllerInstance } = {}

-- model can actually be anything. a projectile, an entity, etc
function mod.Instantiate(model, type_: string)
	if Instances[type_] then
		error("Only one controller can be created per type")
	end

	assert(RegisteredControllers[type_], "Type is not registered: " .. type_)

	local controller: Controller = RegisteredControllers[type_]

	if not controller then
		error("Controller is not registered: " .. type_)
	end

	local newController: ControllerInstance = {
		Model = model,
		Type = controller,

		Enabled = false,
		LookStep = false,

		LastUpdatedLook = tick(),
	}

	if controller.EnabledFunc then
		controller.EnabledFunc(newController)
	end
	setmetatable(newController, InstancedController)


	Instances[type_] = newController

	return newController
end

-- For each thing which blocks sprinting, we lengthen the table
-- When everything that has blocked sprinting is done, #SprintingBlocked == 0
local TryingToSprint = false

local function BeginSprint()
	local active = ActiveController
	if active then
		if active.Type.SprintCallback then
			active.Type.SprintCallback(active, true)
		end
	end
end

local function EndSprint()
	local active = ActiveController
	if active then
		if active.Type.SprintCallback then
			active.Type.SprintCallback(active, false)
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

local function ToggleInstance(self: ControllerInstance, state: boolean, preserveLook: boolean?)
	if self.Enabled == true and state == true then
		return
	end

	self.Enabled = state

	local controller = self.Type

	if state then
		self.LookStep = true
		SprintingBlocked:forceUpdate()
	else
		if controller.MovementUpdate then
			controller.MovementUpdate(self, Vector3.new(0, 0, 0), 0)
		end
		
		if controller.DisabledFunc then
			controller.DisabledFunc(self)
		end

		if not preserveLook then
			StopLookDirectionBroadcaster:BroadcastUp(self.Type.Name)
			self.LookStep = false
		end
		
		if ActiveController == self then
			ActiveController = nil
		end
	end
end

function InstancedController:Destroy()
	ToggleInstance(self, false)
	Instances[self.Type.Name] = nil

	if self.Type.DestroyFunc then
		self.Type.DestroyFunc(self)
	end
end

function mod:DestroyAll()
	for name, controller in Instances do
		controller:Destroy()
	end
end

function mod.Get(name)
	return Instances[name]
end

function mod.InterruptMovement()
	MovementEnabled = false
	LastMovementDirection = Vector3.new(A + D, 0, W + S)
end

function mod.CancelInterruptMovement()
	MovementEnabled = true
end

local walk_speed_tickets = {}

local function apply_walk_speed()
	local walkSpeed = Config.BaseWalkSpeed
	
	for name, ticket in walk_speed_tickets do
		walkSpeed *= ticket.Affect
	end
	
	game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = walkSpeed
end

function mod.TicketWalkSpeed(affect: number, name: string)
	if walk_speed_tickets[name] then
		return walk_speed_tickets[name]
	end
	
	walk_speed_tickets[name] = {Affect = affect, Name = name}
	
	apply_walk_speed()

	return walk_speed_tickets[name]
end

function mod.RemoveWalkSpeed(ticket)
	if ticket and walk_speed_tickets[ticket.Name] then
		walk_speed_tickets[ticket.Name] = nil
		
		apply_walk_speed()
	end
end

function mod.RemoveAllWalkSpeeds()
	for i,v in pairs(walk_speed_tickets) do
		mod.RemoveWalkSpeed(v)
	end
end

function mod.TryDestroy(name)
	local controller = Instances[name]
	if controller then
		controller:Destroy()
	end
end

function mod.GetActive()
	return ActiveController
end

function mod.SetActive(name: string?)
	-- print("SetActive:", name, debug.traceback())
	
	if ActiveController then
		for otherName, controller in Instances do
			if controller.LookStep and otherName ~= name then
				local preserveLook = if name and table.find(RegisteredControllers[name].PreserveLookStateFor, controller.Type.Name) then true else false
				ToggleInstance(ActiveController, false, preserveLook)
			end
		end
	end

	if not name then
		ActiveController = nil
		return
	end

	ActiveController = Instances[name]
	
	if ActiveController then
		ToggleInstance(ActiveController, true)
	end
end

local PadHandler
local SpaceHook
local ShiftHook
local ControllerSpaceHook
local ControllerShiftHook
local JoystickHandler
local WHook
local AHook
local SHook
local DHook

function mod.__init(G)
	if G.CONTEXT == "SERVER" then
		return
	end

	if UserInput.IsMobile then
		task.spawn(function()
			while not Mobile.HasUIStarted() do
				task.wait()
			end

			PadHandler = UserInput.Handler(Enums.UserInputType.DPad, function(input)
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
				
				W = rf
				S = 0

				A = rs
				D = 0
			end)
			
			Mobile.AddButton("Jump", "Meta", function()
				SpaceHeld = true

				if ActiveController and ActiveController.Type.JumpCallback then
					ActiveController.Type.JumpCallback(ActiveController)
				end
			end, function()
				SpaceHeld = false
			end)
		end)
	else
		WHook = UserInput.Hook(Enum.KeyCode.W, function() W = -1 end, function() W = 0 end)
		AHook = UserInput.Hook(Enum.KeyCode.A, function() A = -1 end, function() A = 0 end)
		SHook = UserInput.Hook(Enum.KeyCode.S, function() S = 1 end, function() S = 0 end)
		DHook = UserInput.Hook(Enum.KeyCode.D, function() D = 1 end, function() D = 0 end)

		SpaceHook = UserInput.Hook(Enum.KeyCode.Space, function()
			SpaceHeld = true

			if ActiveController and ActiveController.Type.JumpCallback then
				ActiveController.Type.JumpCallback(ActiveController)
			end
		end, function()
			SpaceHeld = false
		end)

		ShiftHook = UserInput.Hook(Enum.KeyCode.LeftShift, function()
			TryingToSprint = true
			SprintingBlocked:forceUpdate()
		end, function()
			TryingToSprint = false
			SprintingBlocked:forceUpdate()
		end)
		
		ControllerSpaceHook = UserInput.Hook(Enum.KeyCode.ButtonA, function()
			SpaceHeld = true

			if ActiveController and ActiveController.Type.JumpCallback then
				ActiveController.Type.JumpCallback(ActiveController)
			end
		end, function()
			SpaceHeld = false
		end)
		
		ControllerShiftHook = UserInput.Hook(Enum.KeyCode.ButtonL3, function()
			TryingToSprint = not TryingToSprint
			SprintingBlocked:forceUpdate()
		end)

		if Mobile.DoesButtonExist("Jump", "Meta") then
			Mobile.RemoveButton("Jump", "Meta")
		end

		if PadHandler then
			PadHandler:Disconnect()
			PadHandler = nil
		end
		
		JoystickHandler = UserInput.Handler(Enum.KeyCode.Thumbstick1, function(input)
			local y = -input.Position.Y
			if math.abs(y) < THUMBSTICK_DEADZONE then
				y = 0
			end
			W = y
			
			S = 0
			
			local x = input.Position.X
			if math.abs(x) < THUMBSTICK_DEADZONE then
				x = 0
			end
			A = x
			
			D = 0
			
			if math.abs(x) + math.abs(y) <= 0 and TryingToSprint then
				TryingToSprint = false
				SprintingBlocked:forceUpdate()
			end
		end)
	end

	RunService.Stepped:Connect(function(_, dt)
		debug.profilebegin("Controllers")
		local active = ActiveController
		
		if not active then
			return
		end

		local controller = active.Type

		if SpaceHeld then
			if controller.JumpCallback then
				controller.JumpCallback(active)
			end
		end
		
		-- repoll active for compatability with jump destroying controllers.
		active = ActiveController
		if not active then
			return
		end

		controller = active.Type
		
		local direction = Vector3.new(A + D, 0, W + S)
		
		if (not MovementEnabled) and direction ~= LastMovementDirection then
			mod.CancelInterruptMovement()
		end
		
		-- preserve smaller than 1 for thumbstick
		if direction.Magnitude > 1 then
			direction = direction.Unit
		end
		
		if not MovementEnabled then
			direction = Vector3.zero
		end
		
--[[ 		if direction.Magnitude > 0 then
			Abilities.AttemptCancelOnMove()
		end ]]
		
		if controller.MovementUpdate then
			controller.MovementUpdate(active, direction, dt)
		end

		if controller.LocalLookUpdate and active.LookStep then
			local updateValues = {controller.LocalLookUpdate(active, dt)}
			if tick() - active.LastUpdatedLook > UPDATE_LOOK_INTERVAL then
				active.LastUpdatedLook = tick()
				UpdateLookDirectionBroadcaster:BroadcastUp(updateValues, active.Type.Name)
			end
		end
		debug.profileend()
	end)
end

local storeRecievedUpdates = {}

UpdateLookDirectionBroadcaster:DownConnection(function(plr, args, type_)
		storeRecievedUpdates[plr] = storeRecievedUpdates[plr] or {}
		storeRecievedUpdates[plr][type_] = args
	end)
	:ShouldAccept(function(plr, args, type_)
		return RegisteredControllers[type_].ShouldAcceptLookUpdate(plr, args)
	end)
	:UpConnection(function(plr, args, type_)
		if RegisteredControllers[type_].ServerLookUpdate then
			RegisteredControllers[type_].ServerLookUpdate(plr, args)
		end
	end)

StopLookDirectionBroadcaster:DownConnection(function(plr, type_)
		if storeRecievedUpdates[plr] then
			storeRecievedUpdates[plr][type_] = nil
		end
	end)
	:ShouldAccept(function(plr, type_: string)
		if RegisteredControllers[type_] then
			return true
		end

		return false
	end)

function mod.__run(G)
	RunService.Stepped:Connect(function(_, dt)
		debug.profilebegin("Controllers Network")
		for plr, t in storeRecievedUpdates do
			if not plr:IsDescendantOf(game) then
				storeRecievedUpdates[plr] = nil
				continue
			end

			if not plr.Character then
				continue
			end

			for type_, args in t do
				local controller = RegisteredControllers[type_]
				if controller.RemoteLookUpdate then
					pcall(controller.RemoteLookUpdate, dt, plr, table.unpack(args))
				end
			end
		end
		debug.profileend()
	end)
end

return mod
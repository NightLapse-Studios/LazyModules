--!strict

--[[
	This module implements an input-capturing system similar to ContextActionService except with usage abstractions
		as well as the ability to control behavior such as `AddTitle`

	The usage patterns specify an Enum.KeyCode (or Enum.UserInputType for certain inputs e.g. mouse button presses)
		as well as a handling callback.

	The abstract usage patterns:
	Handlers:
		The primary handler functions for keys. E.G. `W` should primarily be handled as "move forward"
	Hooks:
		Listens for input but does not handle it. E.G. `W` should perhaps also light up some UI element, but the UI
		element shouldn't need to handle movement
	Intercepts:
		Temporarily takes control of some input, up to an optional `MaxIntercepts` amount. If a maximum intercept count
		is specified, then the callback function can return a boolean specifying if the input was sunk.
			Sunk input causes the intercept count to go up
			Unsunk input does not, allowing the callback to essentially reject invalid usage of the input
				E.G. `Selected area was out of range` behavior would see the callback return `false`

	Custom KeyCodes:
		Not easily converted to a string, these are currently just stored as numbers in Enums.lua
		Enum items typically have a .Name or .Value field, these don't

	Auxiliary KeyCodes:
		A more complex grouping of input types or key codes
		E.G. Enums.AuxiliaryInputCodes.KeyCodes.Any
			 Enums.AuxiliaryInputCodes.InputGestures.Any
		Aux codes are second-class-citizens to KeyCodes and InputTypes, in this case meaning they are processed in parallel
		and therefore do not support more complex behaviors all the time.
			The primary way this matters right now:
			**AUXILIARY CODES CANNOT BLOCK HANDLERS WHEN LISTENED TO BY INTERCEPTS**


	Details:
	Handlers are stack-based, so the most recently added handler for a keycode will be the effective handler
	A handler which disconnects itself after a single use is semantically equivalent to an intercept with
		`MaxIntercepts` at 1
	Intercepts block handlers, regardless of if they sink the input or not
	Hooks block nothing
	Hooks cannot be blocked by handlers or intercepts
]]

local Config = require(game.ReplicatedFirst.Config)
local GestureDetector = require(script.GestureDetector)
local Enums = require(game.ReplicatedFirst.Lib.Enums)
local AssociativeList = require(game.ReplicatedFirst.Lib.AssociativeList)
local Stack = require(game.ReplicatedFirst.Lib.Stack)
local Mobile = require(script.Mobile)
local ClassicSignal = require(game.ReplicatedFirst.Lib.ClassicSignal)
local Game

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local mod = { }

type BaseListener = {
	InterceptCount: number,
	MaxIntercepts: number,

	down_callback: InputBeganCallback,
	up_callback: InputEndedCallback | false,
	disconnected_callback: (BaseListener) -> () | false,
	keycode: InputBasis,
	
	runsOnProcessed: boolean,
	armed: boolean,
	__SourceFile: string?,

	Disconnect: (self: BaseListener) -> BaseListener,
	SetRunsRobloxProcessed: (self: BaseListener, boolean) -> BaseListener,
	SetDisconnectCallback: (self: BaseListener, (BaseListener) -> ()) -> BaseListener,
}

export type Hook = { Type: "Hook" } & BaseListener
export type Handler = { Type: "Handler" } & BaseListener
export type Intercept = { Type: "Intercept" } & BaseListener

export type AnyListener = Hook | Handler | Intercept

export type InputObject2 = {
	Delta: Vector3,
	KeyCode: KeyCode2,
	Position: Vector3,
	UserInputState: Enum.UserInputState,
	UserInputType: InputType2,
	AuxiliaryCode: Enums.AuxCode | false
}

export type KeyCode2 = Enum.KeyCode | Enums.InputGesture
export type InputType2 = Enum.UserInputType | Enums.UserInputType2
export type InputBasis = KeyCode2 | InputType2 | Enums.AuxCode

export type InputBeganCallback = (input: InputObject2, processed: boolean) -> (boolean)
export type InputEndedCallback = (input: InputObject2, processed: boolean) -> (boolean)

local Handlers: { [InputBasis]: Stack.Stack<Handler?> } = { }
local Intercepts: { [InputBasis]: Stack.Stack<Intercept?> } = { }
local Hooks: { [InputBasis]: Stack.Stack<Hook?> } = { }
local PendingCustomInputs: { InputObject2 } = { }

local CustomKeycodes = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.MouseButton3] = true,
	[Enum.UserInputType.MouseWheel] = true,
	[Enum.UserInputType.MouseMovement] = true,
	[Enum.UserInputType.Touch] = true,
	-- [Enum.UserInputType.Keyboard] = true,
	[Enum.UserInputType.Focus] = true,
	[Enum.UserInputType.Accelerometer] = true,
	[Enum.UserInputType.Gyro] = true,
	--[[ [Enum.UserInputType.Gamepad1] = true,
	[Enum.UserInputType.Gamepad2] = true,
	[Enum.UserInputType.Gamepad3] = true,
	[Enum.UserInputType.Gamepad4] = true,
	[Enum.UserInputType.Gamepad5] = true,
	[Enum.UserInputType.Gamepad6] = true,
	[Enum.UserInputType.Gamepad7] = true,
	[Enum.UserInputType.Gamepad8] = true, ]]
--[[ 	[Enum.UserInputType.TextInput] = true,
	[Enum.UserInputType.InputMethod] = true, ]]
	[Enum.UserInputType.None] = true,
	[Enums.InputGestures.Left] = true,
	[Enums.InputGestures.Right] = true,
	[Enums.InputGestures.Up] = true,
	[Enums.InputGestures.Down] = true,
	[Enums.AuxInputCodes.AuxInputGestures.Any] = true,
	[Enums.AuxInputCodes.AuxInputGestures.Total] = true,
	[Enums.AuxInputCodes.AuxInputGestures.Last] = true,
	[Enums.AuxInputCodes.AuxKeyCodes.Any] = true,
	[Enums.UserInputType.DPad] = true,
}



for i,v in Enum.KeyCode:GetEnumItems() do
	Handlers[v] = (Stack.new() :: any) :: Stack.Stack<Handler>
	Intercepts[v] = (Stack.new() :: any) :: Stack.Stack<Intercept>
	Hooks[v] = (Stack.new() :: any) :: Stack.Stack<Hook>
end
for i,_ in CustomKeycodes do
	Handlers[i] = (Stack.new() :: any) :: Stack.Stack<Handler>
	Intercepts[i] = (Stack.new() :: any) :: Stack.Stack<Intercept>
	Hooks[i] = (Stack.new() :: any) :: Stack.Stack<Hook>
end



local EnumAssociations = AssociativeList.new()
do
	EnumAssociations:add(Enum.KeyCode.One, 1)
	EnumAssociations:add(Enum.KeyCode.Two, 2)
	EnumAssociations:add(Enum.KeyCode.Three, 3)
	EnumAssociations:add(Enum.KeyCode.Four, 4)
	EnumAssociations:add(Enum.KeyCode.Five, 5)
	EnumAssociations:add(Enum.KeyCode.Six, 6)
	EnumAssociations:add(Enum.KeyCode.Seven, 7)
	EnumAssociations:add(Enum.KeyCode.Eight, 8)
	EnumAssociations:add(Enum.KeyCode.Nine, 9)
	EnumAssociations:add(Enum.KeyCode.Zero, 0)
	EnumAssociations:add(Enum.KeyCode.A, "a")
	EnumAssociations:add(Enum.KeyCode.B, "b")
	EnumAssociations:add(Enum.KeyCode.C, "c")
	EnumAssociations:add(Enum.KeyCode.D, "d")
	EnumAssociations:add(Enum.KeyCode.E, "e")
	EnumAssociations:add(Enum.KeyCode.F, "f")
	EnumAssociations:add(Enum.KeyCode.G, "g")
	EnumAssociations:add(Enum.KeyCode.H, "h")
	EnumAssociations:add(Enum.KeyCode.I, "i")
	EnumAssociations:add(Enum.KeyCode.J, "j")
	EnumAssociations:add(Enum.KeyCode.K, "k")
	EnumAssociations:add(Enum.KeyCode.L, "l")
	EnumAssociations:add(Enum.KeyCode.M, "m")
	EnumAssociations:add(Enum.KeyCode.N, "n")
	EnumAssociations:add(Enum.KeyCode.O, "o")
	EnumAssociations:add(Enum.KeyCode.P, "p")
	EnumAssociations:add(Enum.KeyCode.Q, "q")
	EnumAssociations:add(Enum.KeyCode.R, "r")
	EnumAssociations:add(Enum.KeyCode.S, "s")
	EnumAssociations:add(Enum.KeyCode.T, "t")
	EnumAssociations:add(Enum.KeyCode.U, "u")
	EnumAssociations:add(Enum.KeyCode.V, "v")
	EnumAssociations:add(Enum.KeyCode.W, "w")
	EnumAssociations:add(Enum.KeyCode.X, "x")
	EnumAssociations:add(Enum.KeyCode.Y, "y")
	EnumAssociations:add(Enum.KeyCode.Z, "z")
	EnumAssociations:add(Enum.KeyCode.LeftCurly, "{")
	EnumAssociations:add(Enum.KeyCode.Pipe, "|")
	EnumAssociations:add(Enum.KeyCode.RightCurly, "}")
	EnumAssociations:add(Enum.KeyCode.Tilde, "~")
--[[ 	EnumAssociations:add(Enum.KeyCode.KeypadZero, 0)
	EnumAssociations:add(Enum.KeyCode.KeypadOne, 1)
	EnumAssociations:add(Enum.KeyCode.KeypadTwo, 2)
	EnumAssociations:add(Enum.KeyCode.KeypadThree, 3)
	EnumAssociations:add(Enum.KeyCode.KeypadFour, 4)
	EnumAssociations:add(Enum.KeyCode.KeypadFive, 5)
	EnumAssociations:add(Enum.KeyCode.KeypadSix, 6)
	EnumAssociations:add(Enum.KeyCode.KeypadSeven, 7)
	EnumAssociations:add(Enum.KeyCode.KeypadEight, 8)
	EnumAssociations:add(Enum.KeyCode.KeypadNine, 9) ]]
	EnumAssociations:add(Enum.KeyCode.KeypadPeriod, ".")
	EnumAssociations:add(Enum.KeyCode.KeypadDivide, "/")
	EnumAssociations:add(Enum.KeyCode.KeypadMultiply, "*")
	EnumAssociations:add(Enum.KeyCode.KeypadMinus, "-")
	EnumAssociations:add(Enum.KeyCode.KeypadPlus, "+")
	EnumAssociations:add(Enum.KeyCode.KeypadEquals, "=")
	EnumAssociations:add(Enum.KeyCode.Colon, ":")
	EnumAssociations:add(Enum.KeyCode.Semicolon,	";")
	EnumAssociations:add(Enum.KeyCode.LessThan, "<")
	EnumAssociations:add(Enum.KeyCode.Equals, "=")
	EnumAssociations:add(Enum.KeyCode.GreaterThan, ">")
	EnumAssociations:add(Enum.KeyCode.Question, "?")
	EnumAssociations:add(Enum.KeyCode.At, "@")
	EnumAssociations:add(Enum.KeyCode.LeftBracket, "[")
	EnumAssociations:add(Enum.KeyCode.BackSlash, "\\")
	EnumAssociations:add(Enum.KeyCode.RightBracket, "]")
	EnumAssociations:add(Enum.KeyCode.Caret, "^")
	EnumAssociations:add(Enum.KeyCode.Underscore, "_")
end

mod.EnumAssociations = EnumAssociations

local ListenerCreatedCallbacks: { [InputBasis]: (Hook | Intercept | Handler) -> () } = {
	[Enums.UserInputType.DPad] = Mobile.PushDPadUser
}

local ListenerDestroyedCallbacks: { [InputBasis]: (Hook | Intercept | Handler) -> () } = {
	[Enums.UserInputType.DPad] = Mobile.RemoveDPadUser
}



local ListenerType = { }
ListenerType.__index = ListenerType

function ListenerType:Disconnect()
	if self.disconnected_callback then
		self:disconnected_callback()
	end

	if ListenerDestroyedCallbacks[self.keycode] then
		ListenerDestroyedCallbacks[self.keycode](self)
	end

	local list = mod[self.Type][self.keycode]
	for i,v in list do
		if v == self then
			table.remove(list, i)
		end
	end

	return nil
end

function ListenerType:SetRunsRobloxProcessed(doRun)
	self.runsOnProcessed = doRun
end

function ListenerType:SetDisconnectCallback(callback)
	self.disconnected_callback = callback
	return self
end


function ListenerType.new(type: "Handler" | "Intercept" | "Hook", down_callback: InputBeganCallback, up_callback: InputEndedCallback?, keycode: InputBasis, max_ct: number?)
	local listener = {
		Type = type,
		InterceptCount = 0,
		MaxIntercepts = max_ct or math.huge,

		down_callback = down_callback,
		up_callback = up_callback or false,
		disconnected_callback = false,
		keycode = keycode,
		
		runsOnProcessed = false,
		-- For intercepts which also listen for releases, we track if they sank the input first via this `armed` value
		armed = false,
	}

	if ListenerCreatedCallbacks[keycode] then
		ListenerCreatedCallbacks[keycode](listener)
	end

	if Config.LogInputProcessing then
		local s,l,n = debug.info(3, "sln")
		listener.__SourceFile = s..":"..n..":"..l
	end

	if keycode == Enum.UserInputType.MouseWheel and up_callback then
		warn("Key up callback provided to mousewheel event, but only key down will be called")
	end

	setmetatable(listener, ListenerType)

	return (listener :: any) :: AnyListener
end

function mod.Intercept(keycode: InputBasis, down_callback: InputBeganCallback, opt_up_callback: InputEndedCallback?, opt_max_ct: number?)
	if Config.LogInputListeners then
		local s,l,n = debug.info(1, "sln")
		print("New Intercept for `" .. tostring(keycode) .. "`\n\tFrom:\n" .. s .. ":" .. l .. " function " .. n .. "\n")
	end

	opt_max_ct = opt_max_ct or 1

	local listener = ListenerType.new("Intercept", down_callback, opt_up_callback, keycode, opt_max_ct) :: Intercept
	Intercepts[keycode]:push(listener)

	return listener
end

function mod.Hook(keycode: InputBasis, down_callback: InputBeganCallback, opt_up_callback: InputEndedCallback?)
	if Config.LogInputListeners then
		local s,l,n = debug.info(1, "sln")
		print("New Hook for `" .. tostring(keycode) .. "`\n\tFrom:\n" .. s .. ":" .. l .. " function " .. n .. "\n")
	end

	local listener = ListenerType.new("Hook", down_callback, opt_up_callback, keycode) :: Hook
	Hooks[keycode]:push(listener)

	return listener
end

function mod.Handler(keycode: InputBasis, down_callback: InputBeganCallback, opt_up_callback: InputEndedCallback?)
	--local old_primary = mod.Listeners[keycode][1]
	if Config.LogInputListeners then
		local s,l,n = debug.info(1, "sln")
		print("New Handler for `" .. tostring(keycode) .. "`\n\tFrom:\n" .. s .. ":" .. l .. " function " .. n .. "\n")
	end

	local listener = ListenerType.new("Handler", down_callback, opt_up_callback, keycode) :: Handler
	Handlers[keycode]:push(listener)

	return listener
end




function mod.CustomInputObject(keycode: KeyCode2, opt_aux_code: Enums.AuxCode?, input_state: Enum.UserInputState, input_type: Enums.UserInputType2 | Enum.UserInputType)
	assert(keycode)
	assert(input_state)
	assert(input_type)
	--TODO: Better aux code processing
	local opt_aux_code: Enums.AuxCode = opt_aux_code or Enums.AuxInputCodes.AuxKeyCodes.Any

	local t: InputObject2 = {
		Delta = Vector3.new(),
		KeyCode = keycode,
		AuxiliaryCode = opt_aux_code,
		Position = Vector3.new(),
		UserInputState = input_state,
		UserInputType = input_type,
	}

	return t
end

function mod.TakeCustomInput(input: InputObject2)
	table.insert(PendingCustomInputs, input)
end

function mod.GetLastGesture()
	return GestureDetector.Last
end

local Mouse = game.Players.LocalPlayer:GetMouse()
local function desktop_mouse_pos()
	return Vector2.new(Mouse.X, Mouse.Y)
end

-- we must enforce lockcenter on mobile, because roblox does some weird thing
local TouchResponsibleForMouse: InputObject | false = false
local GuiService = game:GetService("GuiService")
local Camera = workspace.CurrentCamera
local function mobile_mouse_pos()
	local inset = GuiService:GetGuiInset()
	return Camera.ViewportSize/2 - inset
end

function mod.GetMousePos()
	return Game.PlatformVar(desktop_mouse_pos, mobile_mouse_pos)()
end


-- Fires either Enum.UserInputType. Keyboard, Touch, Gamepad1, but only to differentiate between Desktop, Mobile, Gamepad, given any input.
mod.LastInputTypeChanged = ClassicSignal.new()

local inputTypeMaps = {
	[Enum.UserInputType.MouseButton1] = Enum.UserInputType.Keyboard,
	[Enum.UserInputType.MouseButton2] = Enum.UserInputType.Keyboard,
	[Enum.UserInputType.MouseButton3] = Enum.UserInputType.Keyboard,
	[Enum.UserInputType.MouseWheel] = Enum.UserInputType.Keyboard,
	[Enum.UserInputType.MouseMovement] = Enum.UserInputType.Keyboard,
	[Enum.UserInputType.Touch] = Enum.UserInputType.Touch,
	[Enum.UserInputType.Keyboard] = Enum.UserInputType.Keyboard,
	[Enum.UserInputType.Gamepad1] = Enum.UserInputType.Gamepad1,
	[Enum.UserInputType.Gamepad2] = Enum.UserInputType.Gamepad1,
	[Enum.UserInputType.Gamepad3] = Enum.UserInputType.Gamepad1,
	[Enum.UserInputType.Gamepad4] = Enum.UserInputType.Gamepad1,
	[Enum.UserInputType.Gamepad5] = Enum.UserInputType.Gamepad1,
	[Enum.UserInputType.Gamepad6] = Enum.UserInputType.Gamepad1,
	[Enum.UserInputType.Gamepad7] = Enum.UserInputType.Gamepad1,
	[Enum.UserInputType.Gamepad8] = Enum.UserInputType.Gamepad1,
}

local lastInputType = inputTypeMaps[UserInputService:GetLastInputType()] or Enum.UserInputType.Keyboard

UserInputService.LastInputTypeChanged:Connect(function(inputType)
	local simplified = inputTypeMaps[inputType]
	
	if simplified and simplified ~= lastInputType then
		lastInputType = simplified
		
		mod.LastInputTypeChanged:Fire(lastInputType)
	end
end)

function mod.GetLastInputType()
	return lastInputType
end



function mod.__init(G)
	Game = G
end

local empty_table = { }
function mod.__build_signals(G, B)
	local function TransformTriggers(original_input: InputObject, new_input: InputObject2)
		if original_input.KeyCode == Enum.KeyCode.ButtonR2 and original_input.UserInputState ~= Enum.UserInputState.Change then
			new_input.KeyCode = Enum.KeyCode.Unknown
			new_input.UserInputType = Enum.UserInputType.MouseButton1
		elseif original_input.KeyCode == Enum.KeyCode.ButtonL2 and original_input.UserInputState ~= Enum.UserInputState.Change then
			new_input.KeyCode = Enum.KeyCode.Unknown
			new_input.UserInputType = Enum.UserInputType.MouseButton2
		end
	end
	
	local function TransformTouch(original_input: InputObject, new_input: InputObject2)
		-- @2.0 test if MouseMovement ends on mobile
		if original_input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		if Mobile.IsInputBoundToDetector("MovementDetector", original_input) then
			return
		end

		if original_input.UserInputState == Enum.UserInputState.Begin then
			if TouchResponsibleForMouse == false then
				new_input.UserInputType = Enum.UserInputType.MouseButton1
				TouchResponsibleForMouse = original_input
			end
		elseif TouchResponsibleForMouse == original_input then
			if original_input.UserInputState == Enum.UserInputState.Change then
				new_input.UserInputType = Enum.UserInputType.MouseMovement
			elseif original_input.UserInputState == Enum.UserInputState.End then
				new_input.UserInputType = Enum.UserInputType.MouseButton1
				TouchResponsibleForMouse = false
			end
		end
	end

	-- This function is handled customly in Mobile.lua if IsMobile == true
	-- Via the GestureDetector container within the file
	local function DetectGestures(original_input: InputObject, new_input: InputObject2)
		if new_input.UserInputType == Enum.UserInputType.MouseMovement then
			GestureDetector.GestureDataSubmittedThisTick = true

			if GestureDetector.IsReady ~= true then
				return
			end

			if UserInputService.MouseBehavior == Enum.MouseBehavior.Default then
				GestureDetector.ConsumePosition(original_input.Position)
			else
				GestureDetector.ConsumeDelta(original_input.Delta)
			end
		elseif new_input.KeyCode == Enum.KeyCode.Thumbstick2 then
			GestureDetector.GestureDataSubmittedThisTick = true

			if GestureDetector.IsReady ~= true then
				return
			end
			
			GestureDetector.ConsumeDelta(original_input.Position * 30)
		end
	end

	local function TransformInput(original_input: InputObject): InputObject2
		local new_input: InputObject2 = {
			Delta = original_input.Delta,
			KeyCode = original_input.KeyCode,
			AuxiliaryCode = false,
			Position = original_input.Position,
			UserInputState = original_input.UserInputState,
			UserInputType = original_input.UserInputType
		}

		-- Anyway here's how mobile touches are converted into more generic inputs
		TransformTouch(original_input, new_input)
		DetectGestures(original_input, new_input)
		
		TransformTriggers(original_input, new_input)

		return new_input
	end

	local function get_group<T>(input: InputObject2, pool: { [InputBasis]: Stack.Stack<T> }, aux: boolean?)
		if aux then
			return pool[input.AuxiliaryCode] or empty_table
		else
			return pool[input.UserInputType] or pool[input.KeyCode] or empty_table
		end
	end

	local function do_up_callback<T>(input, stack: {T}, logging: boolean?, return_on_handle: boolean?, processed): (boolean, T?)
		for i = #stack, 1, -1 do
			local listener = stack[i]
			local relevant_callback = listener.up_callback
			if relevant_callback and ((not processed) or listener.runsOnProcessed) then
				if logging then
					print("\t\t\t" .. listener.__SourceFile)
				end

				local ret = relevant_callback(input, processed)
				if ret == true and return_on_handle == true then
					return ret, listener
				end
			end
		end

		return false, nil
	end
	local function do_down_callback<T>(input, stack: {T}, logging: boolean?, return_on_handle: boolean?, processed): (boolean, T?)
		for i = #stack, 1, -1 do
			local listener = stack[i]
			local relevant_callback = listener.down_callback
			if relevant_callback and ((not processed) or listener.runsOnProcessed) then
				if logging then
					print("\t\t\t" .. listener.__SourceFile)
				end

				local ret = relevant_callback(input, processed)
				if ret == true and return_on_handle == true then
					return ret, listener
				end
			end
		end

		return false, nil
	end
	local function process_interception(listener: Intercept)
		listener.armed = true

		if listener.MaxIntercepts < math.huge then
			listener.InterceptCount += 1

			if listener.MaxIntercepts >= listener.InterceptCount then
				listener:Disconnect()
			end
		end
	end

	local function do_hooks(input, down: boolean, logging: boolean, processed: boolean)
		local hooks, aux_hooks = get_group(input, Hooks, false), get_group(input, Hooks, true)

		logging = logging and (#hooks > 0 or #aux_hooks > 0)
		if logging then
			print("\t\tHooks: " .. #hooks .. " KeyCodes, " .. #aux_hooks .. " AuxKeyCodes")
		end

		if down then
			do_down_callback(input, hooks, logging, false, processed)
			do_down_callback(input, aux_hooks, logging, false, processed)
		else
			do_up_callback(input, hooks, logging, false, processed)
			do_up_callback(input, aux_hooks, logging, false, processed)
		end
	end

	local function do_intercepts(input, down: boolean, logging: boolean, processed: boolean)
		local intercepted = false
		local intercepts, aux_intercepts = get_group(input, Intercepts, false), get_group(input, Intercepts, true)

		logging = logging and (#intercepts > 0 or #aux_intercepts > 0)
		if logging then
			print("\t\Intercepts: " .. #intercepts .. " KeyCodes, " .. #aux_intercepts .. " AuxKeyCodes")
		end

		if down then
			local sinker: Intercept? = nil
			intercepted, sinker = do_down_callback(input, intercepts, logging, true, processed)
			if intercepted and sinker then
				process_interception(sinker)
			end

			sinker = nil
			local did_sink = nil

			did_sink, sinker = do_down_callback(input, aux_intercepts, logging, true, processed)
			if did_sink and sinker then
				process_interception(sinker)
			end
		else
			local sinker: Intercept? = nil
			intercepted, sinker = do_up_callback(input, intercepts, logging, true, processed)
			if intercepted and sinker then
				process_interception(sinker)
			end

			sinker = nil
			local did_sink = nil

			did_sink, sinker = do_up_callback(input, aux_intercepts, logging, true, processed)
			if did_sink and sinker then
				process_interception(sinker)
			end
		end

		return intercepted
	end

	local function do_handlers(input, down: boolean, logging: boolean, processed: boolean)
		local handlers, aux_handlers = get_group(input, Handlers, false), get_group(input, Handlers, true)

		logging = logging and (#handlers > 0 or #aux_handlers > 0)
		if logging then
			print("\t\tHandlers: " .. #handlers .. " KeyCodes, " .. #aux_handlers .. " AuxKeyCodes")
		end

		if down then
			do_down_callback(input, handlers, logging, true, processed)
			do_down_callback(input, aux_handlers, logging, true, processed)
		else
			do_up_callback(input, handlers, logging, true, processed)
			do_up_callback(input, aux_handlers, logging, true, processed)
		end
	end

	-- TODO @2.0 fire off key up events when we open a menu
	-- TODO @Important testing the intercept functionality in regards to key up and down "armed" thing
	local function TransformedInputBegan(input: InputObject2, processed: boolean)
		local logging = if Config.LogInputProcessing and input.KeyCode then true else false
		if logging then
			local should_ignore: boolean? = Config.LogInputProcessingFilters.UserInputType[input.UserInputType]
			if should_ignore then logging = false end

			if logging then
				local kc = if typeof(input.KeyCode) == "EnumItem" then input.KeyCode.Name else input.KeyCode
				local it = if typeof(input.UserInputType) == "EnumItem" then input.UserInputType.Name else input.UserInputType
				print("🟩Processing input:\n\tKey: " .. kc .. " InputType: "	.. it)
			end
		end

		do_hooks(input, true, logging, processed)

		local intercepted = do_intercepts(input, true, logging, processed)

		if intercepted == false then
			do_handlers(input, true, logging, processed)
		end
	end

	local function RawInputBegan(input: InputObject, processed: boolean)
		TransformedInputBegan(TransformInput(input), processed)
	end

	local function TransformedInputEnded(input: InputObject2, processed: boolean)
		local logging = if Config.LogInputProcessing and input.KeyCode then true else false
		if logging then
			local should_ignore: boolean? = Config.LogInputProcessingFilters.UserInputType[input.UserInputType]
			if should_ignore then logging = false end

			if logging then
				local kc = if typeof(input.KeyCode) == "EnumItem" then input.KeyCode.Name else input.KeyCode
				local it = if typeof(input.UserInputType) == "EnumItem" then input.UserInputType.Name else input.UserInputType
				print("🟥Processing input:\n\tKey: " .. kc .. " InputType: "	.. it)
			end
		end

		do_hooks(input, false, logging, processed)

		local intercepted = do_intercepts(input, false, logging, processed)

		if intercepted == false then
			do_handlers(input, false, logging, processed)
		end
	end

	local function RawInputEnded(input: InputObject, processed: boolean)
		TransformedInputEnded(TransformInput(input), processed)
	end

	UserInputService.InputBegan:Connect(RawInputBegan)
	UserInputService.InputEnded:Connect(RawInputEnded)

	-- This connection handles the mousewheel
	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if input.UserInputState ~= Enum.UserInputState.Change then
			return
		end
		
		RawInputBegan(input, processed)
	end)

	local function release_all_inputs()
		for _, v in Enum.KeyCode:GetEnumItems() do
			RawInputEnded({
				Delta = Vector3.new(0, 0, 0),
				KeyCode = v,
				Position = Vector3.new(0, 0, 0),
				UserInputState = Enum.UserInputState.End,
				UserInputType = Enum.UserInputType.Keyboard
			})
		end
		for i, _ in CustomKeycodes do
			RawInputEnded({
				Delta = Vector3.new(0, 0, 0),
				KeyCode = i,
				Position = Vector3.new(0, 0, 0),
				UserInputState = Enum.UserInputState.End,
				UserInputType = Enum.UserInputType.Keyboard
			})
		end
	end

	local FocussedOnTextBox = false
	RunService:BindToRenderStep("CustomInput", Enum.RenderPriority.Input.Value - 1, function()
		for i,v in PendingCustomInputs do
			if v.UserInputState == Enum.UserInputState.End then
				TransformedInputEnded(v, false)
			else
				TransformedInputBegan(v, false)
			end
		end

		table.clear(PendingCustomInputs)

		if UserInputService:GetFocusedTextBox() ~= nil then
			if FocussedOnTextBox == false then
				release_all_inputs()
				FocussedOnTextBox = true
			end
		elseif FocussedOnTextBox == true then
			FocussedOnTextBox = false
		end
	end)

	UserInputService.WindowFocusReleased:Connect(release_all_inputs)
end

return mod
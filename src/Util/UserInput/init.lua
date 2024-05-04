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

local Config
local GestureDetector = require(script.GestureDetector)
local Enums = require(game.ReplicatedFirst.Util.Enums)
local AssociativeList = require(game.ReplicatedFirst.Util.AssociativeList)

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local mod = {
	Handlers = { },
	Intercepts = { },
	Hooks = { },
}

local PendingCustomInputs = { }

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
	[Enums.AuxiliaryInputCodes.InputGestures.Any] = true,
	[Enums.AuxiliaryInputCodes.InputGestures.Total] = true,
	[Enums.AuxiliaryInputCodes.InputGestures.Last] = true,
	[Enums.AuxiliaryInputCodes.KeyCodes.Any] = true,
	[Enums.UserInputType.DPad] = true,
}

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

local ListenerCreatedCallbacks = {
	
}

local ListenerDestroyedCallbacks = {
	
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


function ListenerType.new(type, down_callback, up_callback, keycode, max_ct)
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
		extra = { }
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

	return listener
end

type Intercept = typeof(ListenerType.new("Intercepts", nil, nil, Enum.KeyCode.A, 100))
type Hook = typeof(ListenerType.new("Hooks", nil, nil, Enum.KeyCode.A))
type Handler = typeof(ListenerType.new("Handlers", nil, nil, Enum.KeyCode.A))
type Listener = (Intercept | Hook | Handler)

function mod:Intercept(keycode, down_callback: routine, opt_up_callback: routine?, opt_max_ct: number?)
	if Config.LogInputListeners then
		local s,l,n = debug.info(1, "sln")
		print("New Intercept for `" .. tostring(keycode) .. "`\n\tFrom:\n" .. s .. ":" .. l .. " function " .. n .. "\n")
	end

	opt_max_ct = opt_max_ct or 1

	local listener = ListenerType.new("Intercepts", down_callback, opt_up_callback, keycode, opt_max_ct)
	mod.Intercepts[keycode]:push(listener)

	return listener
end

function mod:Hook(keycode, down_callback: routine, opt_up_callback: routine?)
	if Config.LogInputListeners then
		local s,l,n = debug.info(1, "sln")
		print("New Hook for `" .. tostring(keycode) .. "`\n\tFrom:\n" .. s .. ":" .. l .. " function " .. n .. "\n")
	end

	local listener = ListenerType.new("Hooks", down_callback, opt_up_callback, keycode)
	mod.Hooks[keycode]:push(listener)

	return listener
end

function mod:Handler(keycode, down_callback: routine, opt_up_callback: routine?)
	--local old_primary = mod.Listeners[keycode][1]
	if Config.LogInputListeners then
		local s,l,n = debug.info(1, "sln")
		print("New Handler for `" .. tostring(keycode) .. "`\n\tFrom:\n" .. s .. ":" .. l .. " function " .. n .. "\n")
	end

	local listener = ListenerType.new("Handlers", down_callback, opt_up_callback, keycode)
	mod.Handlers[keycode]:push(listener)

	return listener
end




function mod.CustomInputObject(keycode, opt_aux_code, input_state, input_type)
	assert(keycode)
	assert(input_state)
	assert(input_type)
	--TODO: Better aux code processing
	opt_aux_code = opt_aux_code or Enums.AuxiliaryInputCodes.KeyCodes.Any

	local t = {
		Delta = Vector3.new(),
		KeyCode = keycode,
		AuxiliaryCode = opt_aux_code,
		Position = Vector3.new(),
		UserInputState = input_state,
		UserInputType = input_type,
	}

	return t
end

function mod.TakeCustomInput(input)
	table.insert(PendingCustomInputs, input)
end

function mod.GetLastGesture()
	return GestureDetector.Last
end

function mod:__init(G)
	Game = G
	local Stack = G:Get("Stack")
	Config = G:Get("Config")
	GestureDetector = G:Get("GestureDetector")

	for i,v in Enum.KeyCode:GetEnumItems() do
		mod.Handlers[v] = Stack.new()
		mod.Hooks[v] = Stack.new()
		mod.Intercepts[v] = Stack.new()
	end
	for i,_ in CustomKeycodes do
		mod.Handlers[i] = Stack.new()
		mod.Hooks[i] = Stack.new()
		mod.Intercepts[i] = Stack.new()
	end
end



local empty_table = { }
function mod:__build_signals(G, B)
	local a = 1
	game:GetService("RunService").Stepped:Connect(function()
		a += 1
	end)

	local function TransformTriggers(original_input, new_input)
		if original_input.KeyCode == Enum.KeyCode.ButtonR2 and original_input.UserInputState ~= Enum.UserInputState.Change then
			new_input.KeyCode = Enum.KeyCode.Unknown
			new_input.UserInputType = Enum.UserInputType.MouseButton1
		elseif original_input.KeyCode == Enum.KeyCode.ButtonL2 and original_input.UserInputState ~= Enum.UserInputState.Change then
			new_input.KeyCode = Enum.KeyCode.Unknown
			new_input.UserInputType = Enum.UserInputType.MouseButton2
		end
	end

	-- This function is handled customly in Mobile.lua if IsMobile == true
	-- Via the GestureDetector container within the file
	local function DetectGestures(original_input, new_input)
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

	local function TransformInput(original_input: InputObject)
		local new_input = {
			Delta = original_input.Delta,
			KeyCode = original_input.KeyCode,
			-- Auxi
			AuxiliaryCode = false,
			Position = original_input.Position,
			UserInputState = original_input.UserInputState,
			UserInputType = original_input.UserInputType
		}

		DetectGestures(original_input, new_input)
		
		TransformTriggers(original_input, new_input)

		return new_input
	end

	local function get_group(input, pool: table, aux: boolean?)
		if aux then
			return pool[input.AuxiliaryCode] or empty_table
		else
			return pool[input.UserInputType] or pool[input.KeyCode] or empty_table
		end
	end

	local function do_up_callback(input, pool: table, logging: boolean?, return_on_handle: boolean?, processed)
		for i = #pool, 1, -1 do
			local listener: Listener = pool[i]
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
	local function do_down_callback(input, pool: table, logging: boolean?, return_on_handle: boolean?, processed)
		for i = #pool, 1, -1 do
			local listener: Listener = pool[i]
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
	local function process_interception(listener: Listener)
		listener.armed = true

		if listener.MaxIntercepts < math.huge then
			listener.InterceptCount += 1

			if listener.MaxIntercepts >= listener.InterceptCount then
				listener:Disconnect()
			end
		end
	end

	local function do_hooks(input, down: boolean, logging: boolean, processed: boolean)
		local hooks, aux_hooks = get_group(input, mod.Hooks, false), get_group(input, mod.Hooks, true)

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
		local intercepts, aux_intercepts = get_group(input, mod.Intercepts, false), get_group(input, mod.Intercepts, true)

		logging = logging and (#intercepts > 0 or #aux_intercepts > 0)
		if logging then
			print("\t\Intercepts: " .. #intercepts .. " KeyCodes, " .. #aux_intercepts .. " AuxKeyCodes")
		end

		if down then
			local sinker: Listener? = nil
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
			local sinker: Listener? = nil
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
		local handlers, aux_handlers = get_group(input, mod.Handlers, false), get_group(input, mod.Handlers, true)

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
	local function InputBegan(input: InputObject, processed: boolean, already_transformed: boolean?)
		if not already_transformed then
			input = TransformInput(input)
		end

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

	local function InputEnded(input: InputObject, processed: boolean, already_transformed: boolean?)
		if not already_transformed then
			input = TransformInput(input)
		end

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

	UserInputService.InputBegan:Connect(InputBegan)
	UserInputService.InputEnded:Connect(InputEnded)

	-- This connection handles the mousewheel
	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		input = TransformInput(input)
		
		if input.UserInputState ~= Enum.UserInputState.Change then
			return
		end
		
		InputBegan(input, processed, true)
	end)

	local function release_all_inputs()
		for _, v in Enum.KeyCode:GetEnumItems() do
			InputEnded({
				Delta = Vector3.new(0, 0, 0),
				KeyCode = v,
				Position = Vector3.new(0, 0, 0),
				UserInputState = Enum.UserInputState.End,
				UserInputType = Enum.UserInputType.Keyboard
			})
		end
		for i, _ in CustomKeycodes do
			InputEnded({
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
				InputEnded(v, false, true)
			else
				InputBegan(v, false, true)
			end
		end

		table.clear(PendingCustomInputs)

		if UserInputService:GetFocusedTextBox(self) ~= nil then
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
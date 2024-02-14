local RunService = game:GetService("RunService")

local mod = { }
local MobileButtonGroups = {
	Groups = {
		Meta = {
			Index = 1,
			Capacity = 5,
			Buttons = { }
		},
		Game1 = {
			Index = 2,
			Capacity = 5,
			Buttons = { }
		},
		Game2 = {
			Index = 3,
			Capacity = 8,
			Buttons = { }
		},
	}
}

local I, A, D
local MobileButtonUI
local CharacterInputUI
local UserInput
local Enums = _G.Game.Enums
local Assets

local CameraAreaIsActive, updCameraAreaIsActive

local CameraAreaIsActiveUsers = _G.Game.Maskables.Stack()
	:OnTopValueChanged(function(maskable)
		while not CharacterInputUI do task.wait() end

		if not maskable then
			updCameraAreaIsActive(true)
			return
		end

		local state = maskable[1]
		updCameraAreaIsActive(state)
	end)
	:FINISH()

function mod.PushCameraAreaIsActive(state)
	local wrapper = { state }
	CameraAreaIsActiveUsers:set(wrapper)

	return wrapper
end

function mod.RemoveCameraIsActiveMaskable(maskable)
	CameraAreaIsActiveUsers:remove(maskable)
end

local DPadUsers = _G.Game.Maskables.Stack()
	:OnTopValueChanged(function(user)
		while not CharacterInputUI do task.wait() end

		CharacterInputUI:setState({ DPadEnabled = if user then true else false })
	end)
	:FINISH()

local LeftGestureUsers = _G.Game.Maskables.Stack()
	:OnTopValueChanged(function(user)
		while not CharacterInputUI do task.wait() end
		
		CharacterInputUI:setState({ LeftGestureButton = if user then true else false })
	end)
	:FINISH()

local RightGestureUsers = _G.Game.Maskables.Stack()
	:OnTopValueChanged(function(user)
		while not CharacterInputUI do task.wait() end
		
		CharacterInputUI:setState({ RightGestureButton = if user then true else false })
	end)
	:FINISH()

local UpGestureUsers = _G.Game.Maskables.Stack()
	:OnTopValueChanged(function(user)
		while not CharacterInputUI do task.wait() end
		
		CharacterInputUI:setState({ UpGestureButton = if user then true else false })
	end)
	:FINISH()

local DownGestureUsers = _G.Game.Maskables.Stack()
	:OnTopValueChanged(function(user)
		while not CharacterInputUI do task.wait() end
		
		CharacterInputUI:setState({ DownGestureButton = if user then true else false })
	end)
	:FINISH()

local GestureUsers = {
	[Enums.InputGestures.Left] = LeftGestureUsers,
	[Enums.InputGestures.Right] = RightGestureUsers,
	[Enums.InputGestures.Up] = UpGestureUsers,
	[Enums.InputGestures.Down] = DownGestureUsers,
}

-- The reason that the gestures need specific/special pusher functions is that some codes find the users stack
-- based on listener.keycode whereas some of them use a more specific code to narrow down an auxiliary one
-- Thus we can't always just look up the keycode, nor do we want to always require specifying the specific code
local GestureUserPushers = {
	[Enums.AuxiliaryInputCodes.InputGestures.Any] = function(listener, maskable)
		local stack = GestureUsers[maskable[1]]
		stack:set(maskable)
	end,
	[Enums.InputGestures.Left] = function(listener, maskable)
		GestureUsers[listener.keycode]:set(maskable)
	end,
	[Enums.InputGestures.Right] = function(listener, maskable)
		GestureUsers[listener.keycode]:set(maskable)
	end,
	[Enums.InputGestures.Up] = function(listener, maskable)
		GestureUsers[listener.keycode]:set(maskable)
	end,
	[Enums.InputGestures.Down] = function(listener, maskable)
		GestureUsers[listener.keycode]:set(maskable)
	end,
}

local GestureUserRemovers = {
	[Enums.AuxiliaryInputCodes.InputGestures.Any] = function(listener, maskable)
		local stack = GestureUsers[maskable[1]]
		stack:remove(maskable)
	end,
	[Enums.InputGestures.Left] = function(listener, maskable)
		GestureUsers[listener.keycode]:remove(maskable)
	end,
	[Enums.InputGestures.Right] = function(listener, maskable)
		GestureUsers[listener.keycode]:remove(maskable)
	end,
	[Enums.InputGestures.Up] = function(listener, maskable)
		GestureUsers[listener.keycode]:remove(maskable)
	end,
	[Enums.InputGestures.Down] = function(listener, maskable)
		GestureUsers[listener.keycode]:remove(maskable)
	end,
}


function mod.PushDPadUser(listener)
	DPadUsers:set(listener)
end

function mod.RemoveDPadUser(listener)
	DPadUsers:remove(listener)
end


function mod.PushGestureButton(listener, maskable)
	GestureUserPushers[listener.keycode](listener, maskable) 
end

function mod.RemoveGestureButton(listener, maskable)
	GestureUserRemovers[listener.keycode](listener, maskable)
end


function mod:__init(G)
	UserInput = G.Load("UserInput")
	Enums = G.Load("Enums")
	Assets = G.Load("Assets")
end

mod.TouchDetectors = { }

function mod.IsInputBoundToDetector(name, input)
	local detector = mod.TouchDetectors[name]

	if not detector then
		return false
	end

	return detector.Toucher == input
end

function mod.IsPositionInDetector(name, position)
	local detector = mod.TouchDetectors[name]

	if not detector then
		return false
	end
	
	local object = detector.Ref:getValue()
	
	if not object then
		return false
	end
	
	return I:IsPositionInObject(position, object)
end

-- The difference between the next two functions is that ContinuousTouchDetector uses a frame update connection to call
-- the `update_callback` function, whereas the ChangedTouchDetector uses the frame's actual InputChanged event
-- 
-- The effective difference is that ContinuousTouchDetector will still promote Deltas even when the touch doesn't move
local function ContinuousTouchDetector(name, props, bind_callback, unbind_callback, update_callback)
	local ToucherData = {
		Name = name,
		Toucher = false,
		TouchConn = false,
		InitTouchPos = false,
		
		Ref = I:CreateRef()
	}

	mod.TouchDetectors[name] = ToucherData

	local function unbind_toucher(input)
		if input ~= ToucherData.Toucher then
			return
		end
		
		if unbind_callback then
			unbind_callback(ToucherData)
		end

		ToucherData.TouchConn:Disconnect()
		ToucherData.TouchConn = false
	end

	local function bind_toucher(input: InputObject)
		ToucherData.Toucher = input
		ToucherData.InitTouchPos = input.Position

		ToucherData.TouchConn = RunService.PreRender:Connect(function()
			if input.UserInputState == Enum.UserInputState.End or not input then
				unbind_toucher(input)
				return
			end

			if update_callback then
				update_callback(ToucherData)
			end
		end)

		if bind_callback then
			bind_callback(ToucherData)
		end
	end

	return I:Element("ContainerFrame", D(A(), I
		:Size(props.Size or UDim2.new(1, 0, 1, 0))
		:AnchorPoint(props.AnchorPoint or Vector2.new(0.5, 0.5))
		:Position(props.Position)
		:Active(props.Active or true)
		:BackgroundTransparency(1)
		:InputBegan(function(frame, input: InputObject)
			if input.UserInputState ~= Enum.UserInputState.Begin then
				return
			end

			if input.UserInputType == Enum.UserInputType.Touch then
				bind_toucher(input)
			end
		end)
		:Ref(ToucherData.Ref)
	))
end

local function ChangeTouchDetector(name, props, bind_callback, unbind_callback, update_callback)
	local ToucherData = {
		Name = name,
		Toucher = false,
		TouchConn = false,
		Props = props,
	}

	mod.TouchDetectors[name] = ToucherData

	local function unbind_toucher(input)
		if input ~= ToucherData.Toucher then
			return
		end
		
		if unbind_callback then
			unbind_callback(ToucherData)
		end

		ToucherData.TouchConn:Disconnect()
		ToucherData.TouchConn = false
	end

	local function bind_toucher(input: InputObject)
		ToucherData.Toucher = input
		ToucherData.InitTouchPos = input.Position

		ToucherData.TouchConn = RunService.PreRender:Connect(function()
			if input.UserInputState == Enum.UserInputState.End or not input then
				unbind_toucher(input)
				return
			end
		end)

		if bind_callback then
			bind_callback(ToucherData)
		end
	end

	return I:Element("ContainerFrame", D(A(), I
		:Size(props.Size or UDim2.new(1, 0, 1, 0))
		:AnchorPoint(props.AnchorPoint or Vector2.new(0.5, 0.5))
		:Position(props.Position)
		:Active(true)
		:BackgroundTransparency(1)
		:Ref(function(rbx) ref = rbx end)
		:InputBegan(function(frame, input: InputObject)
			if input.UserInputState ~= Enum.UserInputState.Begin then
				return
			end

			if input.UserInputType == Enum.UserInputType.Touch then
				bind_toucher(input)
			end
		end)
		:InputChanged(function(frame, input: InputObject)
			if input ~= ToucherData.Toucher then
				return
			end

			if input.UserInputState ~= Enum.UserInputState.Change then
				return
			end

			if input.UserInputType == Enum.UserInputType.Touch then
				if update_callback then
					update_callback(ToucherData)
				end
			end
		end)
	))
end

local function push_gesture(code)
	local input = UserInput.CustomInputObject(code, Enums.AuxiliaryInputCodes.InputGestures.Any, Enum.UserInputState.Change, Enums.UserInputType.Gesture)
	UserInput.TakeCustomInput(input)
	input = UserInput.CustomInputObject(Enum.UserInputType.MouseButton1, nil, Enum.UserInputState.Begin, Enum.UserInputType.MouseButton1)
	UserInput.TakeCustomInput(input)
	input = UserInput.CustomInputObject(Enum.UserInputType.MouseButton1, nil, Enum.UserInputState.End, Enum.UserInputType.MouseButton1)
	UserInput.TakeCustomInput(input)
end

function mod:__ui(G, i,a,d)
	I, A, D = i, a, d

	local Roact = G.Load("Roact")
	local GestureDetector = G.Load("GestureDetector")

	CameraAreaIsActive, updCameraAreaIsActive = I:Binding(true)
	local inner_pos, upd_inner_pos = I:Binding(UDim2.new(0, 0, 0, 0))
	local modal_pos, upd_modal_pos = I:Binding(UDim2.new(-1, 0, 0, 0))
	local modal_vis, upd_modal_vis = I:Binding(1)

	local function RenderMobileUI(self)
		local state = self.state

		if state.Enabled ~= true then
			return false
		end

		local enabled_elements = { }
		
		local square_aspect_ratio = 
			I:UIAspectRatioConstraint()
				:AspectRatio(1)
				:AspectType(Enum.AspectType.ScaleWithParentSize)
				:DominantAxis(Enum.DominantAxis.Height)

		if state.DPadEnabled then
			local modal = I:Element("ContainerFrame", D(A(), I
				:Size(0, 0, 0.08, 0)
				:AnchorPoint(0.5, 0.5)
				:Active(false)
				:ClipsDescendants(false)
				:BackgroundTransparency(1)
				:Position(modal_pos)

				:Children(
					square_aspect_ratio,

					I:Frame()
						:BackgroundColor3(Color3.new(44.7 / 255, 44.3 / 255, 45.1 / 255))
						:AnchorPoint(0.5, 0.5)
						:Position(0.5, 0, 0.5, 0)
						:Size(0.7, 0, 0.7, 0)
						:RoundCorners(1, 0)
						:Active(false),

					I:ImageButton()
						:AutoButtonColor(false)
						:BackgroundColor3(Color3.new(63.9 / 255, 63.5 / 255, 64.7 / 255))
						:AnchorPoint(0, 0)
						:RoundCorners(1, 0)
						:Size(1, -2, 1, -2)
						:Position(inner_pos:map(function(pos: UDim2)
							local dir = Vector2.new(pos.X.Offset, pos.Y.Offset)
							if dir.Magnitude > 42 then
								dir = dir.Unit
								dir *= 42
							end

							local clamped = UDim2.new(0, dir.X, 0, dir.Y)

							return clamped
						end))
						:Active(false)
					)
				)
			)

			local movement_detector = ContinuousTouchDetector("MovementDetector",
				{
					Size = UDim2.new(1, 0, 1, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0, 0, 1, 0)
				},
				function(toucher_data)
					local init_touch_pos = toucher_data.InitTouchPos
					upd_modal_pos(UDim2.new(0, init_touch_pos.X, 0, init_touch_pos.Y))
				end,
				function(toucher_data)
					local new_input = UserInput.CustomInputObject(Enums.UserInputType.DPad, nil, Enum.UserInputState.Change, Enums.UserInputType.DPad)
					new_input.Position = Vector3.new(0,0,0)
					UserInput.TakeCustomInput(new_input)
			
					upd_inner_pos(UDim2.new(0, 0, 0, 0))
					upd_modal_pos(UDim2.new(-1, 0, -1, 0))
					upd_modal_vis(1)
				end,
				function(toucher_data)
					local input = toucher_data.Toucher
					local init_touch_pos = toucher_data.InitTouchPos
					local delta = input.Position - init_touch_pos
	
					upd_inner_pos(UDim2.new(0, delta.X, 0, delta.Y))
					upd_modal_vis(0)
		
					local new_input = UserInput.CustomInputObject(Enum.KeyCode.Unknown, nil, Enum.UserInputState.Change, Enums.UserInputType.DPad)
					new_input.Position = delta
					UserInput.TakeCustomInput(new_input)
				end
			)

			movement_detector:RoundCorners(1, 0)

			table.insert(enabled_elements, movement_detector)
			table.insert(enabled_elements, modal)
		end



--[[ 		local LastPanPos = Vector3.new()
		local camera_detector = ContinuousTouchDetector("CameraMovementDetector",
			{
				Size = UDim2.new(0.5, 0, 0.66, 0),
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, 0, 1, 0),
				Active = CameraAreaIsActive
			},
			function(toucher_data)
				local input: InputObject = toucher_data.Toucher
				LastPanPos = input.Position
			end,
			nil,
			function(toucher_data)
				local input: InputObject = toucher_data.Toucher
				local delta = input.Position - LastPanPos

				if delta.Magnitude == 0 then
					return
				end

				local new_input = UserInput.CustomInputObject(Enum.UserInputType.MouseMovement, nil, input.UserInputState, Enum.UserInputType.MouseMovement)
				new_input.Delta = delta

				-- new_input.Position = input.Position
				UserInput.TakeCustomInput(new_input)
				LastPanPos = input.Position
			end
		) ]]

		table.insert(enabled_elements, camera_detector)



		local gesture_buttons = { }

		local gesture_button_size = 0.35
		local gesture_button_center = UDim2.new(0.5, 0, 0.5, 0)
		if state.LeftGestureButton then
			local b = I:ImageButton()
				:BackgroundTransparency(1)
				:Image(Assets.Images.GestureArrow)
				:Rotation(270)
				:Size(gesture_button_size, 0, gesture_button_size, 0)
				:AnchorPoint(1, 0.5)
				:Position(gesture_button_center + UDim2.new(-.1, 0, 0, 0))
				:Children(square_aspect_ratio)
				:TouchTap(function() push_gesture(Enums.InputGestures.Left) end)

			table.insert(gesture_buttons, b)
		end
		if state.RightGestureButton then
			local b = I:ImageButton()
				:BackgroundTransparency(1)
				:Image(Assets.Images.GestureArrow)
				:Rotation(90)
				:Size(gesture_button_size, 0, gesture_button_size, 0)
				:AnchorPoint(-1, 0.5)
				:Position(gesture_button_center + UDim2.new(.1, 0, 0, 0))
				:Children(square_aspect_ratio)
				:TouchTap(function() push_gesture(Enums.InputGestures.Right) end)

			table.insert(gesture_buttons, b)
		end
		if state.UpGestureButton then
			local b = I:ImageButton()
				:BackgroundTransparency(1)
				:Image(Assets.Images.GestureArrow)
				:Rotation(0)
				:Size(gesture_button_size, 0, gesture_button_size, 0)
				:AnchorPoint(0.5, 0)
				:Position(gesture_button_center)-- + UDim2.new(0, 0, -.1, 0))
				:Children(square_aspect_ratio)
				:TouchTap(function() push_gesture(Enums.InputGestures.Up) end)

			table.insert(gesture_buttons, b)
		end
		if state.DownGestureButton then
			local b = I:ImageButton()
				:BackgroundTransparency(1)
				:Image(Assets.Images.GestureArrow)
				:Rotation(180)
				:Size(gesture_button_size, 0, gesture_button_size, 0)
				:AnchorPoint(0.5, 0)
				:Position(gesture_button_center)-- + UDim2.new(0, 0, .1, 0))
				:Children(square_aspect_ratio)
				:TouchTap(function() push_gesture(Enums.InputGestures.Down) end)

			table.insert(gesture_buttons, b)
		end
		
		local gesture_container = ContinuousTouchDetector("GestureDetector",
			{
				Size = UDim2.new(1, 0, .5, 0),
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.new(0, 0, 0, 0),
			},
			function(toucher_data)
				local input = UserInput.CustomInputObject(Enum.UserInputType.MouseButton1, nil, Enum.UserInputState.Begin, Enum.UserInputType.MouseButton1)
				UserInput.TakeCustomInput(input)
			end,
			function(toucher_data)
				local input = UserInput.CustomInputObject(Enum.UserInputType.MouseButton1, nil, Enum.UserInputState.End, Enum.UserInputType.MouseButton1)
				UserInput.TakeCustomInput(input)
			end,
			function(toucher_data)
				GestureDetector.ConsumeDelta(toucher_data.Toucher.Delta)
			end)

		if #gesture_buttons > 0 then
			local gesture_button_container = I:Element("ContainerFrame", D(A(), I
				:Size(1/3, 0, 1/2, 0)
				:BackgroundTransparency(1)
				:JustifyRight(0, 0)
				:Active(false)
				:Children(
					I:UIAspectRatioConstraint()
						:AspectRatio(1.5)
						:AspectType(Enum.AspectType.ScaleWithParentSize)
						:DominantAxis(Enum.DominantAxis.Height),
					
					I:Fragment(gesture_buttons)
				)
			))

			gesture_container:Children(gesture_button_container)
		end

		table.insert(enabled_elements, gesture_container)

		local container = I:Element("ContainerFrame", D(A(), I
			:Size(1, 0, 1, 0)
			:BackgroundTransparency(1)
			:Children(I:Fragment(enabled_elements))
		))

		return container
	end

	local CharacterInputElement = I:Stateful("MobileCharacterInput", I
		:Init(function(self)
			CharacterInputUI = self

			local enabled = UserInput.IsMobile

			self:setState({
				Enabled = enabled,
				DPadEnabled = false,
				LeftGestureButton = false,
				RightGestureButton = false,
				UpGestureButton = false,
				DownGestureButton = false,
			})
		end)
		:Render(RenderMobileUI)
	)
	Roact.mount(Roact.createElement(CharacterInputElement), game.Players.LocalPlayer.PlayerGui.BaseInterface)

	local function RenderMobileButtonUI(self)
		local state = self.state

		local elements = { }

		local button_ct = 0
		local function draw_button(group, cfg, button_idx, gropu_button_ct, ratio)
			button_ct += 1

			local dist = group.Index * 0.11
			local range = math.pi
			local angle = range * 3/2 + range * ratio - (range / (gropu_button_ct * 2))
			local x = 0.0 + dist * math.cos(angle)
			local y = 0.5 + dist * math.sin(angle)
			local p = Vector2.new(x, y)

			local b = I:Element("TextButton", D(A(), I
				:Size(0.1, 0, 0.1, 0)
				:Text(cfg.Label)
				:AnchorPoint(0.5, 0.5)
				:Position(p.X, 0, p.Y, 0)
				:Prop("RoundingScale", 1)
				:Active(true)
				:Prop("InputBegan", function(rbx, input: InputObject)
					if cfg.DownCallback and input.UserInputType == Enum.UserInputType.Touch then
						cfg.DownCallback()
					end
				end)
				:Prop("InputEnded", function(rbx, input: InputObject)
					if cfg.UpCallback and input.UserInputType == Enum.UserInputType.Touch then
						cfg.UpCallback()
					end
				end)
				:Children(
					I:UIAspectRatioConstraint()
						:AspectRatio(1)
						:AspectType(Enum.AspectType.ScaleWithParentSize)
						:DominantAxis(Enum.DominantAxis.Height)
				)
			))

			b:RoundCorners(1, 0)

			table.insert(elements, b)
		end

		local function draw_group(group)
			local len = #group.Buttons
			for i,v in group.Buttons do
				draw_button(group, v, i, len, i / len)
			end
		end	

		for i,v in state.Groups do
			draw_group(v)
		end

		if button_ct == 0 then
			return false
		end

		local tree = I:Element("ContainerFrame", D(A(), I
			:Size(0.5, 0, 1, 0)
			:AnchorPoint(0, 0.5)
			:Position(0, 0, 0.5, 0)
			:Children(
				I:Fragment(elements),
				-- If the container's aspect ratio isn't 1, then the button placement code will be distorted
				I:UIAspectRatioConstraint()
					:AspectRatio(1)
					:AspectType(Enum.AspectType.FitWithinMaxSize)
					:DominantAxis(Enum.DominantAxis.Height)
			)
		))

		return tree
	end 

	local MobileButtonElement = I:Stateful("MobileButtons", I
		:Init(function(self)
			MobileButtonUI = self
		
			self:setState(MobileButtonGroups)
		end)
		:Render(RenderMobileButtonUI)
	)
	Roact.mount(Roact.createElement(MobileButtonElement), game.Players.LocalPlayer.PlayerGui.BaseInterface)
end

function mod.AddButton(name, group_name, down_callback, up_callback)
	if not UserInput.IsMobile then
		return
	end

	local group = MobileButtonGroups.Groups[group_name]
	if not group then
		error("No mobile button group `" .. group_name .. "`")
	end

	if #group.Buttons >= group.Capacity then
		error("Mobile button group `" .. group_name .. "` is full")
	end

	table.insert(group.Buttons, {
		Label = name,
		DownCallback = down_callback,
		UpCallback = up_callback
	})

	MobileButtonUI:setState(MobileButtonGroups)
end

function mod.DoesButtonExist(name, group_name)
	local group = MobileButtonGroups.Groups[group_name]

	local found = false
	for i,v in group.Buttons do
		if v.Label == name then
			found = true

			break
		end
	end
	
	return found
end

function mod.RemoveButton(name, group_name)
	if not UserInput.IsMobile then
		return
	end

	local group = MobileButtonGroups.Groups[group_name]

	local found = false
	for i,v in group.Buttons do
		if v.Label == name then
			table.remove(group.Buttons, i)
			found = true

			break
		end
	end

	if not found then
		error("Tried to remove mobile button `" .. name .. "` from group `" .. group_name .. "` but it was not found")
	end

	MobileButtonUI:setState(MobileButtonGroups)
end

function mod:__build_signals(G, B)
	if not UserInput.IsMobile then
		return
	end

	local FocusUtil = G.Load("ScreenFocusUtil")

	local function show_gesture_tutorial()
		FocusUtil.RunFocusList(
			function()
				local tree = {
					FocusUtil.AreaFocus(UDim2.new(0, 5, 0.5, 5), UDim2.new(0.5, -5, 1, -5)),
					FocusUtil.TextLabel({
						Text = "Character movement region",
						Position = UDim2.new(1/4, 0, 0.4, 0)
					})
				}

				return tree
			end,
			function()
				local tree = {
					FocusUtil.AreaFocus(UDim2.new(0.5, 5, 0.5, 5), UDim2.new(1, -5, 1, -5)),
					FocusUtil.TextLabel({
						Text = "Camera movement region",
						Position = UDim2.new(3/4, 0, 0.4, 0)
					})
				}

				return tree
			end,
			function()
				local tree = {
					FocusUtil.AreaFocus(UDim2.new(0, 5, 0, 5), UDim2.new(1, -5, 0.5, -5)),
					FocusUtil.TextLabel({
						Text = "Attack input region",
						Position = UDim2.new(0.5, 0, 0.6, 0)
					})
				}

				return tree
			end
		)
	end
end

return mod
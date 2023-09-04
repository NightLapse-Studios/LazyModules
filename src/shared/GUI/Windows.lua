--!strict
--[[
	Windows are pretty straight forward, but there is an oddity in their design.

	What you see below largely looks like a stateful roact class, except without actually using Roact.Component:Extend( ... ).
	Instead, the users of a window are to implement a stateful class (if their UI needs it, anyway) which creates a window in its initializer
		and, when it renders, calls `Windows.SetBody( Window, Array<RoactElement> )`
		where the Array<RoactElement> is the results of the render operation for your window-using class

	The SetBody function will store the *final window roact tree* in `Window.RoactTree`. Therefore, the user of a window must use that
		as its render result

	E.G.:
```
	Windows = require( <...>.Windows )
	SkillUI.Window = Windows.new("Skill Builder")

	function SkillUI:render()
		--< do some stuff >
		SkillUI.Window:SetBody( skillListArea )

		return SkillUI.Window.RoactTree
	end
```

	All of this is to avoid complexity with mounting, un mounting, external `setState` workarounds, etc.
	Also there are some concerns with having a variable amount of stateful roact components being created spontaneously at run-time.
]]

local Style
local Roact = _G.Game.PreLoad(game.ReplicatedFirst.Modules.Roact)
local MouseIcon = _G.Game.PreLoad(game.ReplicatedFirst.Modules.MouseIcon)
local Assets = _G.Game.PreLoad(game.ReplicatedFirst.Modules.Assets)
local GUI = _G.Game.PreLoad(script.Parent)

local Mouse = game.Players.LocalPlayer:GetMouse()

local Windows = { }
local WindowGUI = game.Players.LocalPlayer.PlayerGui:WaitForChild("Windows")

--[[
	Windows themselves now
]]

local lastZIndex = 1

local ScalingEdgeEnum = {
	Left = 1,
	Right = 2,
	Top = 3,
	Bottom = 4,
	Center = 5
}
local ScalingState = { IsScaling = false, Origin = -1, XScaleType = -1, YScaleType = -1, Window = -1, DisplayFrame = -1}

local function BeginScaling( window: Window, x, y, x_side, y_side )
	ScalingState.IsScaling = true
	ScalingState.Origin = Vector2.new(x, y)
	ScalingState.XScaleType = x_side
	ScalingState.YScaleType = y_side
	ScalingState.Window = window

	local window_pos = GUI.ScaleToOffset(window.Position:getValue())
	local window_size = window.Size:getValue()
	local LAnchor, RAnchor = 0, 0
	local LPos, RPos = window_pos.X.Offset, window_pos.Y.Offset
	if x_side == ScalingEdgeEnum.Left then
		LAnchor = 1
		LPos = LPos + window_size.X.Offset
	end
	if y_side == ScalingEdgeEnum.Top then
		RAnchor = 1
		RPos = RPos + window_size.Y.Offset
	end

	--print(LAnchor, RAnchor)
	ScalingState.DisplayFrame = Instance.new("Frame", WindowGUI)
	ScalingState.DisplayFrame.AnchorPoint = Vector2.new(LAnchor, RAnchor)
	ScalingState.DisplayFrame.Position = UDim2.new(0, LPos, 0, RPos)
	ScalingState.DisplayFrame.BackgroundTransparency = 0.5
end

local function ResetScalingState()
	ScalingState.IsScaling = false
	ScalingState.Origin = -1
	ScalingState.XScaleType = -1
	ScalingState.YScaleType = -1
	ScalingState.Window = -1

	if ScalingState.DisplayFrame ~= -1 then
		ScalingState.DisplayFrame:Destroy()
	end
	ScalingState.DisplayFrame = -1
end

local function UnSetIcon(ref)
	if ref then
		MouseIcon.UnSetIcon(ref)
	end
end

function Windows.EndScaling( input: InputObject )
	--This checks for if the mouse was simply released over the scaler without any click on it
	if not ScalingState.IsScaling then
		ResetScalingState()
		return
	end

	local window = ScalingState.Window
	local scale_start = ScalingState.Origin
	local XScaleType, YScaleType = ScalingState.XScaleType, ScalingState.YScaleType

	local oldpos: UDim2, oldsize: UDim2 = GUI.ScaleToOffset(window.Position:getValue()), window.Size:getValue()

	local old_xpos, old_ypos, old_xsize, old_ysize = oldpos.X.Offset, oldpos.Y.Offset, oldsize.X.Offset, oldsize.Y.Offset
	local new_xpos, new_ypos, new_xsize, new_ysize

	if XScaleType == ScalingEdgeEnum.Left then
		new_xpos = math.clamp(input.Position.X, old_xpos + old_xsize - window.ClampWidth.Max, old_xpos + old_xsize - window.ClampWidth.Min)
		new_xsize = math.clamp(old_xsize - (input.Position.X - scale_start.X), window.ClampWidth.Min, window.ClampWidth.Max)
	elseif XScaleType == ScalingEdgeEnum.Right then
		new_xpos = old_xpos
		new_xsize = math.clamp(old_xsize + (input.Position.X - scale_start.X), window.ClampWidth.Min, window.ClampWidth.Max)
	else
		new_xpos = old_xpos
		new_xsize = old_xsize
	end

	if YScaleType == ScalingEdgeEnum.Top then
		new_ypos = math.clamp(input.Position.Y, old_ypos + old_ysize - window.ClampHeight.Max, old_ypos + old_ysize - window.ClampHeight.Min)
		new_ysize = math.clamp(old_ysize - (input.Position.Y - scale_start.Y), window.ClampHeight.Min, window.ClampHeight.Max)
	elseif YScaleType == ScalingEdgeEnum.Bottom then
		new_ypos = old_ypos
		new_ysize = math.clamp(old_ysize + (input.Position.Y - scale_start.Y), window.ClampHeight.Min, window.ClampHeight.Max)
	else
		new_ypos = old_ypos
		new_ysize = old_ysize
	end

	window.UpdatePosition(GUI.OffsetToScale(UDim2.new(0, new_xpos, 0, new_ypos)))
	window.UpdateSize(UDim2.new(0, new_xsize, 0, new_ysize))
	
	UnSetIcon(window.LeftMouseIconRef)
	UnSetIcon(window.RightMouseIconRef)
	UnSetIcon(window.TopMouseIconRef)
	UnSetIcon(window.BottomMouseIconRef)
	UnSetIcon(window.TLMouseIconRef)
	UnSetIcon(window.TRMouseIconRef)
	UnSetIcon(window.BLMouseIconRef)
	UnSetIcon(window.BRMouseIconRef)
	
	ResetScalingState()
	
	if window.OnChangeSize then
		window.OnChangeSize(window)
	end
end

local MovingState = { IsMoving = false, Offset = -1, Window = -1 }

function Windows.EndMoving()
	MovingState.IsMoving = false
	MovingState.Offset = -1
	MovingState.Window = -1
end

local function OpenWindow( window: Window )
	window.IsOpen = true
	
	lastZIndex += 1
	window.UpdateZIndex(lastZIndex)
	
	if window.OnOpen then
		window:OnOpen()
	end
end

local function CloseWindow( window: Window )
	window.IsOpen = false
	if window.OnClose then
		window:OnClose()
	end
end

local function ToggleWindow( window: Window )
	if window.IsOpen == true then
		window:CloseWindow()
	else
		window:OpenWindow()
	end
end

function DestroyWindow( window: Window )
	--This is all that this function can do, it is still up to the caller to free all references
	--	or **the window will stay allocated**
	window:Close()
	table.remove(ManagedWindows, table.find(ManagedWindows, window))
end

--local TextService = game:GetService("TextService")
local TitleLeftPad = 8
local TitleRightPad
local MinimizeButtonPad = 14
local WindowLabelFontSize = 19
local ResizeThickness = 6
local Resize_PosAdjustment = 2
local Resize_SizeAdjustment = 2
local WindowBorderSize = 1

local function RenderWindow( window: Window )
	if window.IsOpen == false then
		window.RoactTree = false
		return
	end
	
	local topBar
	
	if window.CustomHeaderProps then
		
		local old = window.CustomHeaderProps[Roact.Event.MouseButton1Down]
		window.CustomHeaderProps[Roact.Event.MouseButton1Down] = function(...)
			if old then
				old(...)
			end
			
			if not window.DisableMoving then
				MovingState.IsMoving = true
				MovingState.Offset = GUI.ScaleToOffset(window.Position:getValue()) - UDim2.new(0, Mouse.X, 0, Mouse.Y)
				MovingState.Window = window
			end
			
			if lastZIndex ~= window.ZIndex:getValue() or lastZIndex == 1 then
				lastZIndex += 1
				window.UpdateZIndex(lastZIndex)
			end
		end
		
		topBar = Roact.createElement(GUI.StdImageButton, window.CustomHeaderProps)
	else
		local Label = Roact.createElement("TextLabel", {
			Size = UDim2.new(1, -(TitleLeftPad + TitleRightPad), 1, 0),
			Position = UDim2.new(0, TitleLeftPad, 0, 0),
			BorderSizePixel = 1,
			BorderColor3 = Style.WindowBorderColor,
			TextColor3 = Style.ActiveTextColor,
			BackgroundTransparency = 1.0,
			Text = window.Title,
			TextSize = WindowLabelFontSize,
			Font = Style.LabelFont,
			LineHeight = 1.1,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextScaled = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center
		})
	
	
		local HideButton = Roact.createElement(GUI.StdImageButton, {
			Size = UDim2.new(0, TitleRightPad - MinimizeButtonPad, 0, TitleRightPad - MinimizeButtonPad),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -(MinimizeButtonPad / 2), 0, MinimizeButtonPad / 2),
			BorderSizePixel = 0,
			BackgroundTransparency = 1.0,
			Image = Assets.Images.Close,
			Active = true,
			[Roact.Event.MouseButton1Click] = function()
				CloseWindow(window)
			end
			--[Roact.Eve]
		})
		
		topBar = Roact.createElement(GUI.StdImageButton, {
			Size = UDim2.new(1, 0, 0, Style.StdHeaderHeight),
			AutoButtonColor = false,
			BackgroundColor3 = Style.SecondaryColor4,
			BorderSizePixel = 0,
			[Roact.Event.MouseButton1Down] = function()
				if not window.DisableMoving then
					MovingState.IsMoving = true
					MovingState.Offset = GUI.ScaleToOffset(window.Position:getValue()) - UDim2.new(0, Mouse.X, 0, Mouse.Y)
					MovingState.Window = window
				end
				
				if lastZIndex ~= window.ZIndex:getValue() or lastZIndex == 1 then
					lastZIndex += 1
					window.UpdateZIndex(lastZIndex)
				end
			end,
			[Roact.Event.MouseButton1Up] = function()
				Windows.EndMoving()
			end
		},{
			Label,
			HideButton
		})
	end
	
	local mainBodyHeight
	if window.CustomHeaderProps then
		if window.CustomHeaderProps.Visible == false then
			mainBodyHeight = 0
		else
			mainBodyHeight = -window.CustomHeaderProps.Size.Y.Offset
		end
	else
		mainBodyHeight = -Style.StdHeaderHeight
	end
	
	window.RoactTree = Roact.createElement("Frame", {
		Size = window.Size,
		Position = window.Position,
		BackgroundTransparency = window.BackgroundHidden and 1 or 0,
		BorderSizePixel = window.BorderHidden and 0 or WindowBorderSize,
		BorderColor3 = Style.WindowBorderColor,
		ZIndex = window.ZIndex
	}, {
		--Topbar
		topBar,

		--Main body
		Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, mainBodyHeight),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			BackgroundTransparency = 1,
		}, {
			Roact.createElement((window.BackgroundHidden and "Frame" or (window.NoScrolling and "Frame" or GUI.StandardXYScrollingFrame)), {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = window.BackgroundHidden and 1 or 0,
				BackgroundColor3 = Style.SecondaryColor1,
				BorderColor3 = Style.WindowBorderColor,
			}, {
				--This frame exists to account for scroll bar thickness. The caller does not need to consider the scroll bar.
				Roact.createElement("Frame", {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1
				},{
					window.Body
				})
			}),
		}),

		--[[
			Edge resize frames
		]]
		--Left-Resize
		Roact.createElement(GUI.StdImageButton, {
			Size = UDim2.new(0, ResizeThickness, 1, -Resize_SizeAdjustment),
			Position = UDim2.new(0, -Resize_PosAdjustment, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BorderSizePixel = 0,
			BackgroundTransparency = 1.0,
			AutoButtonColor = false,
			Active = true,
			Visible = table.find(window.WhitelistedDraggers, "L") and true or false,
			[Roact.Event.MouseButton1Down] = function(x, y)
				BeginScaling(window, Mouse.X, Mouse.Y, ScalingEdgeEnum.Left, ScalingEdgeEnum.Center)
			end,
			[Roact.Event.MouseEnter] = function()
				if not ScalingState.IsScaling then
					window.LeftMouseIconRef = MouseIcon.SetIcon(Assets.Images.MouseIcons.ResizeWE, true)
				end
			end,
			[Roact.Event.MouseLeave] = function()
				if not ScalingState.IsScaling then
					MouseIcon.UnSetIcon(window.LeftMouseIconRef)
				end
			end
		}),
		--Right-Resize
		Roact.createElement(GUI.StdImageButton, {
			Size = UDim2.new(0, ResizeThickness, 1, -Resize_SizeAdjustment),
			Position = UDim2.new(1, Resize_PosAdjustment, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BorderSizePixel = 0,
			BackgroundTransparency = 1.0,
			AutoButtonColor = false,
			Active = true,
			Visible = table.find(window.WhitelistedDraggers, "R") and true or false,
			[Roact.Event.MouseButton1Down] = function(x, y)
				BeginScaling(window, Mouse.X, Mouse.Y, ScalingEdgeEnum.Right, ScalingEdgeEnum.Center)
			end,
			[Roact.Event.MouseEnter] = function()
				if not ScalingState.IsScaling then
					window.RightMouseIconRef = MouseIcon.SetIcon(Assets.Images.MouseIcons.ResizeWE, true)
				end
			end,
			[Roact.Event.MouseLeave] = function()
				if not ScalingState.IsScaling then
					MouseIcon.UnSetIcon(window.RightMouseIconRef)
				end
			end
		}),
		--Top-Resize
		Roact.createElement(GUI.StdImageButton, {
			Size = UDim2.new(1, -Resize_SizeAdjustment, 0, ResizeThickness),
			Position = UDim2.new(0.5, 0, 0, -Resize_PosAdjustment),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BorderSizePixel = 0,
			BackgroundTransparency = 1.0,
			AutoButtonColor = false,
			Active = true,
			Visible = table.find(window.WhitelistedDraggers, "T") and true or false,
			[Roact.Event.MouseButton1Down] = function(x, y)
				BeginScaling(window, Mouse.X, Mouse.Y, ScalingEdgeEnum.Center, ScalingEdgeEnum.Top)
			end,
			[Roact.Event.MouseEnter] = function()
				if not ScalingState.IsScaling then
					window.TopMouseIconRef = MouseIcon.SetIcon(Assets.Images.MouseIcons.ResizeNS, true)
				end
			end,
			[Roact.Event.MouseLeave] = function()
				if not ScalingState.IsScaling then
					MouseIcon.UnSetIcon(window.TopMouseIconRef)
				end
			end
		}),
		--Bottom-Resize
		Roact.createElement(GUI.StdImageButton, {
			Size = UDim2.new(1, -Resize_SizeAdjustment, 0, ResizeThickness),
			Position = UDim2.new(0.5, 0, 1, Resize_PosAdjustment),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BorderSizePixel = 0,
			BackgroundTransparency = 1.0,
			AutoButtonColor = false,
			Active = true,
			Visible = table.find(window.WhitelistedDraggers, "B") and true or false,
			[Roact.Event.MouseButton1Down] = function(x, y)
				BeginScaling(window, Mouse.X, Mouse.Y, ScalingEdgeEnum.Center, ScalingEdgeEnum.Bottom)
			end,
			[Roact.Event.MouseEnter] = function()
				if not ScalingState.IsScaling then
					window.BottomMouseIconRef = MouseIcon.SetIcon(Assets.Images.MouseIcons.ResizeNS, true)
				end
			end,
			[Roact.Event.MouseLeave] = function()
				if not ScalingState.IsScaling then
					MouseIcon.UnSetIcon(window.BottomMouseIconRef)
				end
			end
		}),
		--[[
			Corner resize frames
		]]
		--Top-Left Resize
		Roact.createElement(GUI.StdImageButton, {
			Size = UDim2.new(0, ResizeThickness, 0, ResizeThickness),
			Position = UDim2.new(0, -Resize_PosAdjustment, 0, -Resize_PosAdjustment),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BorderSizePixel = 0,
			BackgroundTransparency = 1.0,
			AutoButtonColor = false,
			Active = true,
			Visible = table.find(window.WhitelistedDraggers, "TL") and true or false,
			[Roact.Event.MouseButton1Down] = function(x, y)
				BeginScaling(window, Mouse.X, Mouse.Y, ScalingEdgeEnum.Left, ScalingEdgeEnum.Top)
			end,
			[Roact.Event.MouseEnter] = function()
				if not ScalingState.IsScaling then
					window.TLMouseIconRef = MouseIcon.SetIcon(Assets.Images.MouseIcons.ResizeNWSE, true)
				end
			end,
			[Roact.Event.MouseLeave] = function()
				if not ScalingState.IsScaling then
					MouseIcon.UnSetIcon(window.TLMouseIconRef)
				end
			end
		}),
		--Top-Right Resize
		Roact.createElement(GUI.StdImageButton, {
			Size = UDim2.new(0, ResizeThickness, 0, ResizeThickness),
			Position = UDim2.new(1, Resize_PosAdjustment, 0, -Resize_PosAdjustment),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BorderSizePixel = 0,
			BackgroundTransparency = 1.0,
			AutoButtonColor = false,
			Active = true,
			Visible = table.find(window.WhitelistedDraggers, "TR") and true or false,
			[Roact.Event.MouseButton1Down] = function(x, y)
				BeginScaling(window, Mouse.X, Mouse.Y, ScalingEdgeEnum.Right, ScalingEdgeEnum.Top)
			end,
			[Roact.Event.MouseEnter] = function()
				if not ScalingState.IsScaling then
					window.TRMouseIconRef = MouseIcon.SetIcon(Assets.Images.MouseIcons.ResizeSWNE, true)
				end
			end,
			[Roact.Event.MouseLeave] = function()
				if not ScalingState.IsScaling then
					MouseIcon.UnSetIcon(window.TRMouseIconRef)
				end
			end
		}),
		--Bottom-Left Resize
		Roact.createElement(GUI.StdImageButton, {
			Size = UDim2.new(0, ResizeThickness, 0, ResizeThickness),
			Position = UDim2.new(0, -Resize_PosAdjustment, 1, Resize_PosAdjustment),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BorderSizePixel = 0,
			BackgroundTransparency = 1.0,
			AutoButtonColor = false,
			Active = true,
			Visible = table.find(window.WhitelistedDraggers, "BL") and true or false,
			[Roact.Event.MouseButton1Down] = function(x, y)
				BeginScaling(window, Mouse.X, Mouse.Y, ScalingEdgeEnum.Left, ScalingEdgeEnum.Bottom)
			end,
			[Roact.Event.MouseEnter] = function()
				if not ScalingState.IsScaling then
					window.BLMouseIconRef = MouseIcon.SetIcon(Assets.Images.MouseIcons.ResizeSWNE, true)
				end
			end,
			[Roact.Event.MouseLeave] = function()
				if not ScalingState.IsScaling then
					MouseIcon.UnSetIcon(window.BLMouseIconRef)
				end
			end
		}),
		--Bottom-Right Resize
		Roact.createElement(GUI.StdImageButton, {
			Size = UDim2.new(0, ResizeThickness, 0, ResizeThickness),
			Position = UDim2.new(1, Resize_PosAdjustment, 1, Resize_PosAdjustment),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BorderSizePixel = 0,
			BackgroundTransparency = 1.0,
			AutoButtonColor = false,
			Active = true,
			Visible = table.find(window.WhitelistedDraggers, "BR") and true or false,
			[Roact.Event.MouseButton1Down] = function(x, y)
				BeginScaling(window, Mouse.X, Mouse.Y, ScalingEdgeEnum.Right, ScalingEdgeEnum.Bottom)
			end,
			[Roact.Event.MouseEnter] = function()
				if not ScalingState.IsScaling then
					window.BRMouseIconRef = MouseIcon.SetIcon(Assets.Images.MouseIcons.ResizeNWSE, true)
				end
			end,
			[Roact.Event.MouseLeave] = function()
				if not ScalingState.IsScaling then
					MouseIcon.UnSetIcon(window.BRMouseIconRef)
				end
			end
		}),
	})
end

local function SetWindowBody( window: Window, element_tbl: Array<RoactElement> )
	window.Body = element_tbl
	RenderWindow(window)
end

function Windows.newWindow(
		title: string,
		pixWidth: number,
		pixHeight: number,
		OnCloseFunc: (Window) -> nil,
		OnOpenFunc: (Window) -> nil,
		dont_manage: boolean,
		OnChangeSizeFunc: (Window) -> nil,
		clampWidth: NumberRange,
		clampHeight: NumberRange,
		initialPosition: UDim2,
		whitelistedDraggers: {[number]: string},-- "T", "L", "TL", "BR", etc. If there is any whitelisted draggers, the window wont be draggable.
		customHeaderProps: RoactProps,
		BorderHidden: boolean,
		BackgroundHidden: boolean,
		NoScrolling: boolean
 	): Window
	
	local doDisableMoving = whitelistedDraggers and #whitelistedDraggers > 0
	 
	local window: Window = {
		--Properties of the UI itself
		Position = false,
		UpdatePosition = false,
		Size = false,
		UpdateSize = false,
		ZIndex = false,
		UpdateZIndex = false,
		
		ClampWidth = clampWidth or NumberRange.new(150, 1920),
		ClampHeight = clampHeight or NumberRange.new(150, 1080),
		WhitelistedDraggers = whitelistedDraggers or {"T", "B", "R", "L", "TL", "TR", "BL", "BR"},
		CustomHeaderProps = customHeaderProps,
		BorderHidden = BorderHidden,
		DisableMoving = doDisableMoving,
		BackgroundHidden = BackgroundHidden,
		NoScrolling = NoScrolling,
		
		Title = title,

		--Internal UI properties
		_window_frame = Roact.createRef(),
		_dont_manage = dont_manage,
		IsOpen = false,

		--Windows functions
		SetBody = SetWindowBody,
		CloseWindow = CloseWindow,
		OpenWindow = OpenWindow,
		ToggleWindow = ToggleWindow,
		Destroy = DestroyWindow,

		--Callbacks
		OnClose = OnCloseFunc,
		OnOpen = OnOpenFunc,
		OnChangeSize = OnChangeSizeFunc,

		LeftMouseIconRef = false,
		RightMouseIconRef = false,
		TopMouseIconRef = false,
		BottomMouseIconRef = false,

		TLMouseIconRef = false,
		TRMouseIconRef = false,
		BLMouseIconRef = false,
		BRMouseIconRef = false,

		IsMoving = false,
		MovingOffset = false,

		Body = false,
		RoactTree = false
	}
	
	if initialPosition == UDim2.new(0.5,0,0.5,0) then
		window.Position, window.UpdatePosition = Roact.createBinding(GUI.OffsetToScale(UDim2.new(0.5,-pixWidth/2,0.5,-pixHeight/2)))
	else
		window.Position, window.UpdatePosition = Roact.createBinding(initialPosition and GUI.OffsetToScale(initialPosition) or UDim2.new(0.03,0,0.03,0))
	end
	
	window.Size, window.UpdateSize = Roact.createBinding(UDim2.new(0, pixWidth, 0, pixHeight))
	window.ZIndex, window.UpdateZIndex = Roact.createBinding(1)

	return window
end

--The simplest way to allow windows to move is to set its state to moving and update its position on each frame,
--  rather than set its state and connect/disconnect to mouse movement events. Ew
local function update( dt )

	if MovingState.IsMoving then
		local window = MovingState.Window
		window.UpdatePosition( GUI.OffsetToScale(UDim2.new(0, Mouse.X, 0, Mouse.Y) + MovingState.Offset ))
	end

	if ScalingState.IsScaling then
		--By positioning anchorpoints based on which edges are scaling, we only have to update the size of the display frame here.
		local DisplayFrame = ScalingState.DisplayFrame
		
		local window = ScalingState.Window
		
		local window_size = ScalingState.Window.Size:getValue()
		local window_pos = GUI.ScaleToOffset(ScalingState.Window.Position:getValue())
		local x_size, y_size
		
		if ScalingState.XScaleType == ScalingEdgeEnum.Left then
			x_size = math.clamp(DisplayFrame.Position.X.Offset - Mouse.X, window.ClampWidth.Min, window.ClampWidth.Max)
		elseif ScalingState.XScaleType == ScalingEdgeEnum.Right then
			x_size = math.clamp(Mouse.X - window_pos.X.Offset, window.ClampWidth.Min, window.ClampWidth.Max)
		else
			x_size = window_size.X.Offset
		end

		if ScalingState.YScaleType == ScalingEdgeEnum.Top then
			y_size = math.clamp(DisplayFrame.Position.Y.Offset - Mouse.Y, window.ClampHeight.Min, window.ClampHeight.Max)
		elseif ScalingState.YScaleType == ScalingEdgeEnum.Bottom then
			y_size = math.clamp(Mouse.Y - window_pos.Y.Offset, window.ClampHeight.Min, window.ClampHeight.Max)
		else
			y_size = window_size.Y.Offset
		end
		DisplayFrame.Size = UDim2.new(0, x_size, 0, y_size)
	end
end

function Windows:__init(G)
	Style = G.Load("Style")
	TitleRightPad = Style.StdHeaderHeight

	local RunService = game:GetService("RunService")
	RunService.RenderStepped:Connect(update)
end

return Windows

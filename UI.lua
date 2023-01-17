--!strict

--[[
	--TODO: This got messy after I started moving functionality into `Roact::createElement` module
		(which used to only be a function).
		This file needs some cleanup/organizing but whatever


	Unlike most things in the Util folder, this file has the normal lifecycle and but it does so through a manual
	call to G.LightLoad from LazyModules since it's part of that system

	StdElements are available for use after the __ui pass, although they can be used earlier but the timing of their
	initialization is not guaranteed. They will become available in whichever order modules happen to be loaded.

	** See mod:__finalize for further docs.

	** See Menu.lua for some usage examples, including StdElements.

	** See GUI.lua for examples of how to register StdElements.
	
	Tweens:
			Tweens play when they are mounted, they are bindings.
			If they are unmounted, their motor still runs, but the sequence will not advance to the next step until mounted again.
			
			@param start default 0, should be a number
			@return a tween sequence for chain definitions
			I:Tween(start)
			
			--Motor chains, occur when the previous step is complete.
			:spring(target, frequency, dampingRatio)
			:linear(target, velocity)
			:instant(target)
			
			to tween non numbers it is recommended to append at the end of the chain with :map(I:ColorMap(c1, c2))
			
			-- other chainable functions
			@param count can be -1 for infinite
			:repeatAll(count) -- repeats the entire chain defined for count times.
			:repeatThis(count) -- repeats the last chained object for count times.
			:pause(t) -- adds a chain which pauses the tween sequence for t seconds before continuing.
			
			-- external use
			:wipe() -- clears the tween sequence
			:reset() -- resets the tween sequence completely.
			:pause() -- pauses the playing of the chain and and the motor and all.
			:resume() -- resumes playing of the chain.
			
			most likely you will do like this
				local tween = I:Tween():[initial chain played upon mount]
				
				TextColor = tween:map(I:ColorMap(c1, c2)),
				
				eg_playerClicked = function()
					tween:wipe():linear()
					or just
					tween:reset()
				end
]]

local mod = {
	Events = {
		Types = { },
		Modules = { }
	}
}

local UIs = mod.Events

local Globals
local LazyString
local AsyncList
local Roact
local Flipper
local Style
local Assets
local unwrap_or_warn
local unwrap_or_error
local safe_require

Instance.new("PathfindingLink")

local LocalizationService = game:GetService("LocalizationService")
local IsServer = game:GetService("RunService"):IsServer()

local ServerScriptService, ReplicatedStorage = game:GetService("ServerScriptService"), game.ReplicatedStorage

local PlayerScripts = if IsServer then false else game.Players.LocalPlayer.PlayerScripts
local CONTEXT = IsServer and "SERVER" or "CLIENT"

local TypeBindings = {
	UDim = UDim.new,
	UDim2 = UDim2.new,
	Vector2 = Vector2.new,
	Vector3 = Vector3.new,
	Color3 = Color3.new,
	Rect = Rect.new,
	--LocalizationTable = LocalizationService:
	Event = "Event",
	Enum = "Enum",
	bool = "primitive",
	int = "primitive",
	float = "primitive",
	string = "primitive",
	Content = "primitive",
	LocalizationTable = "reference",
	GuiObject = "reference",
	SelectionImageObject = "reference",
	Activated = "Event",
	MouseButton1Click = "Event",
	MouseButton1Down = "Event",
	MouseButton1Up = "Event",
	MouseButton2Click = "Event",
	MouseButton2Down = "Event",
	MouseButton2Up = "Event",
	MouseEnter = "Event",
	MouseLeave = "Event",
	FocusLost = "Event",
	Focused = "Event",
	ReturnPressedFromOnScreenKeyboard = "Event",
	DidLoop = "Event",
	Ended = "Event",
	Loaded = "Event",
	Paused = "Event",
	Played = "Event",
	PageEnter = "Event",
	PageLeave = "Event",
	Stopped = "Event",
	ColorSequence = ColorSequence.new,
	NumberSequence = NumberSequence.new,
--[[ 	Color = "ColorSequence",
	Enabled = "bool",
	Offset = "Vector2",
	Rotation = "float",
	Transparency = "NumberSequence",
	CornerRadius = "UDim",
	MaxTextSize = "int",
	MinTextSize = "int",
	MaxSize = "Vector2",
	MinSize = "Vector2",
	AspectRatio = "float",
	AspectType = "Enum",
	DominantAxis = "Enum",
	FillDirection = "Enum",
	HorizontalAlignment = "Enum",
	SortOrder = "Enum",
	VerticalAlignment = "Enum",
	CellPadding = "UDim2",
	CellSize = "UDim2",
	FillDirectionMaxCells = "int",
	StartCorner = "Enum",
	Padding = "UDim",
	Animated = "bool",
	Circular = "bool",
	EasingDirection = "Enum",
	EasingStyle = "Enum",
	TweenTime = "float",
	GamepadInputEnabled = "bool",
	ScrollWheelInputEnabled = "bool",
	TouchInputEnabled = "bool",
	FillEmptySpaceColumns = "bool",
	FillEmptySpaceRows = "bool",
	MajorAxis = "Enum",
	PaddingBottom = "UDim",
	PaddingLeft = "UDim",
	PaddingRight = "UDim",
	PaddingTop = "UDim",
	Scale = "float",
	ApplyStrokeMode = "Enum",
	LineJoinMode = "Enum",
	Thickness = "float", ]]
	[Enum.SelectionBehavior] = "Enum",
	[Enum.SelectionBehavior] = "Enum",
	[Enum.SelectionBehavior] = "Enum",
	[Enum.SelectionBehavior] = "Enum",
	[Enum.AutomaticSize] = "Enum",
	[Enum.BorderMode] = "Enum",
	[Enum.SizeConstraint] = "Enum",
	[Enum.FrameStyle] = "Enum",
	[Enum.ResamplerMode] = "Enum",
	[Enum.ScaleType] = "Enum",
	[Enum.TextTruncate] = "Enum",
	[Enum.TextXAlignment] = "Enum",
	[Enum.TextYAlignment] = "Enum",
	[Enum.ResamplerMode] = "Enum",
	[Enum.ScaleType] = "Enum",
	[Enum.TextTruncate] = "Enum",
	[Enum.TextXAlignment] = "Enum",
	[Enum.TextYAlignment] = "Enum",
	[Enum.AutomaticSize] = "Enum",
	[Enum.ElasticBehavior] = "Enum",
	[Enum.ScrollBarInset] = "Enum",
	[Enum.ScrollingDirection] = "Enum",
	[Enum.ScrollBarInset] = "Enum",
	[Enum.VerticalScrollBarPosition] = "Enum",
	[Enum.TextTruncate] = "Enum",
	[Enum.TextXAlignment] = "Enum",
	[Enum.TextYAlignment] = "Enum",
	NextSelectionDown = "reference",
	NextSelectionLeft = "reference",
	NextSelectionRight = "reference",
	NextSelectionUp = "reference",
}

local Classes = {
	GuiButton = {
		AutoButtonColor = "bool",
		Modal = "bool",
		Selected = "bool",
		Style = "Enum"
	},
	GuiBase2d = {
		Name = "string",
		AutoLocalize = "bool",
		RootLocalizationTable = "LocalizationTable",
		SelectionBehaviorDown = Enum.SelectionBehavior,
		SelectionBehaviorLeft = Enum.SelectionBehavior,
		SelectionBehaviorRight = Enum.SelectionBehavior,
		SelectionBehaviorUp = Enum.SelectionBehavior,
		SelectionGroup = "bool"
	},
	GuiObject = {
		SelectionImageObject = "GuiObject",
		ClipsDescendants = "bool",
		Draggable = "bool",
		Active = "bool",
		AnchorPoint = "Vector2",
		AutomaticSize = Enum.AutomaticSize,
		BackgroundColor3 = "Color3",
		BackgroundTransparency = "float",
		BorderColor3 = "Color3",
		BorderMode = Enum.BorderMode,
		BorderSizePixel = "int",
		LayoutOrder = "int",
		Position = "UDim2",
		Rotation = "float",
		Size = "UDim2",
		SizeConstraint = Enum.SizeConstraint,
		Transparency = "float",
		Visible = "bool",
		ZIndex = "int",
		NextSelectionDown = "GuiObject",
		NextSelectionLeft = "GuiObject",
		NextSelectionRight = "GuiObject",
		NextSelectionUp = "GuiObject",
		Selectable = "bool",
		SelectionOrder = "int",
		Activated = "Event",
		MouseButton1Click = "Event",
		MouseButton1Down = "Event",
		MouseEnter = "Event",
		MouseLeave = "Event",
		MouseButton1Up = "Event",
		MouseButton2Click = "Event",
		MouseButton2Down = "Event",
		MouseButton2Up = "Event",
	},
	CanvasGroup = {
		GroupColor3 = "Color3",
		GroupTransparency = "float"
	},
	Frame = {
		Style = Enum.FrameStyle
	},
	ImageButton = {
		HoverImage = "Content",
		Image = "Content",
		ImageColor3 = "Color3",
		ImageRectOffset = "Vector2",
		ImageRectSize = "Vector2",
		ImageTransparency = "float",
		PressedImage = "Content",
		ResampleMode = Enum.ResamplerMode,
		ScaleType = Enum.ScaleType,
		SliceCenter = "Rect",
		SliceScale = "float",
		TileSize = "UDim2"
	},
	TextButton = {
		Font = "Font",
		FontFace = "Font",
		LineHeight = "float",
		MaxVisibleGraphemes = "int",
		RichText = "bool",
		Text = "string",
		TextColor3 = "Color3",
		TextScaled = "bool",
		TextSize = "float",
		TextStrokeColor3 = "Color3",
		TextStrokeTransparency = "float",
		TextTransparency = "float",
		TextTruncate = Enum.TextTruncate,
		TextWrapped = "bool",
		TextXAlignment = Enum.TextXAlignment,
		TextYAlignment = Enum.TextYAlignment
	},
	ImageLabel = {
		Image = "Content",
		ImageColor3 = "Color3",
		ImageRectOffset = "Vector2",
		ImageRectSize = "Vector2",
		ImageTransparency = "float",
		ResampleMode = Enum.ResamplerMode,
		ScaleType = Enum.ScaleType,
		SliceCenter = "Rect",
		SliceScale = "float",
		TileSize = "UDim2"
	},
	TextLabel = {
		Font = "Font",
		FontFace = "Font",
		LineHeight = "float",
		MaxVisibleGraphemes = "int",
		RichText = "bool",
		Text = "string",
		TextColor3 = "Color3",
		TextScaled = "bool",
		TextSize = "float",
		TextStrokeColor3 = "Color3",
		TextStrokeTransparency = "float",
		TextTransparency = "float",
		TextTruncate = Enum.TextTruncate,
		TextWrapped = "bool",
		TextXAlignment = Enum.TextXAlignment,
		TextYAlignment = Enum.TextYAlignment
	},
	ScrollingFrame = {
		AutomaticCanvasSize = Enum.AutomaticSize,
		BottomImage = "Content",
		CanvasPosition = "Vector2",
		CanvasSize = "UDim2",
		ElasticBehavior = Enum.ElasticBehavior,
		HorizontalScrollBarInset = Enum.ScrollBarInset,
		MidImage = "Content",
		ScrollBarImageColor3 = "Color3",
		ScrollBarImageTransparency = "float",
		ScrollBarThickness = "int",
		ScrollingDirection = Enum.ScrollingDirection,
		ScrollingEnabled = "bool",
		TopImage = "Content",
		VerticalScrollBarInset = Enum.ScrollBarInset,
		VerticalScrollBarPosition = Enum.VerticalScrollBarPosition
	},
	TextBox = {
		ClearTextOnFocus = "bool",
		CursorPosition = "int",
		MultiLine = "bool",
		SelectionStart = "int",
		ShowNativeInput = "bool",
		TextEditable = "bool",
		Font = "Font",
		FontFace = "Font",
		LineHeight = "float",
		MaxVisibleGraphemes = "int",
		PlaceholderColor3 = "Color3",
		PlaceholderText = "string",
		RichText = "bool",
		Text = "string",
		TextColor3 = "Color3",
		TextScaled = "bool",
		TextSize = "float",
		TextStrokeColor3 = "Color3",
		TextStrokeTransparency = "float",
		TextTransparency = "float",
		TextTruncate = Enum.TextTruncate,
		TextWrapped = "bool",
		TextXAlignment = Enum.TextXAlignment,
		TextYAlignment = Enum.TextYAlignment,
		FocusLost = "Event",
		Focused = "Event",
		ReturnPressedFromOnScreenKeyboard = "Event"
	},
	VideoFrame = {
		Looped = "bool",
		Playing = "bool",
		TimePosition = "double",
		Video = "Content",
		Volume = "float",
		DidLoop = "Event",
		Ended = "Event",
		Loaded = "Event",
		Paused = "Event",
		Played = "Event"
	},
	ViewportFrame = {
		Ambient = "Color3",
		LightColor = "Color3",
		LightDirection = "Vector3",
		CurrentCamera = "Camera",
		ImageColor3 = "Color3",
		ImageTransparency = "float"
	},

	UIGradient = {
		Color = "ColorSequence",
		Enabled = "bool",
		Offset = "Vector2",
		Rotation = "float",
		Transparency = "NumberSequence"
	},
	UICorner = {
		CornerRadius = "UDim",
	},
	UITextSizeConstraint = {
		MaxTextSize = "int",
		MinTextSize = "int",
	},
	UISizeConstraint = {
		MaxSize = "Vector2",
		MinSize = "Vector2",
	},
	UIAspectRatioConstraint = {
		AspectRatio = "float",
		AspectType = "Enum",
		DominantAxis = "Enum",
	},
	UIGridStyleLayout = {
		FillDirection = "Enum",
		HorizontalAlignment = "Enum",
		SortOrder = "Enum",
		VerticalAlignment = "Enum",
	},
	UIGridLayout = {
		CellPadding = "UDim2",
		CellSize = "UDim2",
		FillDirectionMaxCells = "int",
		StartCorner = "Enum",
	},
	UIListLayout = {
		Padding = "UDim"
	},
	UIPageLayout = {
		Animated = "bool",
		Circular = "bool",
		EasingDirection = "Enum",
		EasingStyle = "Enum",
		Padding = "UDim",
		TweenTime = "float",
		GamepadInputEnabled = "bool",
		ScrollWheelInputEnabled = "bool",
		TouchInputEnabled = "bool",
		PageEnter = "Event",
		PageLeave = "Event",
		Stopped = "Event"
	},
	UITableLayout = {
		FillEmptySpaceColumns = "bool",
		FillEmptySpaceRows = "bool",
		Padding = "UDim2",
		MajorAxis = "Enum"
	},
	UIPadding = {
		PaddingBottom = "UDim",
		PaddingLeft = "UDim",
		PaddingRight = "UDim",
		PaddingTop = "UDim"
	},
	UIScale = {
		Scale = "float"
	},
	UIStroke = {
		ApplyStrokeMode = "Enum",
		Color = "Color3",
		LineJoinMode = "Enum",
		Thickness = "float",
		Transparency = "float",
		Enabled = "bool"
	},
}

local UIBuilder = {
	Type = "Builder",
	Context = CONTEXT,
	--TODO: Allow nested stateful elements to be made simultaneously
	BuildingStateful = { },
	BuildingElements = { },
	Current = { },
	FinishedSet = { },
	--Here we store things such as extended componenets, since these contian 
	Processors = { },
	Nesteds = { },

	--Wrapper functions for making extending components
	Stateful = function(self, name)
		local component = Roact.Component:extend(name)
		for i,v in self.BuildingStateful do
			component[i] = v
		end
		self.BuildingStateful = { }
		return component
	end,

	Init = function(self, func)
		--assert(self.BuildingStateful[Roact.Type] == Roact.Type.StatefulComponentInstance)
		self.BuildingStateful.init = func
		return self
	end,

	Render = function(self, func)
		--assert(self.BuildingStateful[Roact.Type] == Roact.Type.StatefulComponentInstance)
		self.BuildingStateful.render = func
		return self
	end,

	DidMount = function(self, func)
		--assert(self.BuildingStateful[Roact.Type] == Roact.Type.StatefulComponentInstance)
		self.BuildingStateful.didMount = func
		return self
	end,

	WillUnmount = function(self, func)
		--assert(self.BuildingStateful[Roact.Type] == Roact.Type.StatefulComponentInstance)
		self.BuildingStateful.willUnmount = func
		return self
	end,

	WillUpdate = function(self, func)
		--assert(self.BuildingStateful[Roact.Type] == Roact.Type.StatefulComponentInstance)
		self.BuildingStateful.willUpdate = func
		return self
	end,

	--TextToSize
}

local elements_set_list = UIBuilder.BuildingElements
local function alloc_prop_set()
	local new = { }
	table.insert(elements_set_list, new)
	UIBuilder.Current = new
end

local function dealloc_prop_set()
	if UIBuilder.Current == nil then
		error("UIBuilder: Current is nil")
	end
	UIBuilder.Current = elements_set_list[#elements_set_list - 1]
	UIBuilder.FinishedSet = table.remove(elements_set_list)

	return UIBuilder.FinishedSet
end

mod.A = alloc_prop_set
mod.D = dealloc_prop_set

--Some ham fisted logic to allow stuff to work
local next_alloc_call = true

local mt_EventBuilder = {
	__index = UIBuilder
}

function mod:RoundCorners(scale, pixels)
	self:Children(
		UIBuilder:UICorner()
			:CornerRadius(scale or 0, pixels or 4)
	)
	
	return self
end

function mod:Border(thick, color)
	self:Children(
		UIBuilder:UIStroke()
			:ApplyStrokeMode(Enum.ApplyStrokeMode.Border)
			:Color_Raw(color or Style.SecondaryColor2)
			:Thickness(thick or 2)
	)
	
	return self
end

function mod:Invisible()
	self:BackgroundTransparency(1)
	self:BorderSizePixel(0)
	return self
end

function mod:Line(fromPos: UDim2, toPos: UDim2, thick)
	local size, updSize = Roact.createBinding(UDim2.new(0,0,0,0))
	local rotation, updRotation = Roact.createBinding(0)
	local position, updPosition = Roact.createBinding(UDim2.new(0,0,0,0))
	
	local function updateBindings(rbx)
		local absoluteSize = rbx.AbsoluteSize
		
		local x1 = fromPos.X.Scale * absoluteSize.X + fromPos.X.Offset
		local y1 = fromPos.Y.Scale * absoluteSize.Y + fromPos.Y.Offset
		local x2 = toPos.X.Scale * absoluteSize.X + toPos.X.Offset
		local y2 = toPos.Y.Scale * absoluteSize.Y + toPos.Y.Offset
		local dx = x2 - x1
		local dy = y2 - y1
		
		local distance = math.sqrt(dx * dx + dy * dy)
		updSize(UDim2.new(0, distance, 0, thick))
		
		updPosition(UDim2.new(0, (x1 + x2)/2, 0, (y1 + y2)/2))
		
		updRotation(math.deg(math.atan2(y2 - y1, x2 - x1)))
	end
	
	local old = self.Current[Roact.Change.AbsoluteSize]
	self.Current[Roact.Change.AbsoluteSize] = function(rbx)
		if old then
			old(rbx)
		end
		updateBindings(rbx)
	end
	
	local oldp = self.Current[Roact.Change.Parent]
	self.Current[Roact.Change.Parent] = function(rbx)
		if oldp then
			oldp(rbx)
		end
		
		if rbx.Parent then
			updateBindings(rbx)
		end
	end
	
	self:AnchorPoint(0.5, 0.5)
	self:Size_Raw(size)
	self:Rotation(rotation)
	self:Position_Raw(position)
	
	return self
end

function mod:AspectRatioProp(ratio)
	-- Aspect Ratio is X/Y, so the larger the ratio, the larger Width.
	self:Children(
		UIBuilder:UIAspectRatioConstraint()
			:AspectRatio(ratio)
	)
	
	return self
end

function mod:MoveBy(xs, xo, ys, yo)
	local pos = self.Current.Position or UDim2.new()
	pos += UDim2.new(xs, xo, ys, yo)
	self:Position_Raw(pos)
	return self
end

function mod:Center()
	self:AnchorPoint(0.5, 0.5)
	self:Position(0.5, 0, 0.5, 0)
	return self
end

function mod:JustifyLeft(scaling, spacing)
	self:AnchorPoint(0, 0.5)

	local old_pos = self.Current.Position
	if old_pos then
		self:Position(scaling, spacing, old_pos.Y.Scale, old_pos.Y.Offset)
	else
		self:Position(scaling, spacing, 0.5, 0)
	end

	return self
end
function mod:JustifyRight(scaling, spacing)
	self:AnchorPoint(1, 0.5)

	local old_pos = self.Current.Position
	if old_pos then
		self:Position(1 - scaling, -spacing, old_pos.Y.Scale, old_pos.Y.Offset)
	else
		self:Position(1 - scaling, -spacing, 0.5, 0)
	end

	return self
end
function mod:JustifyTop(scaling, spacing)
	self:AnchorPoint(0.5, 0)

	local old_pos = self.Current.Position
	if old_pos then
		self:Position(old_pos.X.Scale, old_pos.X.Offset, scaling, spacing)
	else
		self:Position(0.5, 0, scaling, spacing)
	end

	return self
end
function mod:JustifyBottom(scaling, spacing)
	self:AnchorPoint(0.5, 1)

	local old_pos = self.Current.Position
	if old_pos then
		self:Position(old_pos.X.Scale, old_pos.X.Offset, 1 - scaling, -spacing)
	else
		self:Position(0.5, 0, 1 - scaling, -spacing)
	end

	return self
end

function mod:OutsideLeft(scaling, spacing)
	self:AnchorPoint(1, 0.5)

	local old_pos = self.Current.Position
	if old_pos then
		self:Position(-scaling, -spacing, old_pos.Y.Scale, old_pos.Y.Offset)
	else
		self:Position(-scaling, -spacing, 0.5, 0)
	end

	return self
end
function mod:OutsideRight(scaling, spacing)
	self:AnchorPoint(0, 0.5)

	local old_pos = self.Current.Position
	if old_pos then
		self:Position(1 + scaling, spacing, old_pos.Y.Scale, old_pos.Y.Offset)
	else
		self:Position(1 + scaling, spacing, 0.5, 0)
	end

	return self
end
function mod:OutsideTop(scaling, spacing)
	self:AnchorPoint(0.5, 1)

	local old_pos = self.Current.Position
	if old_pos then
		self:Position(old_pos.X.Scale, old_pos.X.Offset, -scaling, -spacing)
	else
		self:Position(0.5, 0, -scaling, -spacing)
	end

	return self
end
function mod:OutsideBottom(scaling, spacing)
	self:AnchorPoint(0.5, 0)

	local old_pos = self.Current.Position
	if old_pos then
		self:Position(old_pos.X.Scale, old_pos.X.Offset, 1 + scaling, spacing)
	else
		self:Position(0.5, 0, 1 + scaling, spacing)
	end

	return self
end

function mod:Inset(scaling, spacing)
	self:Size(1 - scaling, -spacing, 1 - scaling, -spacing)
	return self
end

local currentCamera = workspace.CurrentCamera

local function calcSize(size)
	local viewportSize = currentCamera.ViewportSize
	return math.max(11, math.ceil(size * viewportSize.X / 1920 * viewportSize.Y / 1080))
end

function mod:ScaledTextSize(size)
	local binding, updBinding = Roact.createBinding(calcSize(size))
	
	local old = self.Current[Roact.Change.AbsoluteSize]
	
	self.Current[Roact.Change.AbsoluteSize] = function(rbx)
		if old then
			old(rbx)
		end
		
		updBinding(calcSize(size))
	end
	
	return binding
end

--Sets up a named list in the props table, which gains the functionality of the UIBuilder
-- Essentially nesting custom props into the props list, by a specified name
-- Intended use is such as in the StdElements `TextButton` and `ImageButton` in GUI.lua
function UIBuilder:Props(name, ...)
--[[ 	local props = {
		-- Hacky but necessary to isolate the props from the metatable
		-- This means that StdElements which expect a custom props table must index `.Current` to access the props
		Current = UIBuilder.FinishedSet
	} ]]
	UIBuilder.Current[name] = UIBuilder.FinishedSet
	UIBuilder.FinishedSet = { }
	--setmetatable(props, mt_EventBuilder)
	return self
end

function UIBuilder:AppendProps(other_props: table)
	if not other_props then return self end

	for i,v in other_props do
		UIBuilder.Current[i] = v
	end
	return self
end

function UIBuilder:Attribute(name, value)
	UIBuilder.Current[Roact.Attribute[name]] = value
	return self
end

function UIBuilder:Prop(name, value)
	UIBuilder.Current[name] = value
	return self
end

function UIBuilder:Ref(value)
	UIBuilder.Current[Roact.Ref] = value
	return self
end

function UIBuilder:CreateRef()
	return Roact.createRef()
end

function UIBuilder:Tween(start)
	start = start or 0
	
	local binding, updBinding = Roact.createBinding(start)
	return binding:getTween()
end

function UIBuilder:NumberMap(n1, n2)
	return function(v)
		return n1 * (1 - v) + n2 * v
	end
end

function UIBuilder:LerpMap(c1, c2)
	return function(v)
		return c1:Lerp(c2, v)
	end
end


--[[ function UIBuilder:ColorSequenceMap(...)
	local args = {...}
	
	local colors = { }
	
	local i = 1
	while i < #args do
		local arg = args[i]
		if type(arg) == "number" then
			colors[#colors+1] = Color3.new(arg, args[i + 1], args[i + 2])
			i += 2
		else
			colors[#colors+1] = arg
		end
		i += 1
	end
	
	return function(v)
		return ColorSequence.new(colors[1]:Lerp(colors[3], v), colors[2]:Lerp(colors[4], v))
	end
end ]]

--[[ function UIBuilder:ForwardRef(func)
	return Roact.forwardRef(func)
end ]]

function UIBuilder:InsertChild(child)
	local _current = self.Current
	_current[Roact.Children] = _current[Roact.Children] or { }
	table.insert(_current, child)
	return self
end

function UIBuilder:Binding(default)
	return Roact.createBinding(default)
end

function UIBuilder:JoinBindings(bindings)
	return Roact.joinBindings(bindings)
end

function UIBuilder:Fragment(t: table)
	return Roact.createFragment(t)
end


function UIBuilder:Dynamic(func, ...)
--[[ 		for i,v in {...} do
		UIBuilder.Current[i] = v
	end ]]
	local element = Roact.createElement(func, UIBuilder.FinishedSet)
	UIBuilder.FinishedSet = { }
	return element
end

function UIBuilder:Bind(name, binding)
	assert(binding[Roact.Type] == Roact.Type.Binding)
	UIBuilder.Current[name] = binding
	return self
end

local StdElement = { }

local mt_StdElementUtil = { __index = StdElement}

local StandardElements = { }

function mod:NewStdElement(name, element_prototype)
	assert(StandardElements[name] == nil)

	StandardElements[name] = element_prototype
end

function mod:StdElement(name, _)
	assert(StandardElements[name] ~= nil)
	local element_prototype = StandardElements[name]

	local props = UIBuilder.FinishedSet
	UIBuilder.FinishedSet = { }

	--Elements not assigned to functions will do a deep clone
	-- functional elements will function like normal roact elements
	-- Mostly this was done because I went through all the effort of doing the deep clone thing
	-- before realizing there's missing functionality when it comes to elements with lots of nesting
	-- as far as how they acquire props.
	local element
	if typeof(element_prototype) == "function" then
		element = element_prototype(props)
	else
		element = element_prototype:Clone()
		element:Overrides(props)
	end

	return element
end

--[[ function mod:Classify(std_element: string, desc: string)
	assert(StandardElements[desc] ~= nil)
	self.Classifications[desc] = self.Classifications[desc] or { }
	self.Classifications[desc][std_element] = StandardElements[desc]
end ]]


--A small system which allows us to register external functions which modify the props of the element being built
function mod:RegisterStdModifier(name, func)
	Roact.elementModule[name] = func
	UIBuilder[name] = func
end

function mod:StdModifier(name, props)
	local processor = mod[name]
	assert(processor ~= nil)
	processor(self, self, props)
	return self
end

function mod:Builder( module_name: string )
	assert(module_name)
	assert(typeof(module_name) == "string")

	mod.CurrentModule = module_name
	setmetatable(mod, mt_EventBuilder)

	return mod
end

local PropFuncs = { }
local empty_table = { }

function mod:Children(...)
	local existing_children = UIBuilder.Current[Roact.Children]
	local new_children = { ... }

	if not existing_children then
		UIBuilder.Current[Roact.Children] = new_children
	else
		for i,v in new_children do
			table.insert(existing_children, v)
		end
		UIBuilder.Current[Roact.Children] = existing_children
	end
	return self
end

function mod:__finalize(G)
	for class, properties in Classes do
		for prop_name, type in properties do
			local ctor = TypeBindings[type]

			if typeof(ctor) == "function" then
				Roact.elementModule[prop_name] = function(_self, ...)
					local value = ctor(...)
					_self.props[prop_name] = value
					return _self
				end
				UIBuilder[prop_name] = function(_self, ...)
					local value = ctor(...)
					UIBuilder.Current[prop_name] = value
					return _self
				end

				--
				local raw_name = prop_name .. "_Raw"
				Roact.elementModule[raw_name] = function(_self, value)
					_self.props[prop_name] = value
					return _self
				end
				UIBuilder[raw_name] = function(_self, value)
					UIBuilder.Current[prop_name] = value
					return _self
				end

				--Deprecated, this was used when this module was a state maachine that compiled to roact
				UIBuilder["Get" .. prop_name] = function(_self, ...)
					return ctor(...)
				end
			elseif ctor == "Event" then
				local event_key = Roact.Event[prop_name]
				Roact.elementModule[prop_name] = function(_self, value)
					_self.props[event_key] = value
					return _self
				end
				UIBuilder[prop_name] = function(_self, value)
					UIBuilder.Current[event_key] = value
					return _self
				end
			else
				Roact.elementModule[prop_name] = function(_self, value)
					_self.props[prop_name] = value
					return _self
				end
				UIBuilder[prop_name] = function(_self, value)
					UIBuilder.Current[prop_name] = value
					return _self
				end
			end
		end

		--[[
			This is where most of the magic happens.
			This set of functions can be used in two ways:
			
		**Roact-based Usage**
			To return an element to be built on the roact side (which is possible because of
			the above functions inserted into the roact module)

			Such usage may look like this, and is called:
			I:Frame()
				:Size(1, 0, 1, -5)
				:Center()


		**Lazy-based Usage**
			OR it can be used to build an element's properties and then pass them to roact.
			Such behavior is mostly relevant for registering "standard elements" such as in the GUI elements library
				(GUI.lua)
			However, even those are unnecessarily using that functionality, under the assumption that simple elements
			 	are better built as elements (now thought of as tables) which we want to clone and override some props.
				(mod::StdElement for where this difference is implemented)

			Such usage may look like this (note the usage of `I` within the function call):
			I:Frame(
				I:Size(1, 0, 1, -5),
				:Center()
			)



			The difference, semantically, is that the first usage is a simple call to the function, whereas the second
			usage is a call to the function with the element's properties as arguments.

			HOWEVER!!! The second example is more fragile and more complicated because it uses this module as a state
				machine (stored in the mod::Curent table (TODO: Rename that)) and then passing that to
				Roact.createElement at the last second. The args themselves are NOT EVER used.
		]]

		UIBuilder[class] = function(_self, ...)
			local element = Roact.createElement(class, UIBuilder.FinishedSet)
			UIBuilder.FinishedSet = { }
			return element
		end
	end
end

function mod:__init(G)
	Globals = G

	--Allocate an empty prop set so that elements can be made without any props or host elements
	alloc_prop_set()

	safe_require = G.Load(game.ReplicatedFirst.Util.SafeRequire).require

	local err = G.Load(game.ReplicatedFirst.Util.Error)
	unwrap_or_warn = err.unwrap_or_warn
	unwrap_or_error = err.unwrap_or_error

	LazyString = G.Load(game.ReplicatedFirst.Util.LazyString)

	AsyncList = G.Load(game.ReplicatedFirst.Util.AsyncList)
	Roact = G.Load(game.ReplicatedFirst.Modules.Roact)
	Style = G.Load(game.ReplicatedFirst.Modules.GUI.Style)
	Assets = G.Load(game.ReplicatedFirst.Modules.Assets)
	Flipper = G.Load(game.ReplicatedFirst.Modules.Flipper)
end

--This function takes in a table of names of instance types and scans for ones which are GuiObjects
-- If necessary, the instance list can be updated from MaximumADHD client tracker
local function scan_instances()
	local instance_list = safe_require(script.Parent.instance_list)

	local function make_instance(name)
		return Instance.new(name)
	end

	local function check_instance(ins)
		return ins:IsA("GuiObject") or ins:IsA("UIComponent") or ins:IsA("UILayout")
	end

	warn("----------------------------------")
	for i,v in instance_list do
		local success, instance = pcall(make_instance, v)

		if not success then continue end

		local success, value = pcall(check_instance, instance)
		if not success then
			--warn(value)
			continue
		end
		if not value then continue end

		PropFuncs[v] = instance
		print(instance.Name)
	end
end

function mod:__run()
	
end

--[[
	Can't use this because of the upvalue problem with names of classes


	if typeof(ctor) == "function" then
	--We don't allocate new functions for each constructor, instead we reuse them
	if PropFuncsCache[ctor] ~= nil then
		UIBuilder[name] = PropFuncsCache[ctor]
	else
		local func = function(_self, ...)
			local value = ctor(...)
			UIBuilder.Current[name] = value
			return _self
		end
	
		PropFuncsCache[ctor] = func
		UIBuilder[name] = func
	end

	--Raw functions need to be manually used when the caller is passing in already-constructed data
	local raw_name = name.."_Raw"
	if PropFuncCaache_Raw[ctor] ~= nil then
		UIBuilder[raw_name] = PropFuncCaache_Raw[ctor]
	else
		local raw_func = function(_self, value)
			UIBuilder.Current[raw_name] = value
			return _self
		end
		PropFuncCaache_Raw[ctor] = raw_func
		UIBuilder[raw_name] = raw_func
	end
else
	UIBuilder[name] = function(_self, value)
		UIBuilder.Current[name] = value
		return _self
	end
end
]]

return mod
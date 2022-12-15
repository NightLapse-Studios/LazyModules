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
	GuiBase2d = {
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
	UIAspectRatioConstrait = {
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
	Current = { },
	--Here we store things such as extended componenets, since these contian 
	Building = { },
	Processors = { },
	Nesteds = { },

	--Wrapper functions for making extending components
	Stateful = function(self, name)
		local component = Roact.Component:extend(name)
		for i,v in self.Building do
			component[i] = v
		end
		self.Building = { }
		return component
	end,

	Init = function(self, func)
		--assert(self.Building[Roact.Type] == Roact.Type.StatefulComponentInstance)
		self.Building.init = func
		return self
	end,

	Render = function(self, func)
		--assert(self.Building[Roact.Type] == Roact.Type.StatefulComponentInstance)
		self.Building.render = func
		return self
	end,

	DidMount = function(self, func)
		--assert(self.Building[Roact.Type] == Roact.Type.StatefulComponentInstance)
		self.Building.didMount = func
		return self
	end,

	WillUnmount = function(self, func)
		--assert(self.Building[Roact.Type] == Roact.Type.StatefulComponentInstance)
		self.Building.willUnmount = func
		return self
	end,

	WillUpdate = function(self, func)
		--assert(self.Building[Roact.Type] == Roact.Type.StatefulComponentInstance)
		self.Building.willUpdate = func
		return self
	end,

	--TextToSize

	Center = function(self)
		self:AnchorPoint(0.5, 0.5)
		self:Position(0.5, 0, 0.5, 0)
		return self
	end,

	MoveBy = function(self, xs, xo, ys, yo)
		local pos = self.Current.Position or UDim2.new()
		pos += UDim2.new(xs, xo, ys, yo)
		self:Position_Raw(pos)
		return self
	end,
}

local mt_EventBuilder = { __index = UIBuilder }

--Sets up a named list in the props table, which gains the functionality of the UIBuilder
-- Essentially nesting custom props into the props list, by a specified name
-- Intended use is such as in the StdElements `TextButton` and `ImageButton` in GUI.lua
function UIBuilder:Props(name, ...)
	local props = {
		-- Hacky but necessary
		-- This means that StdElements which expect a custom props table must index `.Current` to access the props
		Current = { }
	}
	self.Current[name] = props
	setmetatable(props, mt_EventBuilder)
	return props
end

function UIBuilder:AppendProps(other_props: table)
	for i,v in other_props do
		self.Current[i] = v
	end
	return self
end

function UIBuilder:Attribute(name, value)
	self.Current[Roact.Attribute[name]] = value
	return self
end

function UIBuilder:Prop(name, value)
	self.Current[name] = value
	return self
end

function UIBuilder:Ref(value)
	self.Current[Roact.Ref] = value
	return self
end

function UIBuilder:Binding(default)
	return Roact.createBinding(default)
end

function UIBuilder:JoinBindings(bindings)
	return Roact.joinBindings(bindings)
end


function UIBuilder:Dynamic(func, ...)
--[[ 		for i,v in {...} do
		self.Current[i] = v
	end ]]
	local element = Roact.createElement(func, self.Current)
	self.Current = { }
	return element
end

function UIBuilder:Bind(name, binding)
	assert(binding[Roact.Type] == Roact.Type.Binding)
	self.Current[name] = binding
	return self
end

function mod.Static(self: Builder, ui_type, identifier, tree)
	unwrap_or_error(
		UIs.Types:inspect(ui_type, identifier) == nil,
		LazyString.new("Re-declared Event identifier `", ui_type, "`\nFirst declared in `", UIs.Types[ui_type], "`")
	)

	tree = Roact.createFragment(tree)

	unwrap_or_error(
		UIs.Modules:inspect(self.CurrentModule, identifier) == nil,
		"Duplicate event `" .. ui_type .. "` in `" .. self.CurrentModule .. "`"
	)

	UIs.Types:provide(tree, ui_type, identifier)
	UIs.Modules:provide(tree, self.CurrentModule, ui_type, identifier)

	return tree
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

	--We need to clear the state before we create the new element
	local props = self.Current
	self.Current = { }

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


--A small system which allows us to register external functions which modify the props of the element being built
function mod:RegisterStdModifier(name, func)
	Roact.elementModule[name] = func
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
					_self.Current[prop_name] = value
					return _self
				end

				--
				local raw_name = prop_name .. "_Raw"
				Roact.elementModule[raw_name] = function(_self, value)
					_self.props[prop_name] = value
					return _self
				end
				UIBuilder[raw_name] = function(_self, value)
					_self.Current[prop_name] = value
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
					_self.Current[event_key] = value
					return _self
				end
			else
				Roact.elementModule[prop_name] = function(_self, value)
					_self.props[prop_name] = value
					return _self
				end
				UIBuilder[prop_name] = function(_self, value)
					_self.Current[prop_name] = value
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
			local element = Roact.createElement(class, self.Current)
			_self.Current = { }
			return element
		end
	end
end

function mod:__init(G)
	Globals = G

	safe_require = G.Load(game.ReplicatedFirst.Util.SafeRequire).require

	local err = G.Load(game.ReplicatedFirst.Util.Error)
	unwrap_or_warn = err.unwrap_or_warn
	unwrap_or_error = err.unwrap_or_error

	LazyString = G.Load(game.ReplicatedFirst.Util.LazyString)

	AsyncList = G.Load(game.ReplicatedFirst.Util.AsyncList)
	Roact = G.Load(game.ReplicatedFirst.Modules.Roact)
	Style = G.Load(game.ReplicatedFirst.Modules.GUI.Style)
	Assets = G.Load(game.ReplicatedFirst.Modules.Assets)

	UIs.Types = AsyncList.new(2)
	UIs.Modules = AsyncList.new(3)
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

--[[
	Can't use this because of the upvalue problem with names of classes


	if typeof(ctor) == "function" then
	--We don't allocate new functions for each constructor, instead we reuse them
	if PropFuncsCache[ctor] ~= nil then
		UIBuilder[name] = PropFuncsCache[ctor]
	else
		local func = function(_self, ...)
			local value = ctor(...)
			_self.Current[name] = value
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
			_self.Current[raw_name] = value
			return _self
		end
		PropFuncCaache_Raw[ctor] = raw_func
		UIBuilder[raw_name] = raw_func
	end
else
	UIBuilder[name] = function(_self, value)
		_self.Current[name] = value
		return _self
	end
end
]]

return mod
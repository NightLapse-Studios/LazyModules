--!strict

--[[
	Unlike most things in the Util folder, this file has the normal lifecycle and but it does so through a manual
	call to G.LightLoad from LazyModules since it's part of that system
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

local IsServer = game:GetService("RunService"):IsServer()

local ServerScriptService, ReplicatedStorage = game:GetService("ServerScriptService"), game.ReplicatedStorage

local PlayerScripts = if IsServer then false else game.Players.LocalPlayer.PlayerScripts
local CONTEXT = IsServer and "SERVER" or "CLIENT"

local TypeBindings = {
	bool = "primitive",
	int = "primitive",
	float = "primitive",
	string = "primitive",
	LocalizationTable = "reference",
	GuiObject = "reference",
	UDim = UDim.new,
	UDim2 = UDim2.new,
	Vector2 = Vector2.new,
	Vector3 = Vector3.new,
	Color3 = Color3.new,
	Rect = Rect.new,
	[Enum.SelectionBehavior] = "enum",
	[Enum.SelectionBehavior] = "enum",
	[Enum.SelectionBehavior] = "enum",
	[Enum.SelectionBehavior] = "enum",
	[Enum.AutomaticSize] = "enum",
	[Enum.BorderMode] = "enum",
	[Enum.SizeConstraint] = "enum",
	[Enum.FrameStyle] = "enum",
	[Enum.ResamplerMode] = "enum",
	[Enum.ScaleType] = "enum",
	[Enum.TextTruncate] = "enum",
	[Enum.TextXAlignment] = "enum",
	[Enum.TextYAlignment] = "enum",
	[Enum.ResamplerMode] = "enum",
	[Enum.ScaleType] = "enum",
	[Enum.TextTruncate] = "enum",
	[Enum.TextXAlignment] = "enum",
	[Enum.TextYAlignment] = "enum",
	[Enum.AutomaticSize] = "enum",
	[Enum.ElasticBehavior] = "enum",
	[Enum.ScrollBarInset] = "enum",
	[Enum.ScrollingDirection] = "enum",
	[Enum.ScrollBarInset] = "enum",
	[Enum.VerticalScrollBarPosition] = "enum",
	[Enum.TextTruncate] = "enum",
	[Enum.TextXAlignment] = "enum",
	[Enum.TextYAlignment] = "enum",
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
		SelectionOrder = "int"
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
		TextYAlignment = Enum.TextYAlignment
	},
	VideoFrame = {
		Looped = "bool",
		Playing = "bool",
		TimePosition = "double",
		Video = "Content",
		Volume = "float"
	},
	ViewportFrame = {
		Ambient = "Color3",
		LightColor = "Color3",
		LightDirection = "Vector3",
		CurrentCamera = "Camera",
		ImageColor3 = "Color3",
		ImageTransparency = "float"
	},
}

local StatefulBuilder = {

}

local UIBuilder = {
	Type = "Builder",
	Context = CONTEXT,
	Current = { },
	--Here we store things such as extended componenets, since these contian 
	Building = { },

	--Wrapper functions for making extending components
	Stateful = function(self, name)
		self.Building = Roact.Component:extend(name)
		return self
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

	Mount = function(self, parent)
		--assert(self.Building[Roact.Type] == Roact.Type.StatefulComponentInstance)
		Roact.mount(Roact.createElement(self.Building), parent)
		self.Building = { }
		return self
	end,



	Center = function(self)
		self:AnchorPoint(0.5, 0.5)
		self:Position(0.5, 0, 0.5, 0)
		return self
	end,

	MoveBy = function(self, xs, xo, ys, yo)
		local pos = self.Current.Position or UDim2.new()
		pos += UDim2.new(xs, xo, ys, yo)
		self:PositionRaw(pos)
		return self
	end,



	Dynamic = function(self, func)
		return Roact.createElement(func)
	end,

	Append = function(self, element, ...)
		assert(element[Roact.Type] == Roact.Type.Element)

		local elements = {...}
		element[Roact.Children] = elements
	end,

	Binding = function(self, default)
		return Roact.createBinding(default)
	end,

	JoinBindings = function(self, bindings)
		return Roact.joinBindings(bindings)
	end,

	Bind = function(self, name, binding)
		assert(binding[Roact.Type] == Roact.Type.Binding)
		self.Current[name] = binding
	end
}

local mt_EventBuilder = { __index = UIBuilder }

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

function mod:Builder( module_name: string )
	assert(module_name)
	assert(typeof(module_name) == "string")

	mod.CurrentModule = module_name
	setmetatable(mod, mt_EventBuilder)

	return mod
end

local UITypes = { }

function mod:__finalize(G)
	for class, properties in Classes do
		for name, type in properties do
			local ctor = TypeBindings[type]

			if typeof(ctor) == "function" then
				UIBuilder[name] = function(_self, ...)
					local value = ctor(...)
					_self.Current[name] = value
					return _self
				end
				UIBuilder[name .. "Raw"] = function(_self, value)
					_self.Current[name] = value
					return _self
				end
			else
				UIBuilder[name] = function(_self, value)
					_self.Current[name] = value
					return _self
				end
			end
		end

		UIBuilder[class] = function(_self)
			local element = Roact.createElement(class, _self.Current)
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
		return ins:IsA("GuiObject")
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

		UITypes[v] = instance
		print(instance.Name)
	end
end

return mod
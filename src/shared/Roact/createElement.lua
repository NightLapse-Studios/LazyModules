local Children = require(script.Parent.PropMarkers.Children)
local ElementKind = require(script.Parent.ElementKind)
local Logging = require(script.Parent.Logging)
local Type = require(script.Parent.Type)
local Attribute = require(script.Parent.PropMarkers.Attribute)
local Ref = require(script.Parent.PropMarkers.Ref)

local config = require(script.Parent.GlobalConfig).get()

local multipleChildrenMessage = [[
The prop `Roact.Children` was defined but was overriden by the third parameter to createElement!
This can happen when a component passes props through to a child element but also uses the `children` argument:

	Roact.createElement("Frame", passedProps, {
		child = ...
	})

Instead, consider using a utility function to merge tables of children together:

	local children = mergeTables(passedProps[Roact.Children], {
		child = ...
	})

	local fullProps = mergeTables(passedProps, {
		[Roact.Children] = children
	})

	Roact.createElement("Frame", fullProps)]]

local mod = { }

local mt_ElementUtils = { __index = mod }

local Game
local UI

local function __clone(self)
	local t = { }
	for i,v in self do
		if typeof(v) == "table" and not (v[Type] == Type.Binding) then
 			t[i] = __clone(v)
		else
			t[i] = v
		end
	end

	return t
end

function mod:Center()
	self:AnchorPoint(0.5, 0.5)
	self:Position(0.5, 0, 0.5, 0)
	return self
end

function mod:Ref(ref)
	self.props[Ref] = ref
	return self
end

function mod:JustifyLeft(scaling, spacing)
	self:AnchorPoint(0, 0.5)

	local old_pos = self.props.Position
	if old_pos then
		self:Position(scaling, spacing, old_pos.Y.Scale, old_pos.Y.Offset)
	else
		self:Position(scaling, spacing, 0.5, 0)
	end

	return self
end
function mod:JustifyRight(scaling, spacing)
	self:AnchorPoint(1, 0.5)

	local old_pos = self.props.Position
	if old_pos then
		self:Position(1 - scaling, -spacing, old_pos.Y.Scale, old_pos.Y.Offset)
	else
		self:Position(1 - scaling, -spacing, 0.5, 0)
	end

	return self
end
function mod:JustifyTop(scaling, spacing)
	self:AnchorPoint(0.5, 0)

	local old_pos = self.props.Position
	if old_pos then
		self:Position(old_pos.X.Scale, old_pos.X.Offset, scaling, spacing)
	else
		self:Position(0.5, 0, scaling, spacing)
	end

	return self
end
function mod:JustifyBottom(scaling, spacing)
	self:AnchorPoint(0.5, 1)

	local old_pos = self.props.Position
	if old_pos then
		self:Position(old_pos.X.Scale, old_pos.X.Offset, 1 - scaling, -spacing)
	else
		self:Position(0.5, 0, 1 - scaling, -spacing)
	end

	return self
end

function mod:Inset(scaling, spacing)
	self:Size(1 - scaling, -spacing, 1 - scaling, -spacing)
	return self
end

function mod:OutsideLeft(scaling, spacing)
	self:AnchorPoint(1, 0.5)

	local old_pos = self.props.Position
	if old_pos then
		self:Position(-scaling, -spacing, old_pos.Y.Scale, old_pos.Y.Offset)
	else
		self:Position(-scaling, -spacing, 0.5, 0)
	end

	return self
end
function mod:OutsideRight(scaling, spacing)
	self:AnchorPoint(0, 0.5)

	local old_pos = self.props.Position
	if old_pos then
		self:Position(1 + scaling, spacing, old_pos.Y.Scale, old_pos.Y.Offset)
	else
		self:Position(1 + scaling, spacing, 0.5, 0)
	end

	return self
end
function mod:OutsideTop(scaling, spacing)
	self:AnchorPoint(0.5, 1)

	local old_pos = self.props.Position
	if old_pos then
		self:Position(old_pos.X.Scale, old_pos.X.Offset, -scaling, -spacing)
	else
		self:Position(0.5, 0, -scaling, -spacing)
	end

	return self
end
function mod:OutsideBottom(scaling, spacing)
	self:AnchorPoint(0.5, 0)

	local old_pos = self.props.Position
	if old_pos then
		self:Position(old_pos.X.Scale, old_pos.X.Offset, 1 + scaling, spacing)
	else
		self:Position(0.5, 0, 1 + scaling, spacing)
	end

	return self
end

function mod:MoveBy(xs, xo, ys, yo)
	local pos = self.props.Position or UDim2.new()
	pos += UDim2.new(xs, xo, ys, yo)
	self:Position_Raw(pos)
	return self
end

function mod:AppendProps(other_props: table)
	if not other_props then return self end

	for i,v in other_props do
		self.props[i] = v
	end
	return self
end

function mod:Prop(name, value)
	self.props[name] = value
	return self
end

function mod:Children(...)
	local existing_children = self.props[Children]
	local new_children = { ... }

	if not existing_children then
		self.props[Children] = new_children
	else
		for i,v in new_children do
			table.insert(existing_children, v)
		end
		self.props[Children] = existing_children
	end
	return self
end

function mod:InsertChild(child)
	local _props = self.props
	_props[Children] = _props[Children] or { }
	table.insert(_props[Children], child)
	return self
end

function mod:Attribute(name, value)
	self.props[Attribute[name]] = value
	return self
end

function mod:StdModifier(name, props)
	local processor = mod[name]
	assert(processor ~= nil)
	processor(UI, self, props)
	return self
end

--Direct mutation to props is sometimes done by other functions, this is not a restricted API entry point
function mod:Override(prop, value)
	self.props[prop] = value
	return self
end

function mod:Overrides(props)
	for prop, value in props do
		self.props[prop] = value
	end
	return self
end

function mod:Clone()
	local new = setmetatable(__clone(self), mt_ElementUtils)
	return new
end

function mod:__init(G)
	Game = G
	UI = G.Load("UI")
end




--[[
	Creates a new element representing the given component.

	Elements are lightweight representations of what a component instance should
	look like.

	Children is a shorthand for specifying `Roact.Children` as a key inside
	props. If specified, the passed `props` table is mutated!
]]
function mod.createElement(component, props, children)
	assert(component ~= nil, "`component` is required")

	if config.typeChecks then
		assert(typeof(props) == "table" or props == nil, "`props` must be a table or nil")
		assert(typeof(children) == "table" or children == nil, "`children` must be a table or nil")
	end

	if props == nil then
		props = {}
	end

	if children ~= nil then
		if props[Children] ~= nil then
			Logging.warnOnce(multipleChildrenMessage)
		end

		props[Children] = children
	end

	local elementKind = ElementKind.fromComponent(component)

	local element = {
		[Type] = Type.Element,
		[ElementKind] = elementKind,
		component = component,
		props = props,
	}

	if config.elementTracing then
		-- We trim out the leading newline since there's no way to specify the
		-- trace level without also specifying a message.
		element.source = debug.traceback("", 2):sub(2)
	end

	setmetatable(element, mt_ElementUtils)

	return element
end

return mod
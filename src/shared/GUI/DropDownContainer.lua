
--[[
	Big gotcha for this module is that since a parent frame can't know the size of its children, it's impossible for
		the "menu" to be the size of itself plus its body. Roact compounds this issue because you can't refer to the children of a frame
		until after the elements have been turned into real Instances, which is after the entire lifecycle of a roact component.

	So, unfortunately, to stack lists of drop downs, you have to carefully maneuver the parts of a drop-down element

	To understand exactly what that means, here is the cannonical way to stack two drop-down menus:
	```
		local DropDownContainer = {
			Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
		}

		DbgMenu.MobSpawnerDropDown:renderToTable(DropDownContainer, 1, 2)
		DbgMenu.InteractablesDropDown:renderToTable(DropDownContainer, 3, 4)
		DropDownContainer = Roact.createFragment(DropDownContainer)

		local fin = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			ClipsDescendants = false
		},{
			DropDownContainer
		})
	```

	There is a more bare-bones render function:
	```
		--The container			and then body
		DropDownContainer[1], DropDownContainer[2] = DbgMenu.MobSpawnerDropDown:render()
	```

	The benefit of this is that it means drop-downs are very flexible and can actually be tied to any element located anywhere
	The drawback is that there can be a lot of boilerplate and complexity

	@Important
		for consistency, all render functions called by SetBody are expected to return a LayoutOrder binding update func
		even if LayoutOrder is not going to impact the layout
]]

local Style
local Roact = _G.Game.PreLoad(game.ReplicatedFirst.Modules.Roact)
local Assets = _G.Game.PreLoad(game.ReplicatedFirst.Modules.Assets)
local GUI = _G.Game.PreLoad(game.ReplicatedFirst.Modules.GUI)

local ListModule = { }

local function ToggleList( self, on )
	if on ~= nil then
		self.IsOpen = on
	else
		self.IsOpen = not self.IsOpen
	end

	self._onToggle( self.IsOpen )
end

local Padding = 6

local function RenderList( self )
	local body = false
	local drop_down_arrow_rotation = self._defaultRot

	if self.IsOpen == true then
		body = self.Body

		drop_down_arrow_rotation = self._enabledRot
	end

	local conainter = Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, Style.DropDownHeight_thin),
		--AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Style.SecondaryColor1,
		BorderSizePixel = 1,
		BorderColor3 = Style.WindowBorderColor,
		ClipsDescendants = false,
		LayoutOrder = self._layoutOrdeBinding_button
	}, {
		Roact.createElement(GUI.StdImageButton, {
			Size = UDim2.new(0, Style.DropDownHeight_thin - Padding, 0, Style.DropDownHeight_thin - Padding),
			Position = UDim2.new(0, Padding / 2, 0.5, 0),
			AnchorPoint = Vector2.new(0.0, 0.5),
			BackgroundTransparency = 1.0,
			BorderSizePixel = 0,
			Rotation = drop_down_arrow_rotation,
			Image = Assets.Images.DropdownArrow,
			[Roact.Event.MouseButton1Click] = function()
				ToggleList(self)
			end
		}),
		Roact.createElement(GUI.StdTextButton, {
			Size = UDim2.new(1, -Style.DropDownHeight_thin, 0, Style.DropDownHeight_thin),
			Position = UDim2.new(0, Style.DropDownHeight_thin, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			
			BackgroundTransparency = 1.0,
			BorderSizePixel = 0,
			TextColor3 = Style.ActiveTextColor,
			TextSize = Style.StdHeaderTextSize,
			Font = Style.LabelFont,
			LineHeight = 1.1,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Text = self.Title,
			[Roact.Event.MouseButton1Click] = function()
				ToggleList(self)
			end
		}),
		Roact.createElement("UICorner", {
			CornerRadius = UDim.new(0.3, 0)
		}),
		Roact.createElement("UIStroke", {
			Color = Style.WindowBorderColor,
			Thickness = 1,
		}),
	})

	return conainter, body
end

local function RenderList_Append( list, output_table, layout_order_button: number, layout_order_body: number )
	local drop_down, body = list:render()

	list._update_layoutOrderBinding_button(layout_order_button or 0)
	list._update_layoutOrderBinding_body(layout_order_body or 0)

	table.insert(output_table, drop_down)
	table.insert(output_table, body)
end

local function SetBody( self, render_func, props )
	local roact_tree, layout_order_ref = render_func(props)

	if not layout_order_ref then
		error("DropDownContainer's Body render function must return a RoactTree AND a RoactBinding update function for a LayoutOrder prop")
	end

	self._update_layoutOrderBinding_body = layout_order_ref
	self.Body = roact_tree
end

function ListModule.newList( title: string, disabled_arrow_rotation: number, enabled_arrow_rotation: number, onToggle: ( boolean ) -> nil)

	local button_binding, update_button_binding = Roact.createBinding(0)
	
	local list = {
		Title = title,
		IsOpen = false,

		_onToggle = onToggle,
		_defaultRot = disabled_arrow_rotation or 0.0,
		_enabledRot = enabled_arrow_rotation or 90.0,

		_layoutOrdeBinding_button = button_binding,
		_update_layoutOrderBinding_button = update_button_binding,
		_update_layoutOrderBinding_body = -1,

		Body = false,
		RoactTree = false,

		render = RenderList,
		renderToTable = RenderList_Append,
		ToggleList = ToggleList,
		SetBody = SetBody
	}

	return list
end

function ListModule:__init(G)
	Style = G.Load("Style")
end

return ListModule
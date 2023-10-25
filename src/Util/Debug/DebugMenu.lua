local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local mod = { }

local AL
local Slider = _G.Game.PreLoad(game.ReplicatedFirst.Modules.GUI.Slider)
local Roact = _G.Game.PreLoad(game.ReplicatedFirst.Modules.Roact)
local Style

local DebugMenuValueChangedEvent

local serverEntries = {}

local component

local override_bindings = require(game.ReplicatedFirst.Util.AssociativeList).new()
local entries = { }

local override_layout_order = 1

local I,P,D

function mod.GetOverrideBinding(name)
	return if entries[name] then entries[name].binding else nil
end

local function new_entry(name, menu_name, val)
	local val, updVal = Roact.createBinding(val)
	override_bindings:add(val, updVal)

	local t = {
		Type = "Slider",
		binding = val,
		element = false,
		layout_order = override_layout_order,
		menu = menu_name
	}

	entries[menu_name] = entries[menu_name] or { }
	entries[menu_name][name] = t


	override_layout_order += 1

	if component then
		component:setState({})
	end

	return t
end

function mod.RegisterOverrideSlider(name, val, slider_min: number, slider_max: number, step: number, opt_menu_name): Binding
	opt_menu_name = opt_menu_name or "Override Sliders"
	if entries[opt_menu_name] and entries[opt_menu_name][name] then
		return entries[opt_menu_name][name].binding
	end

	local override = new_entry(name, opt_menu_name, val)
	local slider = Roact.createElement(Slider, {
		Min = slider_min,
		Max = slider_max,
		Init = override.binding:getValue(),
		Increment = step,
		Callback = function(v)
			local updFunc = override_bindings:get(override.binding)
			if not updFunc then
				warn("Something is wrong with the override binding `" .. name .. "`")
				return
			end

			updFunc(v)
		end,
		
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.6, 0, 1, 0)
	})

	override.element = slider

	return override.binding
end

function mod.RegisterButton(name, callback, opt_menu_name)
	opt_menu_name = opt_menu_name or "Misc"
	if entries[opt_menu_name] and entries[opt_menu_name][name] then
		error("Button already registered: " .. name)
		return
	end
	
	if RunService:IsServer() then
		serverEntries[name] = callback
		
		return
	end
	
	local override = new_entry(name, opt_menu_name, 0)
	local button = I:StdElement("ImageButton", P()
		:Prop("Activated", function(rbx)
			DebugMenuValueChangedEvent:Transmit(name)
			callback(nil, Players.LocalPlayer)
		end)
		
		:Prop("UsePrimaryColor", true)
		
		:AnchorPoint(1, 0)
		:Position(1, 0, 0, 0)
		:Size(0.4, 0, 1, 0)
	)

	override.element = button
end

function mod.RegisterToggle(name, val): Binding
	local menu_name = "Togglers"
	if entries[menu_name] and entries[menu_name][name] then
		return entries[menu_name][name].binding
	end

	local override = new_entry(name, "Togglers", val)
	local button = I:StdElement("ImageButton", P()
		:Prop("Activated", function(rbx)
			local updFunc = override_bindings:get(override.binding)
			updFunc(not override.binding:getValue())
		end)
		
		:Prop("ID", true)
		:Prop("Focused", override.binding)
		
		:Prop("UsePrimaryColor", true)
		
		:AnchorPoint(1, 0)
		:Position(1, 0, 0, 0)
		:Size(1, 0, 1, 0)
	)

	override.element = button
	
	return override.binding
end

local ColorPicker

if RunService:IsClient() then
	ColorPicker = _G.Game.PreLoad(game.ReplicatedFirst.Modules.GUI.ColorPicker)
end

-- TODO: The binding returned by this is useless and idk why
function mod.RegisterOverrideColor3(name, color: Color3, callback): Binding
	local menu_name = "Override Colors"
	if entries[menu_name] and entries[menu_name][name] then
		return entries[menu_name][name].binding
	end

	local override = new_entry(name, menu_name, color)
		
	local colorpicker = Roact.createElement(ColorPicker, {
		Init = color,
		Callback = callback,
		
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.6, 0, 1, 0)
	})

	override.element = colorpicker

	return override.binding
end

function mod:__init(G)
	if RunService:IsClient() then
		Slider = G.PreLoad(game.ReplicatedFirst.Modules.GUI.Slider)
		Roact = G.Load(game.ReplicatedFirst.Modules.Roact)
		Style = G.Load("Style")
	end
end

local function handleDebugMenuValueChangedEvent(plr, name, value)
	if serverEntries[name] then
		serverEntries[name](value, plr)
	end
end

function mod:__build_signals(G, B)
	if not RunService:IsStudio() then
		return
	end
	
	DebugMenuValueChangedEvent = B:NewTransmitter("DebugMenuValueChangedEvent")
		:ServerConnection(handleDebugMenuValueChangedEvent)
end

function mod:__ui(G, i, p)
	if not RunService:IsStudio() then
		return
	end

	I,P = i,p

	local function render_DebugMenu(self)
		if self.state.visible ~= true then
			return false
		end

		local sub_menus = { }
		local sub_menu_fragments = { }

		for menu_name, menu_entries in entries do
			local fragment_list = { }
			sub_menu_fragments[menu_name] = fragment_list

			for label, binding_data in menu_entries do
				local element = binding_data.element

				local full_element =
					I:StdElement("ContainerFrame", P()
						:Size(1, 0, 0, 25)
						:LayoutOrder(binding_data.layout_order)
					):Children(
						I:TextLabel(P()
							:Size(1/3, 0, 1, 0)
							:JustifyLeft(0, 0)
							:Text(label)
							:TextColor3(0,0,0)
							:BackgroundTransparency(1)
						),
						element
					)

				table.insert(fragment_list, full_element)
			end
		end

		local function new_sub_menu(name, entry_frames)
			return I:StdElement("ContainerFrame", P()
				:AnchorPoint(0, 0)
				-- :Position(0, 5, 0, 5)
				-- :Size(0.3, 0, 0.5, 0)
				:BackgroundColor3_Raw(Color3.new(0.725490, 0.352941, 0.352941))
				:BackgroundTransparency(1)
				:Children(
					-- menu label
					I:TextLabel(P()
						:Text(name)
						:TextXAlignment(Enum.TextXAlignment.Left)
						:TextStrokeColor3(1, 1, 1)
						:TextStrokeTransparency(0.5)
						:Size(1, 0, 0, 25)
						:BackgroundColor3_Raw(Color3.new(0, 0.458823, 0.541176))
						:BackgroundTransparency(0.65)
					),
					-- body
					I:StdElement("ScrollingFrame", P()
						:Size(1, 0, 1, -25)
						:CanvasSize(1, 0, 1, -25)
						:Position(0, 0, 0, 25)
						:BackgroundTransparency(1)
						:Children(
							I:StdElement("VerticalLayout", P()
								:HorizontalAlignment(Enum.HorizontalAlignment.Center)
								:VerticalAlignment(Enum.VerticalAlignment.Top)
							),

							I:Fragment(entry_frames)
						)
					)
				)
			)
		end

		for i,v in sub_menu_fragments do
			table.insert(sub_menus, new_sub_menu(i, v))
		end

		return I:StdElement("ScrollingFrame", P()
			:CanvasSize(1, 0, 1, -68)
			-- Decent size to not occlude important UI
			:Size(1, 0, 3/4, -68)
			:Position(0, 0, 0, 34)
			:BackgroundTransparency(1)
			:Children(
				I:UIGridLayout(P()
					:StartCorner(Enum.StartCorner.TopLeft)
					:FillDirection(Enum.FillDirection.Horizontal)
					:CellSize(1/3, 0, 1/4, 0)
					:CellPadding(0, 5, 0, 5)
				),
				I:Fragment(sub_menus)
			)
		)
	end

	local DebugMenuUI = I:Stateful("DebugMenuUI", I
		:Init(function(self)
			component = self
		end)
		:Render(render_DebugMenu)
	)

	local visible = false
	local UserInput = G.Load("UserInput")

	local HasControl = false
	UserInput:Handler(Enum.KeyCode.LeftControl,
		function(input: InputObject)
			HasControl = true
		end,
		function()
			HasControl = false
		end)

	UserInput:Handler(Enum.KeyCode.B, function(input: InputObject)
		if not HasControl then
			return false
		end

		visible = not visible
		if visible then
			-- TODO: Mouse behavior system
			-- Views.OverrideMouseBehavior(Enum.MouseBehavior.Default)
		else
			-- Views.StopMouseBehaviorOverride()
		end

		component:setState({ visible = visible })

		return true
	end)

	Roact.mount(Roact.createElement(DebugMenuUI), game.Players.LocalPlayer.PlayerGui.BaseInterface_NoInset)
end

return mod
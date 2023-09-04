
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Roact = _G.Game.PreLoad(game.ReplicatedFirst.Modules.Roact)
local Style
local GUILib = _G.Game.PreLoad(game.ReplicatedFirst.Modules.GUI)
local TextBox = _G.Game.PreLoad(game.ReplicatedFirst.Modules.GUI.Textbox)
local Slider = _G.Game.PreLoad(game.ReplicatedFirst.Modules.GUI.Slider)
local Windows = _G.Game.PreLoad(game.ReplicatedFirst.Modules.GUI.Windows)
local Math = _G.Game.PreLoad(game.ReplicatedFirst.Modules.Math)
local Flipper = _G.Game.PreLoad(game.ReplicatedFirst.Modules.Flipper)
local Enums = _G.Game.Enums
local Assets = _G.Game.PreLoad(game.ReplicatedFirst.Modules.Assets)
local RelativeData = _G.Game.PreLoad(game.ReplicatedFirst.Util.RelativeData)

local ColorPicker = Roact.Component:extend("ColorPicker")
local PickerWindow = Roact.Component:extend("ColorPickerWindow")

local Mouse = game.Players.LocalPlayer:GetMouse()
local ActiveDragger = nil

function PickerWindow:init()
	self.Window = Windows.newWindow("Color Picker", 265, 473, function()
		self:setState({})
	end, function()
		self:setState({})
	end, true, nil, nil, nil, UDim2.new(0.5, 0, 0.5, 0), {}, nil, nil, nil, true)
	
	function PickerWindow.TurnOn(binding, updBinding)
		self.ColorBinding = binding
		self.updColorBinding = updBinding
		
		self.Window:ToggleWindow()
	end
	
	ColorPicker.TurnOn = PickerWindow.TurnOn
end

function PickerWindow:render()
	local window = self.Window
	
	if window.IsOpen == false then
		return false
	end
	
	window:SetBody(Roact.createElement("Frame", {
		BackgroundColor3 = Style.SecondaryColor1,
		BorderSizePixel = 0,
		Size = UDim2.new(1,0,1,0),
	}, {
		Roact.createElement(GUILib.Padding, {
			Pixels = 5,
		}),
		Roact.createElement(GUILib.VerticleLayout, {
			Padding = 5,
		}),
		
		Roact.createElement("Frame", {
			LayoutOrder = 1,
			Size = UDim2.new(1,0,0,0),
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y
		}, {
			Roact.createElement(GUILib.StdImageButton, {
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Image = Assets.Images.ColorWheel,
				Size = UDim2.new(0, 255, 0, 255),
				[Roact.Event.MouseButton1Down] = function(rbx)
					ActiveDragger = {rbx, self.updColorBinding, self.ColorBinding}
				end,
			}, {
				Roact.createElement("ImageLabel", {
					Image = Assets.Images.CircleRing,
					Size = UDim2.new(0, 20, 0, 20),
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					ImageColor3 = Color3.new(),
					Position = self.ColorBinding:map(function(color)
						local h,s,v = GUILib.ColorToHSV(color)
						local x,y = Math.XYOnCircle(0,0, s/2, math.pi/2 - Math.Map(h, 0, 255, 0, math.pi * 2))
						
						return UDim2.new(0.5, x, 0.5, -y)
					end)
				})
			}),
		}),
		
		Roact.createElement("Frame", {
			Size = UDim2.new(1, -10, 0, 2),
			BackgroundColor3 = Style.SecondaryColor3,
			BorderSizePixel = 0,
			
			LayoutOrder = 2,
		}),
		
		Roact.createElement("Frame", {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
		}, {
			Roact.createElement("TextLabel", {
				Text = "Red:",
				TextSize = Style.StdBodyTextSize,
				Font = Style.InformationFont,
				TextColor3 = Style.ActiveTextColor,
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
			}),
			Roact.createElement(Slider, {
				Min = 0,
				Max = 255,
				Init = self.ColorBinding:getValue().R * 255,
				UseThisBinding = self.ColorBinding:map(function(v)
					return v.R * 255
				end),
				Increment = 1,
				Callback = function(v)
					local c = self.ColorBinding:getValue()
					if math.round(c.R * 255) ~= math.round(v) then
						self.updColorBinding(Color3.new(v/255, c.G, c.B))
					end
				end,
				
				AnchorPoint = Vector2.new(1,0.5),
				Position = UDim2.new(1, 0, 0.5, 0)
			})
		}),
		
		Roact.createElement("Frame", {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
		}, {
			Roact.createElement("TextLabel", {
				Text = "Green:",
				TextSize = Style.StdBodyTextSize,
				Font = Style.InformationFont,
				TextColor3 = Style.ActiveTextColor,
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
			}),
			Roact.createElement(Slider, {
				Min = 0,
				Max = 255,
				Init = self.ColorBinding:getValue().G * 255,
				UseThisBinding = self.ColorBinding:map(function(v)
					return v.G * 255
				end),
				Increment = 1,
				Callback = function(v)
					local c = self.ColorBinding:getValue()
					if math.round(c.G * 255) ~= math.round(v) then
						self.updColorBinding(Color3.new(c.R, v/255, c.B))
					end
				end,
				
				AnchorPoint = Vector2.new(1,0.5),
				Position = UDim2.new(1, 0, 0.5, 0)
			})
		}),
		
		Roact.createElement("Frame", {
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
		}, {
			Roact.createElement("TextLabel", {
				Text = "Blue:",
				TextSize = Style.StdBodyTextSize,
				Font = Style.InformationFont,
				TextColor3 = Style.ActiveTextColor,
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
			}),
			Roact.createElement(Slider, {
				Min = 0,
				Max = 255,
				Init = self.ColorBinding:getValue().B * 255,
				UseThisBinding = self.ColorBinding:map(function(v)
					return v.B * 255
				end),
				Increment = 1,
				Callback = function(v)
					local c = self.ColorBinding:getValue()
					if math.round(c.B * 255) ~= math.round(v) then
						self.updColorBinding(Color3.new(c.R, c.G, v/255))
					end
				end,
				
				AnchorPoint = Vector2.new(1,0.5),
				Position = UDim2.new(1, 0, 0.5, 0)
			})
		}),
		
		Roact.createElement("Frame", {
			LayoutOrder = 5,
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
		}, {
			Roact.createElement("TextLabel", {
				Text = "Hue:",
				TextSize = Style.StdBodyTextSize,
				Font = Style.InformationFont,
				TextColor3 = Style.ActiveTextColor,
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
			}),
			Roact.createElement(Slider, {
				Min = 0,
				Max = 255,
				Init = select(1, GUILib.ColorToHSV(self.ColorBinding:getValue())),
				UseThisBinding = self.ColorBinding:map(function(v)
					return select(1, GUILib.ColorToHSV(v))
				end),
				Increment = 1,
				Callback = function(v)
					local h,s,va = GUILib.ColorToHSV(self.ColorBinding:getValue())
					if h ~= math.round(v) then
						self.updColorBinding(Color3.fromHSV(v/255, s/255, va/255))
					end
				end,
				
				AnchorPoint = Vector2.new(1,0.5),
				Position = UDim2.new(1, 0, 0.5, 0)
			})
		}),
		
		Roact.createElement("Frame", {
			LayoutOrder = 6,
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
		}, {
			Roact.createElement("TextLabel", {
				Text = "Saturation:",
				TextSize = Style.StdBodyTextSize,
				Font = Style.InformationFont,
				TextColor3 = Style.ActiveTextColor,
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
			}),
			Roact.createElement(Slider, {
				Min = 0,
				Max = 255,
				Init = select(2, GUILib.ColorToHSV(self.ColorBinding:getValue())),
				UseThisBinding = self.ColorBinding:map(function(v)
					return select(2, GUILib.ColorToHSV(v))
				end),
				Increment = 1,
				Callback = function(v)
					local h,s,va = GUILib.ColorToHSV(self.ColorBinding:getValue())
					if s ~= math.round(v) then
						self.updColorBinding(Color3.fromHSV(h/255, v/255, va/255))
					end
				end,
				
				AnchorPoint = Vector2.new(1,0.5),
				Position = UDim2.new(1, 0, 0.5, 0)
			})
		}),
		
		Roact.createElement("Frame", {
			LayoutOrder = 7,
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
		}, {
			Roact.createElement("TextLabel", {
				Text = "Value:",
				TextSize = Style.StdBodyTextSize,
				Font = Style.InformationFont,
				TextColor3 = Style.ActiveTextColor,
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
			}),
			Roact.createElement(Slider, {
				Min = 0,
				Max = 255,
				Init = select(3, GUILib.ColorToHSV(self.ColorBinding:getValue())),
				UseThisBinding = self.ColorBinding:map(function(v)
					return select(3, GUILib.ColorToHSV(v))
				end),
				Increment = 1,
				Callback = function(v)
					local h,s,va = GUILib.ColorToHSV(self.ColorBinding:getValue())
					if va ~= math.round(v) then
						self.updColorBinding(Color3.fromHSV(h/255, s/255, v/255))
					end
				end,
				
				AnchorPoint = Vector2.new(1,0.5),
				Position = UDim2.new(1, 0, 0.5, 0)
			}),
		}),
		
		Roact.createElement("Frame", {
			LayoutOrder = 8,
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
		}, {
			Roact.createElement("TextLabel", {
				Text = "Hex:",
				TextSize = Style.StdBodyTextSize,
				Font = Style.InformationFont,
				TextColor3 = Style.ActiveTextColor,
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
			}),
			Roact.createElement(TextBox, {
				Text = self.ColorBinding:map(function(v)
					return GUILib.ColorToHex(v)
				end),
				Increment = 1,
				Callback = function(v)
					local hex = GUILib.ColorToHex(self.ColorBinding:getValue())
					if hex ~= v then
						self.updColorBinding(GUILib.HexToColor(v))
					end
				end,
				
				Size = UDim2.new(0, Style.DialogueTextBoxWidth, 0, Style.StdBodyHeight),
				TextSize = Style.StdBodyTextSize,
				AnchorPoint = Vector2.new(1,0.5),
				Position = UDim2.new(1, 0, 0.5, 0)
			})
		}),
		
	}))
		
	
	return window.RoactTree
end

function ColorPicker:init()
	self.ColorBinding, self.updColorBinding = Roact.createBinding(self.props.Init)
end

function ColorPicker:render()
	return Roact.createElement(GUILib.StdImageButton, {
		BorderSizePixel = 1,
		BorderColor3 = Style.WindowBorderColor,
		Position = self.props.Position,
		AnchorPoint = self.props.AnchorPoint,
		Size = UDim2.new(0, Style.DialogueColorIconWidth, 0, 11),
		BackgroundColor3 = self.ColorBinding:map(function(v)
			self.props.Callback(v)
			return v
		end),
		[Roact.Event.MouseButton1Click] = function(rbx)
			PickerWindow.TurnOn(self.ColorBinding, self.updColorBinding)
		end,
	})
end

RunService.RenderStepped:Connect(function()
	if ActiveDragger then
		if UserInputService:IsMouseButtonPressed("MouseButton1") then
			local bounds, updColorBinding = ActiveDragger[1], ActiveDragger[2]
			
			local mousePos = Vector2.new(Mouse.X, Mouse.Y)
			local center = bounds.AbsolutePosition + bounds.AbsoluteSize/2
			
			local s = Math.Map(math.min((mousePos - center).Magnitude, 255/2), 0, 255/2, 0, 1)
			
			local adjacent = center.X - mousePos.X
			local opposite = center.Y - mousePos.Y
			local angle = math.atan2(-adjacent, opposite)
			
			local h = Math.Map(angle % (math.pi * 2), 0, math.pi * 2, 0, 1)
			
			updColorBinding(Color3.fromHSV(h, s, select(3, Color3.toHSV(ActiveDragger[3]:getValue()))))
		else
			ActiveDragger = nil
		end
	end
end)

Roact.mount(Roact.createElement(PickerWindow), game.Players.LocalPlayer.PlayerGui.BaseInterface)

function ColorPicker:__init(G)
	Style = G.Load("Style")
end

return ColorPicker

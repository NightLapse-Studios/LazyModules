
--[[
	Increment
	Min
	Max
	Init
	Callback(value)
	
	size is preset.
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Style
local Math = require(game.ReplicatedFirst.Modules.Math)
local TextBox = require(game.ReplicatedFirst.Modules.GUI.Textbox)
local Flipper = require(game.ReplicatedFirst.Modules.Flipper)
local GUI = require(game.ReplicatedFirst.Modules.GUI)
local Roact = require(game.ReplicatedFirst.Modules.Roact)

local slider = Roact.Component:extend("slider")

local meta = {__mode = "v"}
local grabbed = setmetatable({}, meta)

local function calcValue(self, v)
	local n = Math.Round(v, self.props.Increment)
	local min = self.props.Min
	local max = self.props.Max
	return math.clamp(n, min, max)
end

local function calcPos(self)
	return Math.Percent(self.Value:getValue(), self.props.Min, self.props.Max)
end

function slider:init()
	self.motor = Flipper.SingleMotor.new(0)
	self.ExpandBoxBinding, self.UpdExpandBoxBinding = Roact.createBinding(self.motor:getValue())
	self.motor:onStep(self.UpdExpandBoxBinding)
	
	self.Value, self.UpdValue = Roact.createBinding(calcValue(self, self.props.Init))
	if self.props.UseThisBinding then
		self.Value = Roact.joinBindings({self.props.UseThisBinding, self.Value}):map(function(vs)
			return calcValue(self, vs[1])
		end)
	end
	
	self.Ref = Roact.createRef()
end

function slider:render()
	return Roact.createElement(GUI.StdImageButton, {
		Size = UDim2.new(0, Style.SliderWidth, 0, Style.SliderHeight),
		Position = self.props.Position,
		AnchorPoint = self.props.AnchorPoint,
		BackgroundColor3 = Style.SecondaryColor2,
		BorderColor3 = Style.SecondaryColor1,
		LayoutOrder = self.props.LayoutOrder,
		
		[Roact.Ref] = self.Ref,
		
		[Roact.Event.MouseButton1Down] = function()
			grabbed[1] = self
		end,
	}, {
		Grabber = Roact.createElement(GUI.StdImageButton, {
			BackgroundColor3 = Style.PrimaryFocusColor,
			BorderSizePixel = 0,
			
			Size = Style.SliderHandleSize,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = self.Value:map(function(value)
				self.props.Callback(value)
				return UDim2.new(calcPos(self), 0, 0.5, 0)
			end),
			
			[Roact.Event.MouseButton1Down] = function()
				grabbed[1] = self
			end,
		}),
		Roact.createElement(TextBox, {
			Position = UDim2.new(0, -3, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Size = self.ExpandBoxBinding:map(function(v)
				return UDim2.new(0, Math.LerpNum(Style.SliderTextBoxWidth, Style.SliderTextBoxExpandWidth, v) , 0, Style.StdBodyHeight)
			end),
			BorderSizePixel = 0,
			PlaceholderText = "type an expression",
			
			[Roact.Event.Focused] = function(rbx)
				self.motor:setGoal(Flipper.Spring.new(1, {
					frequency = 2.5,
					dampingRatio = 1,
				}))
			end,
			[Roact.Event.FocusLost] = function(rbx)
				self.motor:setGoal(Flipper.Spring.new(0, {
					frequency = 2.5,
					dampingRatio = 1,
				}))
			end,
			
			TextSize = Style.StdBodyTextSize,
			
			TextTruncate = Enum.TextTruncate.AtEnd,
			
			Text = self.Value,
			
			IsNumber = true,
			Increment = self.props.Increment,
			Min = self.props.Min,
			Max = self.props.Max,
			Init = self.props.Init,
			Callback = function(value)
				self.UpdValue(value)
				self.props.Callback(value)
			end,
		})
	})
end

function slider:__run(G)
	if G.CONTEXT ~= "CLIENT" then
		return
	end

	local Mouse = game.Players.LocalPlayer:GetMouse()

	local function HandleRelease()
		grabbed = setmetatable({}, meta)
	end
	
	local function HandleMouseMove()
		local self = grabbed[1]
		
		if self then
			local gui = self.Ref:getValue()
			if gui then
				local x = Mouse.X
				
				local minGui = gui.AbsolutePosition.X
				local maxGui = minGui + gui.AbsoluteSize.X
				
				local newValue = Math.Map(x, minGui, maxGui, self.props.Min, self.props.Max)
				
				if self.props.UseThisBinding then
					self.props.Callback(calcValue(self, newValue))
				else
					self.UpdValue(calcValue(self, newValue))
				end
			end
		end
	end

	RunService.RenderStepped:Connect(HandleMouseMove)
	UserInputService.InputEnded:Connect(function(obj)
		if obj.UserInputType == Enum.UserInputType.MouseButton1 then
			HandleRelease()
		end
	end)
end

function slider:__init(G)
	Style = G.Load("Style")
end

return slider
local TextService = game:GetService("TextService")

local Style
local Roact = _G.Game.PreLoad(game.ReplicatedFirst.Modules.Roact)
local GUI = _G.Game.PreLoad(game.ReplicatedFirst.Modules.GUI)
local Math = _G.Game.PreLoad(game.ReplicatedFirst.Modules.Math)
local Flipper = _G.Game.PreLoad(game.ReplicatedFirst.Modules.Flipper)
local Enums = _G.Game.Enums
local Dialogue = _G.Game.PreLoad(game.ReplicatedFirst.Modules.GUI.Dialogue)
local MouseIcon = _G.Game.PreLoad(game.ReplicatedFirst.Modules.MouseIcon)

local ToolTipUI = Roact.Component:extend("ToolTipUI")

local MaxSize = Vector2.new(250, math.huge)
local padding = 6
local Height, Width = 0,0
local TextSize = 25

local sizeMotor = Flipper.SingleMotor.new(0)
local size, updsize = Roact.createBinding(sizeMotor:getValue())
sizeMotor:onStep(updsize)

local MousePositionBinding, UpdMousePositionBinding = Roact.createBinding(UDim2.new())
local AnchorBinding, UpdAnchorBinding = Roact.createBinding(Vector2.new())
local TargetSizeBinding, updTargetSizeBinding = Roact.createBinding(UDim2.new(0,0,0,0))

function ToolTipUI:init()
	self.TextBinding, self.UpdTextBinding = Roact.createBinding(nil)
	self.On = false
	
	function ToolTipUI.SetText(text)
		if text == self.TextBinding:getValue() then
			return
		end
		
		local old = self.On
		if text and text ~= "" then
			
			local requiredSize = TextService:GetTextSize(text, TextSize, Style.InformationFont, MaxSize)
			
			updTargetSizeBinding(UDim2.new(0, requiredSize.X, 0, requiredSize.Y))
			Height, Width = requiredSize.Y + padding * 2, requiredSize.X + padding * 2
			
			self.On = true
			
			sizeMotor:setGoal(Flipper.Spring.new(Width, {
				frequency = 3,
				dampingRatio = 0.8,
			}))
		else
			self.On = false
			
			sizeMotor:stop()
			sizeMotor = Flipper.SingleMotor.new(0)
			updsize(0)
			sizeMotor:onStep(updsize)
		end
		
		self.UpdTextBinding(text)
		
		if self.On ~= old then
			self:setState({})
		end
	end
	
	function ToolTipUI.IsOn()
		return self.On
	end
	
	function ToolTipUI.GetCurrentHover()
		return self.TextBinding:getValue()
	end
end

function ToolTipUI:render()
	if not self.On then
		return false
	end
	
	return Roact.createElement("Frame", {
		Position = MousePositionBinding,
		ClipsDescendants = true,
		Size = size:map(function(v)
			return UDim2.new(0,v, 0,Height)
		end),
		AnchorPoint = AnchorBinding,
		BackgroundColor3 = Style.SecondaryColor1,
	}, {
		Roact.createElement(GUI.Padding, {Pixels = padding}),
		Roact.createElement("UICorner", {
			CornerRadius = UDim.new(0, 7),
		}),
		Roact.createElement("UIStroke", {
			Thickness = 2,
			Color = Style.SecondaryColor3,
		}),
		Roact.createElement("TextLabel", {
			Size = TargetSizeBinding,
			RichText = true,
			BackgroundTransparency = 1,
			
			TextWrapped = true,
			Text = self.TextBinding,
			TextSize = TextSize,
			Font = Style.InformationFont,
			TextColor3 = Style.ActiveTextColor,
		})
	})
end

function ToolTipUI:__init(G)
	Style = G.Load("Style")

	game:GetService("RunService").RenderStepped:Connect(function()
		if ToolTipUI.IsOn() then
			local widgetEnum = Dialogue.GetBestWidgetEnum(Enums.WidgetPositions.RightCenter, Width, Height, MouseIcon.GetMouse(), 0)
			local anchor = Dialogue.getWidgetAnchor(widgetEnum)
			local x, y = Dialogue.getWidgetPos(MouseIcon.GetMouse(), widgetEnum, 0)
			UpdMousePositionBinding(UDim2.new(0, x, 0, y))
			UpdAnchorBinding(anchor)
		end
	end)

	Roact.mount(Roact.createElement(ToolTipUI), game.Players.LocalPlayer.PlayerGui.ToolTip)
end

return ToolTipUI
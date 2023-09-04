
--[[
	On-- the init state
	Pixels -- the size
	OnToggle(value)
]]

local Style
local Roact = require(game.ReplicatedFirst.Modules.Roact)
local GUI = require(game.ReplicatedFirst.Modules.GUI)

local BORDER_WIDTH = 1
local CHECK_INSET = 1

local component = Roact.Component:extend("Checkbox")

function component:init()
	local props = self.props
	
	self:setState({
		On = props.On or false,
	})
end

function component:render()
	local props = self.props
	local state = self.state
	
	if state.On then
		local fillSize = props.Pixels - BORDER_WIDTH * 2 - CHECK_INSET * 2
		
		return Roact.createElement(GUI.Border, {
			Pixels = BORDER_WIDTH,
			Position = props.Position,
			Size = UDim2.new(0, props.Pixels, 0, props.Pixels),
			ImageColor3 = Style.PrimaryFocusColor,
			AnchorPoint = props.AnchorPoint,
		}, {
			Roact.createElement("Frame", {
				BackgroundColor3 = Style.PrimaryFocusColor,
				Position = UDim2.new(0, BORDER_WIDTH + CHECK_INSET, 0, BORDER_WIDTH + CHECK_INSET),
				Size = UDim2.new(0, fillSize, 0, fillSize),
				BorderSizePixel = 0,
			}),
			Roact.createElement(GUI.StdImageButton, {
				Size = UDim2.new(1,0,1,0),
				BackgroundTransparency = 1,
				[Roact.Event.MouseButton1Click] = function(rbx)
					props.OnToggle(not state.On)
					self:setState({On = not state.On})
				end,
			})
		})
	else
		return Roact.createElement(GUI.Border, {
			Pixels = BORDER_WIDTH,
			Position = props.Position,
			Size = UDim2.new(0, props.Pixels, 0, props.Pixels),
			ImageColor3 = Style.PrimaryFocusColor,
			AnchorPoint = props.AnchorPoint,
		}, {
			Roact.createElement(GUI.StdImageButton, {
				Size = UDim2.new(1,0,1,0),
				BackgroundTransparency = 1,
				[Roact.Event.MouseButton1Click] = function(rbx)
					props.OnToggle(not state.On)
					self:setState({On = not state.On})
				end,
			})
		})
	end
end

function component:__init(G)
	Style = G.Load("Style")
end

return component
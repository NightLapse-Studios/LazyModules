
local TextService = game:GetService("TextService")
local Modules = game.ReplicatedFirst.Modules

-- Constants
local Style
local Enums = _G.Game.Enums
local Assets = _G.Game.PreLoad(Modules.Assets)

-- Builders
local GUILib = _G.Game.PreLoad(Modules.GUI)
local Roact = _G.Game.PreLoad(Modules.Roact)
local RelativeData = _G.Game.PreLoad(game.ReplicatedFirst.Util.RelativeData)

-- Buildings
local CheckBox = _G.Game.PreLoad(Modules.GUI.Checkbox)
local DropDowns = _G.Game.PreLoad(Modules.GUI.DropDownSelector)
local Sliders = _G.Game.PreLoad(Modules.GUI.Slider)
local TextBox = _G.Game.PreLoad(Modules.GUI.Textbox)
local ColorPicker = _G.Game.PreLoad(Modules.GUI.ColorPicker)

local WidgetPositions = Enums.WidgetPositions

local WidgetPositionData = RelativeData.new("WidgetPosition4Centers", {
	WidgetPositions.TopCenter,
	WidgetPositions.BottomCenter,
	WidgetPositions.TopRight,
	WidgetPositions.BottomLeft,
	WidgetPositions.RightCenter,
	WidgetPositions.LeftCenter,
	WidgetPositions.BottomRight,
	WidgetPositions.TopLeft,
})

local WidgetPositionAnchors = {
	Vector2.new(0.5, 1),
	Vector2.new(0.5, 0),
	Vector2.new(0, 1),
	Vector2.new(1, 0),
	Vector2.new(0, 0.5),
	Vector2.new(1, 0.5),
	Vector2.new(0, 0),
	Vector2.new(1, 1),
}

local EXTRA_EXTENTS = 20
local BIG_VEC = Vector2.new(1e10, 1e10)

local Dialogue = {}
Dialogue.__index = Dialogue

function  Dialogue.new(width, Transparency, segmentHeight)
	-- If width is nil, then it will be as big as it needs to be to fit everything.
	-- Padding is seperate from width.
	
	local obj = {
		Elements = {
			[1] = Roact.createElement(GUILib.VerticleLayout, {Padding = 1}),
		},
		
		Width = width,
		ExtentsSize = 0,
		Height = 0,
		Transparency = Transparency,
		SegmentHeight = segmentHeight,
	}
	setmetatable(obj, Dialogue)
	
	return obj
end

function Dialogue:AddButton( label, callback, props )
	if not self.Width then
		self.ExtentsSize = math.max(
			self.ExtentsSize,
			TextService:GetTextSize(label, Style.StdBodyTextSize, Style.LabelFont, BIG_VEC).X
		)
	end
	
	self.Height += Style.DialogueSegmentHeight
	
	local nextIndex = #self.Elements + 1
	self.Elements[nextIndex] =
	Roact.createElement(GUILib.StdImageButton, {
		Size = UDim2.new(UDim.new(1, 0), self.SegmentHeight),
		
		BackgroundColor3 = Style.SecondaryColor2,
		BorderSizePixel = 0,
		ImageTransparency = 1,
		
		LayoutOrder = nextIndex,
		[Roact.Event.Activated] = callback,
		[Roact.Attribute.ButtonImageColor] = Style.SecondaryColor3,
		Name = label,
		[Roact.Attribute.Name] = label,
	}, {
		Roact.createElement("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
		
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = label,
			TextColor3 = (props and props.TextColor3) or Style.ActiveTextColor,
			Font = Style.InformationFont,
			TextScaled = true
		})
	})
	
end

function Dialogue:AddSeparator()
	self.Height += Style.DialogueSpacerHeight
	
	local nextIndex = #self.Elements + 1
	self.Elements[nextIndex] =
	Roact.createElement("Frame", {
		Size = UDim2.new(UDim.new(1, 0), self.SegmentHeight),
		
		BackgroundColor3 = Style.SecondaryColor2,
		BorderSizePixel = 0,
		
		LayoutOrder = nextIndex,
	}, {
		Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, 2),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			
			BackgroundColor3 = Style.SecondaryColor4,
			BorderSizePixel = 0,
		})
	})
end

function Dialogue:AddPadding(ud)
	self.Height += Style.DialogueSpacerHeight
	
	local nextIndex = #self.Elements + 1
	self.Elements[nextIndex] =
	Roact.createElement("Frame", {
		Size = UDim2.new(UDim.new(1, 0), ud or self.SegmentHeight),
		
		BackgroundTransparency = 1,
		
		LayoutOrder = nextIndex,
	})
end

function Dialogue:AddTitle(text)
	if not self.Width then
		self.ExtentsSize = math.max(
			self.ExtentsSize,
			TextService:GetTextSize(text, Style.BigHeaderTextSize, Style.LabelFont, BIG_VEC).X
		)
	end
	
	self.Height += Style.DialogueHeaderHeight
	
	local nextIndex = #self.Elements + 1
	self.Elements[nextIndex] =
	Roact.createElement("Frame", {
		Size = UDim2.new(UDim.new(1, 0), self.SegmentHeight),
		
		BackgroundColor3 = Style.SecondaryColor2,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		
		LayoutOrder = nextIndex,
	}, {
		Roact.createElement("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 0),
			
			Text = text,
			Font = Style.LabelFont,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextColor3 = Style.ActiveTextColor,
			
			BackgroundColor3 = Style.SecondaryColor2,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}),
		Roact.createElement("Frame", {
			Size = UDim2.new(1, Style.DialogueLineAbovePadding, 0, 1),
			Position = UDim2.new(0.5, 0, 1, -2),
			AnchorPoint = Vector2.new(0.5, 1),
			
			BackgroundTransparency = 1,
			BackgroundColor3 = Style.SecondaryColor4,
			BorderSizePixel = 0,
		})
	})
end

function Dialogue:AddCheckbox(text, initState, callback)
	if not self.Width then
		self.ExtentsSize = math.max(
			self.ExtentsSize,
			TextService:GetTextSize(text, Style.StdHeaderTextSize, Style.LabelFont, BIG_VEC).X + Style.CheckBoxSize
		)
	end
	
	self.Height += Style.DialogueSegmentHeight
	
	local checkBox = Roact.createElement(CheckBox, {
		Pixels = Style.CheckBoxSize,
		On = initState,
		OnToggle = callback,
		
		AnchorPoint = Vector2.new(1,0.5),
		Position = UDim2.new(1, 0, 0.5, 0)
	})
	
	local nextIndex = #self.Elements + 1
	self.Elements[nextIndex] =
	Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, Style.DialogueSegmentHeight),
		
		BackgroundColor3 = Style.SecondaryColor2,
		BorderSizePixel = 0,
		
		LayoutOrder = nextIndex,
		
		-- this is a usual, but it's fine wihthout it, bc we can't get state from outside.
		--[[ [Roact.Event.MouseButton1Click] = function()
			checkBox:setState({On = not checkBox.state.On})
		end, ]]
	}, {
		Roact.createElement("TextLabel", {
			Size = UDim2.new(1, -Style.CheckBoxSize-3, 1, 0),
		
			BorderSizePixel = 0,
			BackgroundColor3 = Style.SecondaryColor2,
			BackgroundTransparency = 1,
			
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = text,
			TextColor3 = Style.ActiveTextColor,
			Font = Style.LabelFont,
			TextSize = Style.StdHeaderTextSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
		
		checkBox
	})
end

function Dialogue:AddDropdown(text, options, initOptionName, callback, colors, doHideCallback, addChildrenToOptions, displayNames)
	if not self.Width then
		self.ExtentsSize = math.max(
			self.ExtentsSize,
			TextService:GetTextSize(text, Style.StdHeaderTextSize, Style.LabelFont, BIG_VEC).X + Style.DropDownSelectorWidth
		)
	end
	
	local ZBind, updZBind = Roact.createBinding(3)
	self.Height += Style.DialogueSegmentHeight
	
	local dropDown = Roact.createElement(DropDowns, {
		Options = options,
		Colors = colors,
		DoHideCallback = doHideCallback,
		DisplayNames = displayNames,
		AddChildrenToOptions = addChildrenToOptions,
		InitOptionName = initOptionName,
		Callback = callback,
		OnToggle = function()
			if ZBind:getValue() == 3 then
				updZBind(4)
			else
				updZBind(3)
			end
		end,
		
		AnchorPoint = Vector2.new(1,0.5),
		Position = UDim2.new(1, 0, 0.5, 0)
	})
	
	local nextIndex = #self.Elements + 1
	self.Elements[nextIndex] =
	Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, Style.DialogueSegmentHeight),
		
		BackgroundColor3 = Style.SecondaryColor2,
		BorderSizePixel = 0,
		
		ZIndex = ZBind,-- For the drop down to render above the parents
		
		LayoutOrder = nextIndex,
	}, {
		Roact.createElement("TextLabel", {
			Size = UDim2.new(1, -Style.DropDownSelectorWidth - 3, 1, 0),
		
			BorderSizePixel = 0,
			BackgroundColor3 = Style.SecondaryColor2,
			BackgroundTransparency = 1,
			
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = text,
			TextColor3 = Style.ActiveTextColor,
			Font = Style.LabelFont,
			TextSize = Style.StdHeaderTextSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
		
		dropDown
	})
end

function Dialogue:AddLabeledButton(text, btnText, callback, btnColor)
	if not self.Width then
		self.ExtentsSize = math.max(
			self.ExtentsSize,
			TextService:GetTextSize(text, Style.StdHeaderTextSize, Style.LabelFont, BIG_VEC).X + Style.DialogueTextBoxWidth
		)
	end
	
	self.Height += Style.DialogueSegmentHeight
	
	local nextIndex = #self.Elements + 1
	self.Elements[nextIndex] =
	Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, Style.DialogueSegmentHeight),
		
		BackgroundColor3 = Style.SecondaryColor2,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		
		LayoutOrder = nextIndex,
	}, {
		Roact.createElement("TextLabel", {
			Size = UDim2.new(1, - Style.DialogueTextBoxWidth, 1, 0),
		
			BorderSizePixel = 0,
			BackgroundColor3 = Style.SecondaryColor2,
			BackgroundTransparency = 1,
			
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = text,
			TextColor3 = Style.ActiveTextColor,
			Font = Style.LabelFont,
			TextSize = Style.StdHeaderTextSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
		
		Roact.createElement(GUILib.StdTextButton, {
			Position = UDim2.new(1,0,0,0),
			AnchorPoint = Vector2.new(1,0),
			Size = UDim2.new(0,Style.DialogueTextBoxWidth,1,0),
			
			Text = btnText,
			Font = Style.LabelFont,
			TextColor3 = Style.ActiveTextColor,
			TextSize = Style.StdHeaderTextSize,
			
			BackgroundTransparency = self.Transparency,
			BackgroundColor3 = btnColor,
			BorderColor3 = Style.PrimaryFocusColor,
			BorderMode = Enum.BorderMode.Inset,
			BorderSizePixel = 1,
			
			[Roact.Event.MouseButton1Click] = callback,
		})
	})
end

function Dialogue:AddSlider(text, min, max, Increment, init, callback)
	if not self.Width then
		self.ExtentsSize = math.max(
			self.ExtentsSize,
			TextService:GetTextSize(text, Style.StdHeaderTextSize, Style.LabelFont, BIG_VEC).X + Style.SliderWidth + Style.SliderTextBoxWidth
		)
	end
	
	self.Height += Style.DialogueSegmentHeight
	
	local slider = Roact.createElement(Sliders, {
		Min = min,
		Max = max,
		Init = init,
		Increment = Increment,
		Callback = callback,
		
		AnchorPoint = Vector2.new(1,0.5),
		Position = UDim2.new(1, 0, 0.5, 0)
	})
	
	local nextIndex = #self.Elements + 1
	self.Elements[nextIndex] =
	Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, Style.DialogueSegmentHeight),
		
		BackgroundColor3 = Style.SecondaryColor2,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		
		LayoutOrder = nextIndex,
	}, {
		Roact.createElement("TextLabel", {
			Size = UDim2.new(1, - Style.SliderWidth - Style.SliderTextBoxWidth - 3, 1, 0),
		
			BorderSizePixel = 0,
			BackgroundColor3 = Style.SecondaryColor2,
			BackgroundTransparency = 1,
			
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = text,
			TextColor3 = Style.ActiveTextColor,
			Font = Style.LabelFont,
			TextSize = Style.StdHeaderTextSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
		
		slider
	})
end

function Dialogue:AddColorPicker(text, init, callback)
	if not self.Width then
		self.ExtentsSize = math.max(
			self.ExtentsSize,
			TextService:GetTextSize(text, Style.StdHeaderTextSize, Style.LabelFont, BIG_VEC).X + Style.DialogueColorIconWidth
		)
	end
	
	self.Height += Style.DialogueSegmentHeight
	
	local nextIndex = #self.Elements + 1
	self.Elements[nextIndex] = Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, Style.DialogueSegmentHeight),
		
		BackgroundColor3 = Style.SecondaryColor2,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		
		LayoutOrder = nextIndex,
	}, {
		Roact.createElement("TextLabel", {
			Size = UDim2.new(1, -Style.DialogueColorIconWidth - 3, 1, 0),
		
			BorderSizePixel = 0,
			BackgroundColor3 = Style.SecondaryColor2,
			BackgroundTransparency = 1,
			
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = text,
			TextColor3 = Style.ActiveTextColor,
			Font = Style.LabelFont,
			TextSize = Style.StdHeaderTextSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
		
		Roact.createElement(ColorPicker, {
			Init = init,
			Callback = callback,
			Position = UDim2.new(1, -2, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5)
		}),
	})
end

function Dialogue:AddTextBox(text, init, minchar, maxchar, callback, verify)
	if not self.Width then
		self.ExtentsSize = math.max(
			self.ExtentsSize,
			TextService:GetTextSize(text, Style.StdHeaderTextSize, Style.LabelFont, BIG_VEC).X + Style.DialogueTextBoxWidth
		)
	end
	
	self.Height += Style.DialogueSegmentHeight
	
	local box = Roact.createElement(TextBox, {
		Init = init,
		Verify = verify,
		Min = minchar,
		Max = maxchar,
		Callback = callback,
		
		AnchorPoint = Vector2.new(1,0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, Style.DialogueTextBoxWidth, 0, Style.StdBodyHeight),
		TextSize = Style.StdBodyTextSize,
		
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	
	local nextIndex = #self.Elements + 1
	self.Elements[nextIndex] =
	Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, Style.DialogueSegmentHeight),
		
		BackgroundColor3 = Style.SecondaryColor2,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		
		LayoutOrder = nextIndex,
	}, {
		Roact.createElement("TextLabel", {
			Size = UDim2.new(1, -Style.DialogueTextBoxWidth - 3, 1, 0),
		
			BorderSizePixel = 0,
			BackgroundColor3 = Style.SecondaryColor2,
			BackgroundTransparency = 1,
			
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = text,
			TextColor3 = Style.ActiveTextColor,
			Font = Style.LabelFont,
			TextSize = Style.StdHeaderTextSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
		
		box
	})
end

function Dialogue:AddText(text, rich, rightAlign)
	if not self.Width then
		local thisText = text
		if rich then
			thisText = string.gsub(text, "%b<>", "")
		end
		
		self.ExtentsSize = math.max(
			self.ExtentsSize,
			TextService:GetTextSize(thisText, Style.StdBodyTextSize, Style.InformationFont, BIG_VEC).X
		)
	end
	
	self.Height += Style.DialogueSegmentHeight
	
	local nextIndex = #self.Elements + 1
	self.Elements[nextIndex] =
	Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, Style.DialogueSegmentHeight),
		
		BackgroundTransparency = 1,
		BackgroundColor3 = Style.SecondaryColor2,
		BorderSizePixel = 0,
		
		LayoutOrder = nextIndex,
	}, {
		Roact.createElement("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 0),
			
			RichText = rich,
			Text = text,
			Font = Style.InformationFont,
			TextSize = Style.StdBodyTextSize,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = rightAlign and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextColor3 = Style.ActiveTextColor,
			
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	})
end

function Dialogue:GetWidth()
	return self.Width or self.ExtentsSize + 2 + Style.DialoguePadding + EXTRA_EXTENTS
end

function Dialogue:GetFinishedElement(doAutoY)
	-- Inherents the parents size with optionally scalling the Y to fit the contents.
	
	if #self.Elements <= 0 then
		return false
	end
	
	return Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, doAutoY and 0 or 1, 0),
		AutomaticSize = doAutoY and Enum.AutomaticSize.Y or nil,
		
		ClipsDescendants = false,
		BackgroundTransparency = self.Transparency,
		BackgroundColor3 = Style.SecondaryColor2,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 999999999,
	},{
		Roact.createFragment(self.Elements),
		Roact.createElement(GUILib.Padding, {
			Pixels = Style.DialoguePadding,
		})
	})
end

function Dialogue.getWidgetAnchor(widgetPosition)
	return WidgetPositionAnchors[WidgetPositionData.Hash[widgetPosition]]
end

function Dialogue.getWidgetPos(rbx, widgetPosition, padding)
	local size = rbx.AbsoluteSize
	local topLeft = rbx.AbsolutePosition
	local botRight = topLeft + size
	local left_x, top_y = topLeft.X, topLeft.Y
	local right_x, bot_y = botRight.X, botRight.Y
	local cen_x, cen_y = (left_x + right_x) * 0.5, (top_y + bot_y) * 0.5
	
	if widgetPosition == WidgetPositions.TopCenter then
		return cen_x, top_y - padding
	elseif widgetPosition == WidgetPositions.BottomCenter then
		return cen_x, bot_y + padding
	elseif widgetPosition == WidgetPositions.LeftCenter then
		return left_x - padding, cen_y
	elseif widgetPosition == WidgetPositions.RightCenter then
		return right_x + padding, cen_y
	elseif widgetPosition == WidgetPositions.TopLeft then
		return left_x - padding, top_y - padding
	elseif widgetPosition == WidgetPositions.TopRight then
		return right_x + padding, top_y - padding
	elseif widgetPosition == WidgetPositions.BottomRight then
		return right_x + padding, bot_y + padding
	elseif widgetPosition == WidgetPositions.BottomLeft then
		return left_x - padding, bot_y + padding
	end
end

local function cutRight(px, width, WindowSize, full)
	return math.max(px + (full and width or width * 0.5) - WindowSize.X, 0)
end
local function cutLeft(px, width, full)
	return math.max((full and width or width * 0.5) - px, 0)
end
local function cutTop(py, height, full)
	return math.max((full and height or height * 0.5) - py, 0)
end
local function cutBottom(py, height, WindowSize, full)
	return math.max(py + (full and height or height * 0.5) - WindowSize.Y, 0)
end

function Dialogue.getWidgetCutAmount(widgetPos, width, height, rbx, padding)
	local WindowSize = workspace.CurrentCamera.ViewportSize
	
	local px, py = Dialogue.getWidgetPos(rbx, widgetPos, padding)
	
	py += 36
	
	--returns the sum of the pixels hanging off the screen for the 3 edges farthest from the widget anchor.
	--could probably be simplified.
	if widgetPos == WidgetPositions.TopCenter then
		return cutLeft(px, width) + cutRight(px, width, WindowSize) + cutTop(py, height, true)
	elseif widgetPos == WidgetPositions.BottomCenter then
		return cutLeft(px, width) + cutRight(px, width, WindowSize) + cutBottom(py, height, WindowSize, true)
	elseif widgetPos == WidgetPositions.LeftCenter then
		return cutTop(py, height) + cutBottom(py, height, WindowSize) + cutLeft(px, width, true)
	elseif widgetPos == WidgetPositions.RightCenter then
		return cutTop(py, height) + cutBottom(py, height, WindowSize) + cutRight(px, width, WindowSize, true)
	elseif widgetPos == WidgetPositions.TopLeft then
		return cutTop(py, height, true) + cutLeft(px, width, true)
	elseif widgetPos == WidgetPositions.TopRight then
		return cutTop(py, height, true) + cutRight(px, width, WindowSize, true)
	elseif widgetPos == WidgetPositions.BottomRight then
		return cutBottom(py, height, WindowSize, true) + cutRight(px, width, WindowSize, true)
	elseif widgetPos == WidgetPositions.BottomLeft then
		return cutBottom(py, height, WindowSize, true) + cutLeft(px, width, true)
	end
end

local function tryForBest(widgetPosition, width, height, RBX, padding, curBestCut, curBestPos)
	local cut = Dialogue.getWidgetCutAmount(widgetPosition, width, height, RBX, padding)
	
	-- if there was some off the screen, try the opposite side.
	if cut > 0 then
		if cut < curBestCut then
			return cut, widgetPosition
		end
		return curBestCut, curBestPos
	else
		return true, widgetPosition
	end
end

function Dialogue.GetBestWidgetEnum(desiredWidgetPosition, width, height, RBX, padding)
	local bestPos, bestCut = desiredWidgetPosition, math.huge
	
	bestCut, bestPos = tryForBest(desiredWidgetPosition, width, height, RBX, padding, bestCut, bestPos)
	if bestCut == true then return bestPos end
	
	bestCut, bestPos = tryForBest(WidgetPositionData:Opposite(desiredWidgetPosition), width, height, RBX, padding, bestCut, bestPos)
	if bestCut == true then return bestPos end
	
	bestCut, bestPos = tryForBest(WidgetPositionData:ClockWise(WidgetPositionData:ClockWise(desiredWidgetPosition)), width, height, RBX, padding, bestCut, bestPos)
	if bestCut == true then return bestPos end
	
	bestCut, bestPos = tryForBest(WidgetPositionData:CounterClockWise(WidgetPositionData:CounterClockWise(desiredWidgetPosition)), width, height, RBX, padding, bestCut, bestPos)
	if bestCut == true then return bestPos end
	
	bestCut, bestPos = tryForBest(WidgetPositionData:CounterClockWise(desiredWidgetPosition), width, height, RBX, padding, bestCut, bestPos)
	if bestCut == true then return bestPos end
	
	bestCut, bestPos = tryForBest(WidgetPositionData:ClockWise(desiredWidgetPosition), width, height, RBX, padding, bestCut, bestPos)
	if bestCut == true then return bestPos end
	
	bestCut, bestPos = tryForBest(WidgetPositionData:Opposite(WidgetPositionData:CounterClockWise(desiredWidgetPosition)), width, height, RBX, padding, bestCut, bestPos)
	if bestCut == true then return bestPos end
	
	bestCut, bestPos = tryForBest(WidgetPositionData:Opposite(WidgetPositionData:ClockWise(desiredWidgetPosition)), width, height, RBX, padding, bestCut, bestPos)
	
	return bestPos
end
-- Positions the Dialogue like hovering over something in discord does.
function Dialogue:GetFinishedElementAtWidgetPosition( RBX, desiredWidgetPosition: Centers, padding )
	padding = padding or 0
	
	if #self.Elements <= 0 then
		return false
	end
	
	-- 2 pixels of extra padding
	local width = self.Width
	if not width then
		width = self.ExtentsSize + 2 + Style.DialoguePadding + EXTRA_EXTENTS
	end
	
	local height = self.Height + 2
	
	-- favor the desired widget position first.
	local bestWidgetPos = Dialogue.GetBestWidgetEnum(desiredWidgetPosition, width, height, RBX, padding)
	
	local px, py = Dialogue.getWidgetPos(RBX, bestWidgetPos, padding)
	
	return Roact.createElement("Frame", {
		Size = UDim2.new(0, width - 2, 0, 0),
		Position = UDim2.new(0, px, 0, py),
		AnchorPoint = Dialogue.getWidgetAnchor(bestWidgetPos),
		AutomaticSize = Enum.AutomaticSize.Y,
		
		ClipsDescendants = false,
		BackgroundTransparency = 0,
		BackgroundColor3 = Style.SecondaryColor2,
		BorderSizePixel = 1,
		BorderColor3 = Style.WindowBorderColor,
		BorderMode = Enum.BorderMode.Outline,
		Active = true,
		ZIndex = 999999999,
	},{
		Roact.createFragment(self.Elements),
		Roact.createElement(GUILib.Padding, {
			Pixels = Style.DialoguePadding,
		})
	})
end

-- will try to position at bottom right of position.
function Dialogue:GetFinishedElementAtPosition( position )
	if not position then
		return false
	end

	if #self.Elements <= 0 then
		return false
	end

	local width = self.Width
	if not width then
		width = self.ExtentsSize + Style.DialoguePadding + EXTRA_EXTENTS
	end
	local height = self.Height
	
	-- correct the dialogue from extending the window. We apply 2 pixels of padding for borders.
	-- I chose Y to change anchor points if it extends, we must do this because if you right click in the bottom right
	-- your mouse will otherwise be over the menu. Must add stupid 36 pixels for GUI stupid Y inset biggest roblox mistake of lifetime.
	local windowSize = workspace.CurrentCamera.ViewportSize
	
	if position.X + width + 2 > windowSize.X then
		position = Vector2.new(windowSize.X - width - 2, position.Y)
	end
	
	local anchY = 0
	if position.Y + height + 2 + 36 > windowSize.Y then
		anchY = 1
	end
	
	position = UDim2.new(0, position.X, 0, position.Y)
	
	return Roact.createElement("Frame", {
		Size = UDim2.new(0, width, 0, 0),
		Position = position,
		AnchorPoint = Vector2.new(0, anchY),
		AutomaticSize = Enum.AutomaticSize.Y,
		
		ClipsDescendants = false,
		BackgroundTransparency = 0,
		BackgroundColor3 = Style.SecondaryColor2,
		BorderSizePixel = 1,
		BorderColor3 = Style.WindowBorderColor,
		BorderMode = Enum.BorderMode.Outline,
		Active = true,
		ZIndex = 999999999,
	},{
		Roact.createFragment(self.Elements),
		Roact.createElement(GUILib.Padding, {
			Pixels = Style.DialoguePadding,
		})
	})
end

--[[ function Dialogue:GetAsFragment()
	return Roact.createFragment(self.Elements)
end ]]

function Dialogue:__init(G)
	Style = G.Load("Style")
end

return Dialogue

local Style
local Roact
local Assets
local Enums = _G.Game.Enums
local String
local EffectUtil
local Audio
local Globals

local module = {}

local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local I, P, D

local RoactEvents
local ButtonIcon = nil
local MouseIcon

local updServerTime
local updPlayTime
local rightclickBind
local TeamFireLimit = 0
local SpamPassRate = 60*5 -- if being spammed, a notification will pass this often
local SpamPassRateAppliesAt = SpamPassRate * 2-- * number of messages that can get through before PassRate limit takes affect
local plr = game.Players.LocalPlayer

local StandardAnchorPoint = Vector2.new(0, 0)
local StandardPosition = UDim2.new(0, 0, 0, 0)

local updTime
--[[ module.CurrentTime, updTime = Roact.createBinding(0)
module.CurrentTime = Roact.joinBindings({module.CurrentTime, Settings.GetSettingsRoactBinding("DisplayTime")}):map(function(values)
	local set = values[2]
	
	if set == Enums.DisplayTimes["12Hour"] then
		return os.date("%I:%M:%S %p")
	elseif set == Enums.DisplayTimes["24Hour"] then
		return os.date("%X")
	else
		return "ERR: " .. (set or "")
	end
end) ]]


function module.HideUI()
	local gui = game.Players.LocalPlayer.PlayerGui
	gui.BaseInterface.Enabled = false
	gui.MiniMap.Enabled = false
end

function module.ShowUI()
	local gui = game.Players.LocalPlayer.PlayerGui
	gui.BaseInterface.Enabled = true
	gui.MiniMap.Enabled = true
end

function module.HexToColor(hex)
    hex = string.gsub(hex, "#", "")
    return Color3.fromRGB(tonumber("0x"..string.sub(hex, 1,2)), tonumber("0x"..string.sub(hex, 3,4)), tonumber("0x"..string.sub(hex, 5,6)))
end

function module.ColorToHex(color)
	local rgb = (math.round(color.R * 255) * 0x10000) + (math.round(color.G * 255) * 0x100) + math.round(color.B * 255)
	local str = string.format("%x", rgb)
	if #str ~= 6 then
		str = String.BuildString("0", 6 - #str) .. str
	end
    return str
end

function module.ColorToRGB(color)
	return math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255)
end

function module.ColorToHSV(color)
	local h,s,v = Color3.toHSV(color)
	
	return math.round(h * 255), math.round(s * 255), math.round(v * 255)
end

function module.GetColorTypes(color)
	local r,g,b = module.ColorToRGB(color)
	local h,s,v = module.ColorToHSV(color)
	local hex = module.ColorToHex(color)
	return r,g,b,h,s,v,hex
end

function module.IsScrollBarAtEnd(barRBX, damp)
	damp = damp or 1
	
	local maxYPosition = barRBX.AbsoluteCanvasSize.Y - barRBX.AbsoluteSize.Y
	local currentYPosition = barRBX.CanvasPosition.Y
	
	if currentYPosition + damp >= maxYPosition then-- add one to damp
		return true
	end
end

function module.GetTextSize(rbx, size, text)
	return TextService:GetTextSize(text or rbx.Text, rbx.TextSize, rbx.Font, size or rbx.AbsoluteSize)
end

function module.Border( props )
	--The image is a 64 x 64 with a white border of 16 x 16
	--any border sizes bigger than 16 will begin to look blurry
	--for color use ImageColor3
	
	props.SliceCenter = Rect.new(32, 32, 32, 32)
	props.ScaleType = Enum.ScaleType.Slice
	props.SliceScale = props.Pixels / 16
	props.Image = Assets.Images.Border
	
	props.Pixels = nil
	props.BackgroundTransparency = 1
	
	return Roact.createElement("ImageLabel", props)
end

function module.StandardVerticalScrollingFrame( props )
	local children = props[Roact.Children]
	if not children then
		props[Roact.Children] = {}
		children = props[Roact.Children]
	end
	
	children.UIListLayout = props.Layout or Roact.createElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, props.Padding or 2)
	})
	
	props.Layout = nil
	props.Padding = nil
	
	props.CanvasSize = props.CanvasSize or UDim2.new(0, 0, 0, 0)
	props.BackgroundColor3 = props.BackgroundColor3 or Style.SecondaryColor1
	props.BorderSizePixel = props.BorderSizePixel or 0
	props.ScrollBarThickness = Style.ScrollBarSize
	props.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	props.ScrollingDirection = Enum.ScrollingDirection.Y
	props.BottomImage = ""
	props.TopImage = ""
	props.AutomaticCanvasSize = props.AutomaticCanvasSize or Enum.AutomaticSize.Y
	
	local frame = Roact.createElement("ScrollingFrame", props)

	return frame
end

function module.StandardHorizontalScrollingFrame( props )
	local children = props[Roact.Children]
	
	children.UIListLayout = Roact.createElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = props.VA,
		Padding = UDim.new(0, props.Padding or 2)
	})
	
	props.Padding = nil
	props.VA = nil
	
	props.CanvasSize = UDim2.new(0, 0, 0, 0)
	props.BackgroundColor3 = props.BackgroundColor3 or Style.SecondaryColor1
	props.BorderSizePixel = props.BorderSizePixel or 0
	props.ScrollBarThickness = 0
	props.HorizontalScrollBarInset = Enum.ScrollBarInset.None
	props.ScrollingDirection = Enum.ScrollingDirection.X
	props.BottomImage = ""
	props.TopImage = ""
	props.AutomaticCanvasSize = Enum.AutomaticSize.X
	
	local frame = Roact.createElement("ScrollingFrame", props)

	return frame
end

function module.TrendColors()
	return Style.DarkTextColor, Style.GrowColor, Style.DeleteColor
end

function module.ColorToPrefix(colorOrTrend)
	if colorOrTrend == nil then
		colorOrTrend = Style.DarkTextColor:getValue()
	elseif colorOrTrend == true then
		colorOrTrend = Style.GrowColor:getValue()
	elseif colorOrTrend == false then
		colorOrTrend = Style.DeleteColor:getValue()
	end
	
	return string.format('<font color="rgb(%d,%d,%d)">',
		math.round(255 * colorOrTrend.R),
		math.round(255 * colorOrTrend.G),
		math.round(255 * colorOrTrend.B)
	)
end-- prefix: </font>

function module.NameTag(props)
	return Roact.createElement("BillboardGui", {
		Adornee = props.Adornee,
		Size = UDim2.new(4, 0, 0.3, 10),
		StudsOffset = props.StudsOffset or Vector3.new(0, -2, 0),
		StudsOffsetWorldSpace = props.StudsOffsetWorldSpace,
		ClipsDescendants = false,
		Active = false,
		AlwaysOnTop = true,
		MaxDistance = 600,
		LightInfluence = 0,
	}, {
		Roact.createElement("TextLabel", {
			Text = props.Name,
			AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
			Position = props.Position or UDim2.new(0.5,0,0.5,0),
			Size = UDim2.new(55, 0, 1, 0),
			Font = Style.LabelFont,
			TextScaled = true,
			TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center,
			BackgroundTransparency = 1,
			TextColor3 = props.Color or Color3.new(1,1,1),
		})
	})
end

function module.StandardXYScrollingFrame( props )
	props.CanvasSize = UDim2.new(0, 0, 0, 0)
	props.BackgroundColor3 = props.BackgroundColor3 or Style.SecondaryColor1
	props.BorderSizePixel = 0
	props.ScrollBarThickness = Style.ScrollBarSize
	props.HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	props.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	props.ScrollingDirection = Enum.ScrollingDirection.XY
	props.BottomImage = ""
	props.TopImage = ""
	props.AutomaticCanvasSize = Enum.AutomaticSize.XY

	local frame = Roact.createElement("ScrollingFrame", props)

	return frame
end

local ViewportSize = workspace.CurrentCamera.ViewportSize
function module.ScaleToOffset(udim2: UDim2, parent)
	local curSize = if parent then parent.AbsoluteSize else ViewportSize
	local x, y = curSize.X, curSize.Y - 36
	
	local ux, uy = udim2.X, udim2.Y
	
	x = ux.Offset + (ux.Scale * x)
	y = uy.Offset + (uy.Scale * y)
	
	return UDim2.new(0, x, 0, y)
end

function module.OffsetToScale(udim2: UDim2)
	local curSize = ViewportSize
	local x, y = curSize.X, curSize.Y - 36
	
	local ux, uy = udim2.X, udim2.Y
	
	x = ux.Offset / x + ux.Scale
	y = uy.Offset / y + uy.Scale
	
	return UDim2.new(x, 0, y, 0)
end

function module.StandardTextBox(props)
	local oldLost = props[Roact.Event.FocusLost]
	local oldGained = props[Roact.Event.Focused]
	local placeholderText = props.PlaceholderText
	
	local bind, updbind = Roact.createBinding(false)
	local oldbind = bind
	if type(placeholderText) == "table" then
		bind = Roact.joinBindings({bind, Style.DisabledTransparency, Style.TextCursorColor, Style.ActiveTextColor, props.PlaceholderText})
	else
		bind = Roact.joinBindings({bind, Style.DisabledTransparency, Style.TextCursorColor, Style.ActiveTextColor})
	end
	
	-- the purpose of these two connections is to make the cursor a different color from the placeholder text
	props[Roact.Event.FocusLost] = function(rbx, ...)
		if oldLost then
			oldLost(rbx, ...)
		end
		
		updbind(false)
	end
	
	props[Roact.Event.Focused] = function(rbx, ...)
		if oldGained then
			oldGained(rbx, ...)
		end
		
		updbind(true)
	end
	
	props.PlaceholderColor3 = bind:map(function(vs)
		if vs[1] then
			return vs[3]
		else
			return vs[4]
		end
	end)
	props.TextTransparency = bind:map(function(vs)
		if vs[1] then
			return 0
		else
			return vs[2]
		end
	end)
	props.Text = props.Text or ""
	props.ClearTextOnFocus = false
	props.TextWrapped = true
	props.TextEditable = true
	props.TextColor3 = Style.ActiveTextColor
	props.BackgroundColor3 = Style.SecondaryColor3
	props.Font = Style.InformationFont
	props.BorderColor3 = props.BorderColor3 or Style.WindowBorderColor
	props.PlaceholderText = bind:map(function(vs)
		if vs[1] then
			return ""
		else
			return vs[5] or placeholderText
		end
	end)
	
	return Roact.createElement("TextBox", props)
end

local enterTween = TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local changeAmount = 0.2

local lastTweens = nil
local enterTweenFinishedConnection = nil
local updateAppearanceConnection = nil

function module.DoButtonEnter(rbx)
	--ButtonIcon = MouseIcon.SetIcon(Assets.Images.MouseIcons[Enums.MouseIconsBack[Settings.GetSetting("MouseIcon")] .. "Hover"])
	
	local ButtonRaise = rbx:GetAttribute("ButtonRaise")
	local ButtonScale = rbx:GetAttribute("ButtonScale")
	local ButtonDropColor = rbx:GetAttribute("ButtonDropColor")
	local ButtonImageColor = rbx:GetAttribute("ButtonImageColor")
	local EnterTween = rbx:GetAttribute("EnterTime")
	
	--print(ButtonImageColor, "Color")
	
	lastTweens = {}
	
	local uiScale
	local gradient
	local oldpos = rbx.Position
	
	local et = enterTween
	if EnterTween then
		et = TweenInfo.new(EnterTween, et.EasingStyle, et.EasingDirection)
	end
	
	if ButtonRaise then
		lastTweens.Position = {TweenService:Create(rbx, et, {Position = oldpos + UDim2.new(0, 0, 0, -ButtonRaise)}), oldpos}
	end
	if ButtonScale then
		uiScale = Instance.new("UIScale")
		uiScale.Scale = 1
		uiScale.Parent = rbx
		
		lastTweens.Scale = {TweenService:Create(uiScale, et, {Scale = ButtonScale}), uiScale}
	end
	if ButtonDropColor then
		gradient = Instance.new("UIGradient")
		gradient.Color = ButtonDropColor
		gradient.Rotation = 90
		gradient.Offset = Vector2.new(0, 1)
		gradient.Parent = rbx
		
		lastTweens.Drop = {TweenService:Create(gradient, et, {Offset = Vector2.new(0, 0)}), gradient}
	end
	if ButtonImageColor then
		if rbx:IsA("ImageButton") then
			lastTweens.ImageColor = {TweenService:Create(rbx, et, {ImageColor3 = ButtonImageColor, BackgroundColor3 = ButtonImageColor}), rbx.ImageColor3, rbx.BackgroundColor3}
		else
			lastTweens.ImageColor = {TweenService:Create(rbx, et, {BackgroundColor3 = ButtonImageColor}), rbx.BackgroundColor3}
		end
	end
	
	local last = nil
	for i,v in pairs(lastTweens)do
		v[1]:Play()
		last = v[1]
	end
	
	if not last then
		return
	end
	
	enterTweenFinishedConnection = last.Completed:Connect(function()
		updateAppearanceConnection = RunService.RenderStepped:Connect(function()
			ButtonRaise = rbx:GetAttribute("ButtonRaise")
			ButtonScale = rbx:GetAttribute("ButtonScale")
			ButtonDropColor = rbx:GetAttribute("ButtonDropColor")
			ButtonImageColor = rbx:GetAttribute("ButtonImageColor")
			
			if ButtonRaise then
				rbx.Position = oldpos + UDim2.new(0, 0, 0, -ButtonRaise)
			end
			if ButtonScale then
				uiScale.Scale = ButtonScale
			end
			if ButtonDropColor then
				gradient.Color = ButtonDropColor
			end
			if ButtonImageColor then
				if rbx:IsA("ImageButton") then
					rbx.ImageColor3 = ButtonImageColor
					rbx.BackgroundColor3 = ButtonImageColor
				else
					rbx.BackgroundColor3 = ButtonImageColor
				end
			end
		end)
	end)
end

function module.stopButtonTween(rbx)
	if lastTweens then
		if enterTweenFinishedConnection then
			enterTweenFinishedConnection:Disconnect()
			enterTweenFinishedConnection = nil
		end
		if updateAppearanceConnection then
			updateAppearanceConnection:Disconnect()
			updateAppearanceConnection = nil
		end
		if lastTweens.Position then
			lastTweens.Position[1]:Cancel()
			rbx.Position = lastTweens.Position[2]
		end
		if lastTweens.Scale then
			lastTweens.Scale[2]:Destroy()
		end
		if lastTweens.Drop then
			lastTweens.Drop[2]:Destroy()
		end
		if lastTweens.ImageColor then
			if rbx:IsA("ImageButton") then
				lastTweens.ImageColor[1]:Cancel()
				rbx.ImageColor3 = lastTweens.ImageColor[2]
				rbx.BackgroundColor3 = lastTweens.ImageColor[3]
			else
				lastTweens.ImageColor[1]:Cancel()
				rbx.BackgroundColor3 = lastTweens.ImageColor[2]
			end
		end
		lastTweens = nil
	end
end

function module.DoButtonLeave(rbx)
	MouseIcon.UnSetIcon(ButtonIcon)
	
	module.stopButtonTween(rbx)
end

local function button(props)
	props.AutoButtonColor = false
	props.Active = true
	
	local oldClick = props[Roact.Event.MouseButton1Click]
	props[Roact.Event.MouseButton1Click] = function(rbx, ...)
		if Globals.ButtonUnderMouse == rbx then
			if oldClick then
				oldClick(rbx, ...)
			end
		end
	end
	
	local oldActivated = props[Roact.Event.Activated]
	props[Roact.Event.Activated] = function(rbx, ...)
		if Globals.ButtonUnderMouse == rbx then
			Audio.ParentedSound(Assets.Sounds.ButtonClick, 1):Play()
			
			if oldActivated then
				oldActivated(rbx, ...)
			end
		end
	end
	
	local oldMouseDown = props[Roact.Event.MouseButton1Down]
	props[Roact.Event.MouseButton1Down] = function(rbx, ...)
		if Globals.ButtonUnderMouse == rbx then
			module.stopButtonTween(rbx)
			if oldMouseDown then
				oldMouseDown(rbx, ...)
			end
		end
	end
	
	local oldClick2 = props[Roact.Event.MouseButton2Click]
	local oldEnter = props[Roact.Event.MouseEnter]
	props[Roact.Event.MouseEnter] = function(rbx, ...)
		Globals.UpdatedButtonUnderMouseEvent.Event:Wait()
		
		if Globals.ButtonUnderMouse == rbx then
			if oldEnter then
				oldEnter(rbx, ...)
			end
		end
	end
	
	props[Roact.Event.MouseButton2Click] = function(rbx, ...)
		if Globals.ButtonUnderMouse == rbx then
			if oldClick2 then
				oldClick2(rbx, ...)
			end
		end
	end
	
	props.BorderColor3 = props.BorderColor3 or Style.PrimaryFocusColor
	
	props.Size = UDim2.new(1,0,1,0)
	props.AnchorPoint = Vector2.new(0.5, 0.5)
	props.Position = UDim2.new(0.5,0,0.5,0)
	props.AspectRatio = nil
end

local function stdButton(props, type_)
	local containterProps = {
		BackgroundTransparency = 1,
		Position = props.Position,
		LayoutOrder = props.LayoutOrder,
		Size = props.Size,
		AnchorPoint = props.AnchorPoint,
	}
	
	local aspect = props.AspectRatio
	
	button(props)
	
	local idx = props.Name or 1
	
	if aspect then
		return Roact.createElement("Frame", containterProps, {
			[idx] = Roact.createElement(type_, props),
			[2] = Roact.createElement("UIAspectRatioConstraint", {
				AspectRatio = aspect.AspectRatio,
				AspectType = aspect.AspectType,
				DominantAxis = aspect.DominantAxis,
			})
		})
	else
		return Roact.createElement("Frame", containterProps, {
			Roact.createElement(type_, props),
		})
	end
end

function module.StdImageButton(props)
	return stdButton(props, "ImageButton")
end

function module.StdTextButton(props)
	return stdButton(props, "TextButton")
end

function module.Padding(props)
	local Pixels = props.Pixels or 1
	
	local pix = type(Pixels) == "table" and Pixels:map(function(v)
		return UDim.new(0,v)
	end) or UDim.new(0, Pixels)
	
	props.PaddingBottom = pix
	props.PaddingLeft = pix
	props.PaddingRight = pix
	props.PaddingTop = pix
	props.Pixels = nil
	return Roact.createElement("UIPadding", props)
end

function module.VerticleLayout( props )
	return Roact.createElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, props.Padding or 0),
		HorizontalAlignment = props.HorizontalAlignment or props.HA,
		VerticalAlignment = props.VerticalAlignment or props.VA,
	}, props[Roact.Children])
end


local function DisplayLocked(I, element, props)
	element:Children(
		I:Frame()
			:Size(1,0,1,0)
			:BackgroundColor3(Style.DisabledColor)
			:BackgroundTransparency(0.65)
			:Children(
				D(P(),I
				:ImageLabel()
					:Image(Assets.Images.Locked)
					:Size(1,-8,1,-8)
					:Center()
					:BackgroundTransparency(1)
				:Children(
					D(P(),I
					:UIAspectRatioConstraint()
						:AspectType(Enum.AspectType.ScaleWithParentSize)
						:DominantAxis(Enum.DominantAxis.Width)
						:AspectRatio(1)
					))
				)
			)
	)
end

local NormalScreenHeight = 1080
local ActualScreenSize

function module.ScalePixelSize(size)
	size *= ActualScreenSize / NormalScreenHeight
	return size
end

local ScalePixelSize = module.ScalePixelSize

local empty_table = { }
function module:__ui(G, i, p)
	I = i
	P = p

	-- This one inserts children into the props for you
	I:RegisterStdModifier("DisplayLocked", DisplayLocked)

	local GoldTextColor = Color3.new(0.627450, 0.486274, 0.023529)
	I:NewStdElement("GoldPriceTag", function(props)
		local tree = I:Frame()
			:Position_Raw(props.Position)
			:AnchorPoint_Raw(props.AnchorPoint)
			:Size(1,0,1,0)
			:BorderSizePixel(0)
			:ClipsDescendants(false)
			:BackgroundTransparency(1)
		:Children(
			I:ImageLabel(P()
				:Size(1, 0, 0.5, 0)
				:AnchorPoint(1, 0)
				:Position(1, 0, .5, 0)
				:Image(Assets.Images.Gold)
				:BackgroundTransparency(1)
				:ImageTransparency(0)
				:AspectRatioProp(1)
			),
			I:TextLabel()
				:Size(1, 0, 1, 0)
				:AnchorPoint(1, 0)
				:Position(1, 0, 0, 0)
				:Text(-props.Price)
				:TextColor3_Raw(GoldTextColor)
				:TextSize(I:ScaledTextSize(24))
				:TextXAlignment(Enum.TextXAlignment.Right)
				:TextYAlignment(Enum.TextYAlignment.Top)
				:Font(Style.LabelFont)
				:BackgroundTransparency(1)
		)

		return tree
	end)

	I:NewStdElement("VerticalSeperator", function(props)
		return
			I:Frame()
				:Size(1, 0, 0, 5)
				:BorderSizePixel(0)
				:BackgroundTransparency(1)
				:Position(props.Position)
				:AnchorPoint(props.AnchorPoint)
				:LayoutOrder(props.LayoutOrder)
			:Children(
				I:Frame(P()
					:BackgroundColor3_Raw(Style.ActiveTextColor)
					:Size(1, -8, 0, 1)
					:Center()
					:BorderSizePixel(0)
				)
			)
	end)
	
	I:NewStdElement("HorizontalSeperator", function(props)
		return
			I:Frame()
				:Size(0, 5, 1, 0)
				:BorderSizePixel(0)
				:BackgroundTransparency(1)
				:Position(props.Position)
				:AnchorPoint(props.AnchorPoint)
				:LayoutOrder(props.LayoutOrder)
			:Children(
				I:Frame(P()
					:BackgroundColor3_Raw(Style.ActiveTextColor)
					:Size(0, 1, 1, -8)
					:Center()
					:BorderSizePixel(0)
				)
			)
	end)
	
	I:NewStdElement("VisibleFrame", function(props)
		local aspect
		
		if props.AspectRatio then
			aspect = I:UIAspectRatioConstraint():AspectRatio(props.AspectRatio)
		end
		
		return I:Frame(P()
			:RoundCorners()
			:BorderSizePixel(0)
			:BackgroundColor3_Raw(props.BackgroundColor3 or props.Color or Style.SecondaryColor1)
			:Size_Raw(props.Size)
			:AnchorPoint_Raw(props.AnchorPoint)
			:Position_Raw(props.Position)
			:LayoutOrder(props.LayoutOrder)
			:ClipsDescendants(props.ClipsDescendants)
			:Border()
		):Children(
			I:Frame(P()
				:Invisible()
				:Inset(0, 4)
				:Center()
			):Children(
				I:Fragment(props.Children)
			),
			aspect
		)
	end)
	
	I:NewStdElement("VisibleScrollingFrame", function(props)
		local notAtEnd, updNotAtEnd = I:Binding(true)
		
		return I:Frame(P()
			:RoundCorners()
			:BorderSizePixel(0)
			:BackgroundColor3_Raw(props.BackgroundColor3 or props.Color or Style.SecondaryColor1)
			:Size_Raw(props.Size)
			:AnchorPoint_Raw(props.AnchorPoint)
			:Position_Raw(props.Position)
			:Border()
			:ClipsDescendants(true)
			:BackgroundTransparency(props.BackgroundTransparency)
		):Children(
			I:ScrollingFrame(P()
				:Invisible()
				:Inset(0, 4)
				:Center()
				:ScrollingDirection(Enum.ScrollingDirection.Y)
				:AutomaticCanvasSize(props.AutomaticSize or Enum.AutomaticSize.Y)
				:CanvasSize_Raw(props.CanvasSize or UDim2.new(0,0,0,0))
				:ScrollBarThickness(0)
				:ClipsDescendants(false)
				:Change("CanvasPosition", function(rbx)
					if not module.IsScrollBarAtEnd(rbx) then
						updNotAtEnd(true)
					else
						updNotAtEnd(false)
					end
				end)
			):Children(
				I:Fragment(props.Children)
			),
			I:Frame(P()
				:Size(1, 0, 0.1, 0)
				:JustifyBottom(0,0)
				:BorderSizePixel(0)
				:BackgroundColor3(1,1,1)
				:Visible(notAtEnd)
			):Children(
				I:UIGradient(P()
					:Rotation(-90)
					:Color_Raw(Style.SecondaryColor1:map(function(v)
						return ColorSequence.new(v)
					end))
					:Transparency(0, 1)
				)
			)
		)
	end)
	
	
	local function init_StatefulButton(self)
		self.HoveredOverlay = I:Tween()
		self.FocusedOverlay = I:Tween()
		self.PressedOverlay = I:Tween()
		
		self.UsePrimaryColor = self.props.UsePrimaryColor
		self.Focused = self.props.Focused
		self.id = self.props.ID
	end
	
	local function render_StatefulButton(self)
		local props = self.props
		local thirdColor = self.UsePrimaryColor and Style.PrimaryFocusColor or Style.ActiveTextColor
		
		P()
			:Size(1,4,1,4)
			:Center()
			:BorderSizePixel(0)
		
		if self.Focused then
			I:Name(self.Focused:map(function(v)
	
				if v == self.id then
					self.FocusedOverlay:skip():skip():spring(12, 9, 2)
				else
					self.FocusedOverlay:skip():skip():spring(0, 4, 2)
				end
				
				return ""
			end))
		end
		
		I:BackgroundColor3_Raw(thirdColor)
		:BackgroundTransparency(Roact.joinBindings({self.HoveredOverlay, self.PressedOverlay, self.FocusedOverlay}):map(function(v)
			return 1 - (v[1] + v[2] + v[3]) / 100
		end))
		
		:RoundCorners()
		
		local overlay = I:Frame(D())
		
		P()
			:Size_Raw(props.Size)
			:AnchorPoint_Raw(props.AnchorPoint)
			:Position_Raw(props.Position)
			:AutoButtonColor(false)
			:Name(props.Name)
			:LayoutOrder(props.LayoutOrder)
			:BackgroundTransparency(props.BackgroundTransparency)
		
		if props._type == "Image" then
			I:Image(props.Image)
			:ImageTransparency(props.ImageTransparency)
		else
			I:Text(props.Text)
			:TextColor3_Raw(thirdColor)
			:TextTransparency(props.TextTransparency)
			:TextSize(props.TextSize)
			:Font(props.Font)
		end
		
		I:MouseEnter(function(rbx)
			self.HoveredOverlay:skip():spring(5, 9, 2)
		end)
		:MouseLeave(function(rbx)
			self.HoveredOverlay:skip():spring(0, 9, 2)
		end)
		
		:MouseButton1Down(function(rbx)
			self.PressedOverlay:skip():spring(7, 9, 2)
		end)
		:MouseButton1Up(function(rbx)
			self.PressedOverlay:skip():spring(0, 4, 2)
		end)
		
		:Activated(function(rbx)
			if not self.Focused then
				self.FocusedOverlay:skip():skip():instant(12):spring(0, 6, 2)
			end
			props.Activated(rbx)
		end)
		
		:Change("AbsoluteSize", props[Roact.Change.AbsoluteSize])
		:Change("Parent", props[Roact.Change.Parent])
		:Ref(props[Roact.Ref])
		
		:BackgroundColor3_Raw(Style.SecondaryColor1)
		
		:Border(2, Roact.joinBindings({self.FocusedOverlay, Style.SecondaryColor2, thirdColor}):map(function(v)
			return v[2]:Lerp(v[3], v[1]/12)
		end))
		:RoundCorners()
		:Modal(props.Modal)
		
		if props._type == "Image" then
			return I:ImageButton(D()):Children(
				I:Fragment(props.Children),
				overlay
			)
		else
			return I:TextButton(D()):Children(
				I:Fragment(props.Children),
				overlay
			)
		end
	end
	
	local StatefulButton = I:Stateful("Stateful Button", I
		:Init(init_StatefulButton)
		:Render(render_StatefulButton)
	)
	
	I:NewStdElement("TextButton", function(props)
		props._type = "Text"
		return Roact.createElement(StatefulButton, props)
	end)
	
	I:NewStdElement("ImageButton", function(props)
		props._type = "Image"
		return Roact.createElement(StatefulButton, props)
	end)
	
	
	
	--This is more suitable when the element may change its locked status without re-rendering
	I:NewStdElement("DisplayLocked", function(props)
		local tree = I:Frame(P()
			:Size(1,0,1,0)
			:BackgroundColor3(Style.DisabledColor)
			:BackgroundTransparency(props.Locked:map(function(locked)
				return if locked then 0.55 else 1
			end))
		):Children(
			I:ImageLabel(P()
				:Image(Assets.Images.Lock)
				:Size(1,-8,1,-8)
				:Center()
				:BackgroundTransparency(1)
				:ScaleType(Enum.ScaleType.Fit)
				:ImageTransparency(props.Locked:map(function(locked)
					return if locked then 0.2 else 1
				end))
			)
		)

		return tree
	end)

	I:NewStdElement("SpawnPointsIcon", 
		I:ImageLabel(P()
			:Image(Assets.Images.SpawnPoints)
			:BackgroundTransparency(1)
			:Children(
				I:UIAspectRatioConstraint(P()
					:AspectRatio(1)
					:AspectType(Enum.AspectType.FitWithinMaxSize)
				)
			)
		)
	)
	
	I:NewStdElement("GoldIcon", 
		I:ImageLabel(P()
			:Image(Assets.Images.Gold)
			:BackgroundTransparency(1)
			:Children(
				I:UIAspectRatioConstraint(P()
					:AspectRatio(1)
					:AspectType(Enum.AspectType.FitWithinMaxSize)
				)
			)
		)
	)

	I:NewStdElement("ScrollingFrame",
		I:ScrollingFrame(P()
			:CanvasSize(0, 0, 0, 0)
			:BackgroundColor3_Raw(Style.SecondaryColor1)
			:BorderSizePixel(0)
			:ScrollBarThickness(Style.ScrollBarSize)
			:VerticalScrollBarInset(Enum.ScrollBarInset.ScrollBar)
			:ScrollingDirection(Enum.ScrollingDirection.Y)
			:BottomImage("")
			:TopImage("")
			:AutomaticCanvasSize(Enum.AutomaticSize.Y)
		)
	)

	I:NewStdElement("ContainerFrame",
		I:Frame(P()
			:Size(1,0,1,0)
			:BackgroundTransparency(1)
			:BorderSizePixel(0)
		)
	)

	I:NewStdElement("VisibleContainerFrame",
		I:Frame(P()
			:Size(1,0,1,0)
			:BackgroundColor3_Raw(Style.SecondaryColor1)
			:BorderSizePixel(0)
		)
	)

	I:NewStdElement("VerticalLayout",
		I:UIListLayout(P()
			:FillDirection(Enum.FillDirection.Vertical)
			:SortOrder(Enum.SortOrder.LayoutOrder)
			:Padding(0, 2)
		)
	)

    I:NewStdElement("HorizontalLayout",
		I:UIListLayout(P()
			:FillDirection(Enum.FillDirection.Horizontal)
			:SortOrder(Enum.SortOrder.LayoutOrder)
			:Padding(0, 2)
		)
	)
end

function module:__init(G)
	Globals = G
	Style = G.Load("Style")
	Roact = G.Load("Roact")
	Assets = G.Load("Assets")
	String = G.Load("Strings")
	Audio = G.Load("Audio")

	RoactEvents = Roact.Event

	-- The rest is just client stuff
	if G.CONTEXT == "SERVER" then
		return
	end
	
	MouseIcon = Globals.Load("MouseIcon")

	local BaseInterface = game.Players.LocalPlayer.PlayerGui:WaitForChild("BaseInterface_NoInset")
	ActualScreenSize = BaseInterface.AbsoluteSize.Y

	BaseInterface.Changed:Connect(function(property)
		if property == "AbsoluteSize" then
			print(BaseInterface.AbsoluteSize.Y)
			ActualScreenSize = BaseInterface.AbsoluteSize.Y
		end
	end)

	--[[ module.ServerTime, updServerTime = Roact.createBinding(0)
	module.ServerTime = module.ServerTime:map(function()
		return String.FormatTime("%D:%H2:%M2:%S2", Globals.ServerTime + workspace.DistributedGameTime, 4, nil)
	end) ]]

	--[[ module.PlayTime, updPlayTime = Roact.createBinding(0)
	module.PlayTime = module.PlayTime:map(function()
		return String.FormatTime("%D:%H2:%M2:%S2", workspace.DistributedGameTime, 4, nil)
	end) ]]

	--[[ module.Ping, module.UpdPing = Roact.createBinding(0)
	module.Ping = module.Ping:map(function(v)
		return tostring(math.round(v * 1000)) .. "ms"
	end) ]]

	--[[ module.FPS, module.UpdFPS = Roact.createBinding(0)
	module.FPS = module.FPS:map(function(v)
		return tostring(math.round(1/v)) .. "fps"
	end) ]]

	module.PremiumSubscription, module.UpdPremiumSubscription = Roact.createBinding(plr.MembershipType == Enum.MembershipType.Premium)
	rightclickBind = Roact.createBinding(Enum.UserInputType.MouseButton2)

	coroutine.wrap(function()
		while true do
			task.wait(1)
			--updTime(0)
			--updServerTime(0)
			--updPlayTime(0)
			if module.PremiumSubscription:getValue() ~= (plr.MembershipType == Enum.MembershipType.Premium) then
				module.UpdPremiumSubscription(plr.MembershipType == Enum.MembershipType.Premium)
			end
		end
	end)()

	task.spawn(function()
		while true do
			local dt = task.wait(0.1)
			if TeamFireLimit > 0 then
				TeamFireLimit = math.max(0, TeamFireLimit - dt)
			end
		end
	end)
end

return module
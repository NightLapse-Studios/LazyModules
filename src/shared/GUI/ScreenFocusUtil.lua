local Game
local Assets
local Style
local Flipper
local Roact = _G.Game.PreLoad(game.ReplicatedFirst.Modules.Roact)
local GUI

local D,A,I

local mod = { }

local RunService = game:GetService("RunService")
local GUIService = game:GetService("GuiService")
local TextService = game:GetService("TextService")

local FocusInt = Roact.Component:extend("FocusInterface")

local MaskedTransparency = 0.4
local MaskedColor = Color3.new(0.070588, 0.121568, 0.160784)
local Mouse = game.Players.LocalPlayer:GetMouse()
local InsetSize = GUIService:GetGuiInset()

local TextLabelInTween

local function GetScreenSize()
	screen_size = Vector2.new(Mouse.ViewSizeX + InsetSize.X, Mouse.ViewSizeY + InsetSize.Y)
end

function mod.TextLabel(props)
	local text_size = props.TextSize or 32
	local font = props.Font or Enum.Font.SourceSans

	local end_size = TextService:GetTextSize(props.Text, text_size, font, Vector2.new(1e10, 1e10))

	return Roact.createElement("Frame", {
		ZIndex = 100001,
		BackgroundTransparency = 1,
		Position = props.Position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 0, 1, 0),
	}, {
		Roact.createElement("TextButton", {
			Active = true,
			Font = font,
			ZIndex = 100000,
			RichText = true,
			Text = props.Text,
			TextScaled = true,
			TextStrokeTransparency = 0.2,
			TextStrokeColor3 = Style.DarkTextColor,
			TextColor3 = Style.ActiveTextColor,
			Size = TextLabelInTween:map(function(v)
				return UDim2.new(0, end_size.X * v, 0, end_size.Y * v)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			BackgroundTransparency = 1,
			[Roact.Event.Activated] = function()
				mod.NextPhase()
			end
		}),
		props.children
	})
end

--[[ function mod.ScreenMask()
	return Roact.createFragment({
		Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = MaskedColor,
			BackgroundTransparency = MaskedTransparency
		})
	})
end ]]

function mod.AreaFocus(udimA: UDim2, udimB: UDim2)
	GetScreenSize()
	--To cut down on the number of animated values, offsets are converted into the scale portion of the UDims
	local normalized_udimA = UDim2.new(udimA.X.Scale + udimA.X.Offset / screen_size.X, 0, udimA.Y.Scale + udimA.Y.Offset / screen_size.Y, 0)
	local normalized_udimB = UDim2.new(udimB.X.Scale + udimB.X.Offset / screen_size.X, 0, udimB.Y.Scale + udimB.Y.Offset / screen_size.Y, 0)

	if FocusInt.FocusingUDimA.X.Scale ~= udimA.X.Scale or FocusInt.FocusingUDimA.Y.Scale ~= udimA.Y.Scale
		or FocusInt.FocusingUDimB.X.Scale ~= udimB.X.Scale or FocusInt.FocusingUDimB.Y.Scale ~= udimB.Y.Scale then
			--Don't animate if we aren't actually moving focus
			local opts = {
				frequency = 1.8
			}
			FocusInt.FocusBBAXmotor:setGoal(Flipper.Spring.new(normalized_udimA.X.Scale, opts))
			FocusInt.FocusBBAYmotor:setGoal(Flipper.Spring.new(normalized_udimA.Y.Scale, opts))
			FocusInt.FocusBBBXmotor:setGoal(Flipper.Spring.new(normalized_udimB.X.Scale, opts))
			FocusInt.FocusBBBYmotor:setGoal(Flipper.Spring.new(normalized_udimB.Y.Scale, opts))
	end
	FocusInt.FocusingUDimA, FocusInt.FocusingUDimB = normalized_udimA, normalized_udimB

	return Roact.createFragment({
		--Top bar
		Roact.createElement("Frame", {
			Active = true,
			Size = FocusInt.FocusBBAYbinding:map(function(value)
				return UDim2.new(1, 0, value, 0)
			end),
			BackgroundColor3 = MaskedColor,
			BackgroundTransparency = MaskedTransparency,
			BorderSizePixel = 0
		}),
		--Bottom bar
		Roact.createElement("Frame", {
			Active = true,
			Size = FocusInt.FocusBBAYbinding:map(function(value)
				return UDim2.new(1, 0, 1 - value, 0)
			end),
			BackgroundColor3 = MaskedColor,
			BackgroundTransparency = MaskedTransparency,
			Position = FocusInt.FocusBBBYbinding:map(function(value)
				return UDim2.new(0, 0, value, 0)
			end),
			BorderSizePixel = 0
		}),
		--Left block
		Roact.createElement("Frame", {
			Active = true,
			Size = Roact.joinBindings({FocusInt.FocusBBAXbinding, FocusInt.FocusBBBYbinding, FocusInt.FocusBBAYbinding}):map(function(values)
				return UDim2.new(values[1], 0, values[2] - values[3], 0)
			end),
			BackgroundColor3 = MaskedColor,
			BackgroundTransparency = MaskedTransparency,
			Position = FocusInt.FocusBBAYbinding:map(function(value)
				return UDim2.new(0, 0, value, 0)
			end),
			BorderSizePixel = 0
		}),
		--Right block
		Roact.createElement("Frame", {
			Active = true,
			Size = Roact.joinBindings({FocusInt.FocusBBBXbinding, FocusInt.FocusBBBYbinding, FocusInt.FocusBBAYbinding}):map(function(values)
				return UDim2.new(1 - values[1], 0, values[2] - values[3], 0)
			end),
			BackgroundColor3 = MaskedColor,
			BackgroundTransparency = MaskedTransparency,
			Position = Roact.joinBindings({FocusInt.FocusBBBXbinding, FocusInt.FocusBBAYbinding}):map(function(values)
				return UDim2.new(values[1], 0, values[2], 0)
			end),
			BorderSizePixel = 0
		}),
		--Frame for border
		Roact.createElement("ImageButton", {
			Size = Roact.joinBindings({FocusInt.FocusBBAXbinding, FocusInt.FocusBBAYbinding, FocusInt.FocusBBBXbinding, FocusInt.FocusBBBYbinding}):map(function(values)
				return UDim2.new(values[3] - values[1], 0, values[4] - values[2], 0)
			end),
			Position = Roact.joinBindings({FocusInt.FocusBBAXbinding, FocusInt.FocusBBAYbinding}):map(function(values)
				return UDim2.new(values[1], 0, values[2], 0)
			end),
			Image = Assets.Images.BorderOnly9Slice,
			ResampleMode = Enum.ResamplerMode.Pixelated,
			SliceCenter = Rect.new(Vector2.new(1,1), Vector2.new(2,2)),
			SliceScale = 2,
			ImageColor3 = Color3.new(0.047058, 0.529411, 0.545098),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Slice,
			Active = true,
			AutoButtonColor = false,
			[Roact.Event.Activated] = function()
				mod.NextPhase()
			end
		})
	})
end

local SetState

function FocusInt:init()
	FocusInt.HasActiveTutorial = false
	FocusInt.phase = -1
	FocusInt.WaitingForInput = false
	FocusInt.CurrentTutorial = false

	FocusInt.FocusingUDimA = UDim2.new(0,0,0,0)
	FocusInt.FocusingUDimB = UDim2.new(0,0,0,0)

	FocusInt.FocusBBAXmotor = Flipper.SingleMotor.new(0)
	FocusInt.FocusBBAYmotor = Flipper.SingleMotor.new(1)
	FocusInt.FocusBBBXmotor = Flipper.SingleMotor.new(0)
	FocusInt.FocusBBBYmotor = Flipper.SingleMotor.new(1)

	FocusInt.FocusBBAXbinding, FocusInt.SetFocusBBAXbinding = Roact.createBinding( FocusInt.FocusBBAXmotor:getValue() )
	FocusInt.FocusBBAYbinding, FocusInt.SetFocusBBAYbinding = Roact.createBinding( FocusInt.FocusBBAYmotor:getValue() )
	FocusInt.FocusBBBXbinding, FocusInt.SetFocusBBBXbinding = Roact.createBinding( FocusInt.FocusBBBXmotor:getValue() )
	FocusInt.FocusBBBYbinding, FocusInt.SetFocusBBBYbinding = Roact.createBinding( FocusInt.FocusBBBYmotor:getValue() )

	FocusInt.FocusBBAXmotor:onStep(FocusInt.SetFocusBBAXbinding)
	FocusInt.FocusBBAYmotor:onStep(FocusInt.SetFocusBBAYbinding)
	FocusInt.FocusBBBXmotor:onStep(FocusInt.SetFocusBBBXbinding)
	FocusInt.FocusBBBYmotor:onStep(FocusInt.SetFocusBBBYbinding)

	SetState = function(s) self:setState(s) end
	SetState({Funcs = false, phase = -1})
end

function FocusInt:render(props)
	local state = self.state
	local phase = state.phase

	if not state.Funcs then
		return false
	end

	if phase == -1 then
		return false
	end

	if phase > #state.Funcs then
		return false
	end

	local func = state.Funcs[phase]
	local tree = I:StdElement("ContainerFrame", D(A(), I
		:Size(1, 0, 1, 0)
		:Children(
			I:Fragment(func())
		)
	))

	TextLabelInTween:skip():instant(0):spring(1, 3, 0.5)

	return tree
end

function FocusInt:didUpdate()
	if FocusInt.JustEndedTutorial == true then
		FocusInt.JustEndedTutorial = false
		self:setState({})
	end
end

function mod.RunFocusList(...: (number)->any)
	FocusInt.phase = 1
	SetState({
		Funcs = { ... },
		phase = FocusInt.phase
	})
end

function mod.Stop()
	FocusInt.phase = -1
	SetState({
		Funcs = false,
		phase = FocusInt.phase
	})
end

function mod.NextPhase()
	FocusInt.phase += 1
	SetState({
		phase = FocusInt.phase
	})
end

function mod:__init(G)
	Game = G
	Assets = G.Load("Assets")
	Style = G.Load("Style")
	Style = G.Load("Style")
	Flipper = G.Load("Flipper")
	Roact = G.Load("Roact")
	GUI = G.Load("GUI")
end

function mod:__ui(G,i,a,d)
	I,A,D = i,a,d

	TextLabelInTween = I:Tween(0)

	Roact.mount(Roact.createElement(FocusInt), game.Players.LocalPlayer.PlayerGui.ScreenHighlights)
end

return mod
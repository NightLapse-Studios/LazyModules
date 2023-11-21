
local Roact = _G.Game.PreLoad(game.ReplicatedFirst.Modules.Roact)

--[[
	by saying :client(), the setting will be only visible in studio
	]]

local Style = {
	UpdateBindings = {}
}

local function make_binding(k,v)
	Style[k], Style.UpdateBindings[k] = Roact.createBinding(v)
end

-- the color you use to draw attention to something that the user can usually interact with (buttons).)
make_binding("PrimaryFocusColor", Color3.fromHSV(0.030434, 0.692771, 0.650980))
make_binding("SpecialFocusedColor", Color3.new(0.847059, 0.803922, 0.400000))
make_binding("SpecialUnfocusedColor", Color3.new(0.458824, 0.427451, 0.137255))
make_binding("DeleteColor", Color3.fromHSV(0.0, 0.748858, 0.858823))
make_binding("GrowColor", Color3.fromHSV(0.328252, 0.748858, 0.858823))
make_binding("WarnColor", Color3.fromHSV(0.177845, 0.748858, 0.858823))

make_binding("SecondaryColor1", Color3.new(0.09, 0.09, 0.095))
make_binding("SecondaryColor2", Color3.new(0.13, 0.13, 0.135))
make_binding("SecondaryColor3", Color3.new(0.17, 0.17, 0.175))
make_binding("SecondaryColor4", Color3.new(0.18, 0.18, 0.185))
make_binding("ActiveTextColor", Color3.fromRGB(203, 203, 221))
make_binding("DarkTextColor", Color3.fromRGB(30, 30, 30))
make_binding("TextCursorColor", Color3.fromRGB(255, 255, 255))
make_binding("WindowBorderColor", Color3.fromRGB(0, 0, 0))
make_binding("DisabledTransparency", 0.4)
make_binding("BasicBackgroundTransparency", 0.25)
make_binding("ScrollBarSize", 5)
make_binding("DisabledColor", Color3.fromRGB(90, 28, 28))
make_binding("EnabledColor", Color3.new(0.152941, 0.541176, 0.184313))

Style.FieldSelectorRed = Color3.fromRGB(134, 45, 17)
Style.FieldSelectorGreen = Color3.fromRGB(25, 130, 69)


Style.LabelFont = Enum.Font.Fantasy
Style.InformationFont = Enum.Font.SourceSansLight


--[[ Big header sizes ]]
Style.BigHeaderHeight = 33
Style.BigHeaderTextSize = 21

--[[ Normal header sizes ]]
Style.StdHeaderHeight = 27
Style.StdHeaderTextSize = 17

--[[ Small header sizes ]]


--[[ Body sizes ]]
Style.StdBodyTextSize = 13
Style.StdBodyHeight = 15

--[[ Dialogues ]]
Style.DialogueSpacerHeight = 9
Style.DialogueSegmentHeight = 20
Style.DialogueHeaderHeight = 36
Style.DialoguePadding = 6
Style.DialogueLineAbovePadding = 2
Style.DialogueTextBoxWidth = 120
Style.DialogueColorIconWidth = 50

--[[CheckBox]]
Style.CheckBoxSize = 12

--[[DropDown]]
Style.DropDownHeight_thin = 17
Style.DropDownSelectorWidth = 75
Style.MaxDropDownSelectorHeight = 120

--[[Slider]]
Style.SliderWidth = 100
Style.SliderHeight = 5
Style.SliderHandleSize = UDim2.new(0, 5, 0, 10)
Style.SliderTextBoxWidth = 40
Style.SliderTextBoxExpandWidth = 140

local LogBadRefs = true
if LogBadRefs then
	setmetatable(Style, {__index = function(tbl, key)
		if (rawget(tbl, key) == nil) then
			warn(string.format("Bad reference to style sheet [ %s ]", key))
		end
	end})
end

return Style
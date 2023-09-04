
--[[
	Options: {[name] = number}-- like an enum table. number is used to decider order.
	InitOptionName
	Callback(optionName, number)
]]

local UserInputService = game:GetService("UserInputService")
local Modules = game.ReplicatedFirst.Modules

local DropDownContainer = _G.Game.PreLoad(Modules.GUI.DropDownContainer)
local GUI = _G.Game.PreLoad(Modules.GUI)
local Roact = _G.Game.PreLoad(Modules.Roact)
local Style

local interface = Roact.Component:extend("DropDownSelector")

local opened = setmetatable({}, {__mode = "k"})

function interface:init()
	local idx = nil
	for i,v in pairs(self.props.Options) do
		if i == self.props.InitOptionName then
			idx = v
			break
		end
	end
	self.TitleBinding, self.UpdTitleBinding = Roact.createBinding(self.props.DisplayNames and self.props.DisplayNames[idx] or self.props.InitOptionName)
	
	self.List = DropDownContainer.newList(self.TitleBinding, 0, 90, function()
		if self.props.OnToggle then
			self.props.OnToggle()
		end
		self:setState({})
	end)
end

--optionsNames, initOptionName, callback
function interface:render()
	local list = self.List
	local props = self.props
	
	if list.IsOpen then
		opened[self] = true
		local optionsBuild = {}
		local num = 0
		
		for optionName, index in pairs(props.Options) do
			if (not props.DoHideCallback) or not props.DoHideCallback(optionName, index) then
				local children
				if props.AddChildrenToOptions then
					children = props.AddChildrenToOptions(optionName, index)
				end
				
				num += 1
				
				local displayName = props.DisplayNames and props.DisplayNames[index] or optionName
				
				optionsBuild[index] = Roact.createElement(GUI.StdTextButton, {
					Text = displayName,
					Font = Style.InformationFont,
					TextSize = 11,
					TextColor3 = props.Colors and props.Colors[index] or Style.ActiveTextColor,
					
					BackgroundColor3 = Style.SecondaryColor1,
					BorderSizePixel = 0,
					
					Size = UDim2.new(1, 0, 0, Style.DropDownHeight_thin - 3),
					LayoutOrder = index,
					
					[Roact.Attribute.ButtonDropColor] = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.741176, 0.741176, 0.741176)),
					
					[Roact.Event.MouseButton1Click] = function()
						local doCancel = props.Callback(optionName, index)
						if not doCancel then
							list:ToggleList(false)
							if self.TitleBinding:getValue() ~= displayName then
								self.UpdTitleBinding(displayName)
							end
						end
					end
				}, children)
			end
		end
		
		local container = list:render()
		
		local size = math.min((Style.DropDownHeight_thin - 3) * num, Style.MaxDropDownSelectorHeight)
		
		return Roact.createElement("Frame", {
			Size = UDim2.new(0, Style.DropDownSelectorWidth, 0, Style.DropDownHeight_thin),
			Position = props.Position,
			AnchorPoint = props.AnchorPoint,
			BackgroundTransparency = 1,
		}, {
			container,
			Roact.createElement("Frame", {
				Position = UDim2.new(0,0,0, Style.DropDownHeight_thin + 1),
				Size = UDim2.new(0, Style.DropDownSelectorWidth, 0, size),
				BackgroundTransparency = 1,
				ZIndex = 4,
				[Roact.Event.MouseEnter] = function()
					self.KeepOpen = true
				end,
				[Roact.Event.MouseLeave] = function()
					self.KeepOpen = false
				end,
			}, {
				Roact.createElement(GUI.StandardVerticalScrollingFrame, {
					Padding = 0,
					Size = UDim2.new(0, Style.DropDownSelectorWidth, 1, 0),
					BorderSizePixel = 1,
					BorderColor3 = Style.WindowBorderColor,
				}, optionsBuild)
			}),
		})
	else
		opened[self] = nil
		local container = list:render()
		
		return Roact.createElement("Frame", {
			Size = UDim2.new(0, Style.DropDownSelectorWidth, 0, Style.DropDownHeight_thin),
			Position = props.Position,
			AnchorPoint = props.AnchorPoint,
			BackgroundTransparency = 1,
			ZIndex = 100,
		}, container)
	end
end

local function closeAll(pos)
	for self, _ in pairs(opened)do
		
		if self.List.IsOpen then
			if not self.KeepOpen then
				
				self.List:ToggleList(false)
			end
		else
			opened[self] = nil
		end
	end
end

UserInputService.InputBegan:Connect(function(obj)
	if obj.UserInputType == Enum.UserInputType.MouseButton1 or obj.UserInputType == Enum.UserInputType.MouseButton2 or obj.UserInputType == Enum.UserInputType.Touch then
		closeAll(obj.Position)
	end
end)

function interface:__init(G)
	Style = G.Load("Style")
end

return interface
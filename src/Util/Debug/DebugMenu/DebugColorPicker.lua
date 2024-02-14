local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ColorPicker = {}

local ColorWheel = "rbxassetid://7151805781"
local CircleRing = "rbxassetid://7151851820"

local grabbed = nil

function ColorPicker:__ui(G, I, P)
	local Math = G.Load("Math")
	local Vectors = G.Load("Vectors")
	
	local function init(self)
		self.WheelRef = I:CreateRef()
		self.LastNon0Hue = self.props.Color:getValue():ToHSV()
		self.UpdateColor = function(color)
			self.props.Color.update(color)
			self.props.Callback(color)
		end
	end
	
	local function render(self)
		local color = self.props.Color
		local updateColor = self.UpdateColor
		
		local colorComponents = color:map(function(v: Color3)
			-- n is for normalized
			
			local nh, ns, nv = v:ToHSV()
			
			if nh ~= 0 then
				self.LastNon0Hue = nh
			end
			
			local nr, ng, nb = v.R, v.G, v.B
			
			local hex = v:ToHex()
			
			return nh, ns, nv,  nr, ng, nb,  hex
		end)
		
		local List = {}
		
		local function createStrip(title, element)
			table.insert(List, I:Frame(P()
				:LayoutOrder(#List)
				:Size(1, 0, 0.1, 0)
				:Invisible()
			):Children(
				I:TextLabel(P()
					:JustifyLeft(0,0)
					:Font("Roboto")
					:Text(title)
					:TextSize(I:ScaledTextSize("DebugColorPickerSliderTitle"))
					:TextColor3(1,1,1)
					:Size(0.1, 0, 1, 0)
					:TextXAlignment("Left")
					:TextYAlignment("Center")
				),
				
				I:Frame(P()
					:JustifyRight(0,0)
					:Size(0.85, 0, 1, 0)
					:Invisible()
				):Children(
					element
				)
			)) 
		end
		
		local function createSlider(title, componentIndex, callback)
			createStrip(title, I:DebugSlider(P()
				:Prop("Min", 0)
				:Prop("Max", 1)
				:Prop("Increment", 0.001)
				:Prop("UseThisBinding", colorComponents:map(function(...)
					local comps = {...}
					return comps[componentIndex]
				end))
				:Prop("Callback", callback)
				
				:BackgroundColor3(1, 1, 1)
				
				:Prop("Children", {
					I:UIGradient(P()
						:Color(colorComponents:map(function(...)
							local comps = {...}
							
							local C1, C2
							
							if componentIndex == 1 then
								C1 = Color3.fromHSV(0, comps[2], comps[3])
								C2 = Color3.fromHSV(1, comps[2], comps[3])
							elseif componentIndex == 2 then
								C1 = Color3.fromHSV(comps[1], 0, comps[3])
								C2 = Color3.fromHSV(comps[1], 1, comps[3])
							elseif componentIndex == 3 then
								C1 = Color3.fromHSV(comps[1], comps[2], 0)
								C2 = Color3.fromHSV(comps[1], comps[2], 1)
							elseif componentIndex == 4 then
								C1 = Color3.new(0, comps[5], comps[6])
								C2 = Color3.new(1, comps[5], comps[6])
							elseif componentIndex == 5 then
								C1 = Color3.new(comps[4], 0, comps[6])
								C2 = Color3.new(comps[4], 1, comps[6])
							elseif componentIndex == 6 then
								C1 = Color3.new(comps[4], comps[5], 0)
								C2 = Color3.new(comps[4], comps[5], 1)
							end
							
							return ColorSequence.new(C1, C2)
						end))
					)
				})
			))
		end
		
		createSlider("H", 1, function(updatedValue)
			local nh, ns, nv,  nr, ng, nb,  hex = colorComponents:getValue()
			local newColor = Color3.fromHSV(updatedValue, ns, nv)
			self.LastNon0Hue = updatedValue
			updateColor(newColor)
		end)
		
		createSlider("S", 2, function(updatedValue)
			local nh, ns, nv,  nr, ng, nb,  hex = colorComponents:getValue()
			updateColor(Color3.fromHSV(self.LastNon0Hue, updatedValue, nv))
		end)
		
		createSlider("V", 3, function(updatedValue)
			local nh, ns, nv,  nr, ng, nb,  hex = colorComponents:getValue()
			updateColor(Color3.fromHSV(self.LastNon0Hue, ns, updatedValue))
		end)
		
		createSlider("R", 4, function(updatedValue)
			local nh, ns, nv,  nr, ng, nb,  hex = colorComponents:getValue()
			local newColor = Color3.new(updatedValue, ng, nb)
			self.LastNon0Hue = newColor:ToHSV()
			updateColor(newColor)
		end)
		
		createSlider("G", 5, function(updatedValue)
			local nh, ns, nv,  nr, ng, nb,  hex = colorComponents:getValue()
			local newColor = Color3.new(nr, updatedValue, nb)
			self.LastNon0Hue = newColor:ToHSV()
			updateColor(newColor)
		end)
		
		createSlider("B", 6, function(updatedValue)
			local nh, ns, nv,  nr, ng, nb,  hex = colorComponents:getValue()
			local newColor = Color3.new(nr, ng, updatedValue)
			self.LastNon0Hue = newColor:ToHSV()
			updateColor(newColor)
		end)
		
		createStrip("HEX", I:DebugTextBox(P()
			:Prop("TextBinding", colorComponents:map(function(nh, ns, nv,  nr, ng, nb,  hex)
				return hex
			end))
			:Prop("Min", 6)
			:Prop("Max", 6)
			:Prop("Verify", function(value)
				local suc, err = pcall(function()
					Color3.fromHex(value)
				end)
				
				return suc
			end)
			:Prop("Callback", function(value)
				local newColor = Color3.fromHex(value)
				updateColor(newColor)
			end)
		))
		
		return I:Frame(P()
			:Size(1, 0, 1, 0)
			:Invisible()
			:AspectRatioProp(0.5)
		):Children(
			I:ImageButton(P()
				:AutoButtonColor(false)
				:AspectRatioProp(1)
				:Size(0.9, 0, 1, 0)
				:JustifyTop(0.05, 0)
				:Image(ColorWheel)
				:Invisible()
				:Ref(self.WheelRef)
				
				:ImageColor3(colorComponents:map(function(nh, ns, nv,  nr, ng, nb,  hex)
					return Color3.new(nv, nv, nv)
				end))
				
				:MouseButton1Down(function()
					grabbed = self
				end)
			):Children(
				I:ImageButton(P()
					:AutoButtonColor(false)
					:Size(0, 20, 0, 20)
					:Image(CircleRing)
					:Invisible()
					
					:AnchorPoint(0.5, 0.5)
					:Position(colorComponents:map(function(nh, ns, nv,  nr, ng, nb,  hex)
						local x, y = Vectors.XYOnCircle(0,0, ns/2, math.pi/2 - self.LastNon0Hue * math.pi * 2)

						return UDim2.new(0.5 + x, 0, 0.5 - y, 0)
					end))
					
					:MouseButton1Down(function()
						grabbed = self
					end)
				)
			),
			
			I:Frame(P()
				:Position(0, 0, 0.5, 0)
				:Size(0.9, 0, 0.45, 0)
				:Invisible()
			):Children(
				I:UIListLayout(P()
					:Padding(0.01, 0)
					:FillDirection("Vertical")
					:HorizontalAlignment("Center")
					:SortOrder("LayoutOrder")
					:VerticalAlignment("Top")
				),
				
				I:Fragment(List)
			)
		)
	end
	
	I:Stateful(P()
		:Name("DebugColorPicker")
		:Init(init)
		:Render(render)
	)
	
	RunService.RenderStepped:Connect(function()
		if grabbed then
			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				grabbed = nil
			else
				local wheel = self.WheelRef:getValue()
				if not wheel then
					grabbed = nil
				else
					local center = wheel.AbsolutePosition + wheel.AbsoluteSize/2
					local mousePosition = UserInputService:GetMouseLocation()
					
					local delta = center - mousePosition
					
					local s = math.min(delta.Magnitude, 1)
					local angle = math.atan2(-delta.X, delta.Y)
					local h = angle % (math.pi * 2) / (math.pi * 2)

					local _, _, v = grabbed.props.Color:getValue():ToHSV()
					
					local color = Color3.fromHSV(h, s, v)
					
					grabbed.UpdateColor(color)
				end
			end
		end
	end)
end

return ColorPicker
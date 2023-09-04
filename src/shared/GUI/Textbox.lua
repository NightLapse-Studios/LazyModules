
--[[
	Use this to request Text Input that is not Chat like. If input text did not pass verification, it is reset to the last valid text.
	
	Init-- the initial value of the textBox.
	
	IsNumber -- will only pass if the input passed the ExpressionParser.
	Increment -- Increments to round the number to. (1, 0.1, 5, etc.)
	
	-- verifies charcount for strings, rounds the value for numbers.
	Min
	Max
	
	-- should error if it did not pass the check, otherwise can optionally return a new value to use. Called after preset verifications (min, max)
	Verify
	
	-- called when the input after the FocusLost Event has passed all the checks.
	Callback
]]

local Style
local Roact = require(game.ReplicatedFirst.Modules.Roact)
local GUI = require(game.ReplicatedFirst.Modules.GUI)
local ExpressionParser = require(game.ReplicatedFirst.Modules.ExpressionParser)
local Math = require(game.ReplicatedFirst.Modules.Math)

local component = Roact.Component:extend("TextBox")

function component:init()
	self.LastText = self.props.Init
end

function component:render()
	local props = self.props
	
	local oldChange, oldLost = props[Roact.Change.Text], props[Roact.Event.FocusLost]
	local ref = props[Roact.Ref]
	
	return Roact.createElement(GUI.StandardTextBox, {
		BorderSizePixel = props.BorderSizePixel,
		BorderColor3 = Style.PrimaryFocusColor,
		MultiLine = props.MultiLine,
		
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		TextTruncate = props.TextTruncate,
		Text = props.Text or props.Init,
		PlaceholderText = props.PlaceholderText,
		TextSize = props.TextSize,
		
		TextXAlignment = props.TextXAlignment,
		TextYAlignment = props.TextYAlignment,
		
		[Roact.Event.Focused] = props[Roact.Event.Focused],
		[Roact.Ref] = ref,
		
		[Roact.Change.Text] = function(rbx)
			if not rbx:IsFocused() then
				self.LastText = rbx.Text
			end
			
			if oldChange then
				oldChange(rbx)
			end
		end,
		
		[Roact.Event.FocusLost] = function(rbx, enterPressed)
			if props.IsNumber then
				-- Expression Parser
				local suc, num = pcall(ExpressionParser.Evaluate, rbx.Text)
				
				if suc and num then
					
					-- Rounding
					if props.Increment then
						num = Math.Round(num, props.Increment)
					end
					
					-- Clamping
					num = math.clamp(num, props.Min or -math.huge, props.Max or math.huge)
					
					-- Custom Verification
					local verify = props.Verify
					local passedCustom = true
					if verify then
						local suc2, new = pcall(verify, num)
						if suc2 then
							if new then
								num = new
							end
						else
							passedCustom = false
						end
					end
					
					-- Callbacks
					if passedCustom then
						rbx.Text = num
						self.LastText = num
						props.Callback(num)
						
						if oldLost then
							oldLost(rbx, enterPressed)
						end
						
						return
					end
				end
			else
				local text = rbx.Text
				
				-- Verify Char count
				if (not props.Min) or #text >= props.Min then
					if (not props.Max) or #text <= props.Max then
						
						-- Custom Verification
						local verify = props.Verify
						local passedCustom = true
						
						if verify then
							local suc, new = pcall(verify, text)
							if suc then
								if new then
									text = new
								end
							else
								passedCustom = false
							end
						end
						
						-- callbacks
						if passedCustom then
							rbx.Text = text
							self.LastText = text
							props.Callback(text)
							
							if oldLost then
								oldLost(rbx, enterPressed)
							end
							
							return
						end
					end
				end
			end
			
			-- reset text if not returned
			rbx.Text = self.LastText
			
			if oldLost then
				oldLost(rbx, enterPressed)
			end
		end
	})
end

function component:__init(G)
	Style = G.Load("Style")
end

return component
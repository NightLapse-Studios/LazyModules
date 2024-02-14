local Checkbox = {}

function Checkbox:__ui(G, I, P)
	I:Stateful(P()
		:Name("DebugCheckbox")
		:Render(function(self)
			local binding = self.props.UseThisBinding
			local callback = self.props.Callback
			
			return I:Frame(P()
				:Size(1, 0, 1, 0)
				:Invisible()
			):Children(
				I:TextButton(P()
					:Size(1, 0, 1, 0)
					:Center()
					:BackgroundColor3(0, 1, 0)
					:BorderSizePixel(0)
					:BackgroundTransparency(binding:map(function(v)
						return v and 0 or 1
					end))
					:Text(" ON ")
					:TextTransparency(binding:map(function(v)
						return v and 0 or 1
					end))
					:TextScaled(true)
					:TextColor3(1, 1, 1)
					:Font(Enum.Font.Roboto)
					:Activated(function()
						callback(not binding:getValue())
					end)
					:RoundCorners()
				):Children(
					I:Frame(P()
						:Invisible()
						:Size(1, 2, 1, 2)
						:Center()
						:RoundCorners()
						:Border(1, Color3.new(0, 1, 0))
					)
				)
			)
		end)
	)
end


return Checkbox
local mod = { }

function mod:__ui(G, I, P)
	local Component
	local UITest = I:Stateful("UITest", I
		:Init(function(self)
			Component = self
		end)
		:Render(function(self)
			local tree = I:Frame(P()
				:Size(0, 10, 0, 10)
				:JustifyTop(0, 0)
				:AnchorPoint(0, 0)
			)

			return tree
		end)
	)

	G.Load("UserInput"):Handler(Enum.KeyCode.U,
		function()
			Component:setState({ visible = true })
		end,
		function()
			Component:setState({ visible = false })
		end
	)
	
	local Roact = G.Load("Roact")
	Roact.mount(Roact.createElement(UITest), game.Players.LocalPlayer.PlayerGui.BaseInterface_NoInset)
end

return mod
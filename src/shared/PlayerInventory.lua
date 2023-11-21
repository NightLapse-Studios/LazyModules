local Inventory

local INV_SIZE = 16

local mod = { }

function mod.new(plr)
	local inv = Inventory.new(INV_SIZE, plr)

	return inv
end

function mod.GetInventory(plr)
	return Inventory.FromOwner(plr)
end

function mod:__init(G)
	Inventory = G.Load("Inventory")
end

function mod:__tests(G, T)
	if G.CONTEXT == "SERVER" then
		return
	end

	local Items = G.Load("Items")

	local inv = mod.new(game.Players.LocalPlayer)
	T:Test("Add items", function()
		inv:Add(Items.FromID[1], 2)

		T:WhileSituation("normally",
			T.NotEqual, inv.Slots[1], false,
			T.Equal, inv.Slots[2], false
		)

		T:ExpectError("adding instanced items", function()
			inv:Add(inv.Slots[1])
		end)
	end)
end

return mod
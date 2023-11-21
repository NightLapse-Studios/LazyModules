local mod = { }

mod.FromID = { }
mod.FromName = { }

local Item = { }
Item.__index = Item

local Meta = _G.Game.Meta
local META_CONTEXTS = _G.Game.Enums.META_CONTEXTS
local ItemBuilder = Meta.CONFIGURATOR(Item)
	:SETTER(META_CONTEXTS.BOTH, "SetStackSize", "StackSize")
	:FINISHER(META_CONTEXTS.BOTH, function(obj)
		table.freeze(obj)
	end)
	:FINISH()

function Item:Instantiate()
	if self.__IsInstanced then
		error("Instantiating an already instanced item")
		return self
	end

	local item = table.clone(self)
	item.__IsInstanced = true

	setmetatable(item, Item)

	return item
end

local function NewItem(name, id)
	local item = {
		Name = name,
		ID = id,
		Stack = 1,
		StackSize = 1,
		__IsInstanced = false
	}

	mod.FromID[id] = item
	mod.FromName[name] = item

	setmetatable(item, ItemBuilder)

	return item
end

NewItem("Grass seeds", 1)
	:SetStackSize(64)
	:FINISH()

return mod
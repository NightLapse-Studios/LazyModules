local mod = { }

mod.FromID = { }
mod.FromName = { }

local Item = { }
Item.__index = Item

function Item:Instantiate()
	if self.__IsInstanced then
		warn("Instantiating an already instanced item, probably a bug")
		return self
	end

	local item = table.clone(self)
	item.__IsInstanced = true

	setmetatable(item, Item)

	return item
end

local function new_item(name, id)
	local item = {
		Name = name,
		ID = id,
		Stack = 1,
		StackSize = 1,
		__IsInstanced = false
	}

	mod.FromID[id] = item
	mod.FromName[name] = item

	table.freeze(item)

	return item
end

new_item("Grass seeds", 1)

return mod
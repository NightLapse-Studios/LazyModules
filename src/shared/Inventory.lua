local Items

local mod = { }

function mod:__init(G)
	Items = G.Load("Items")
end

local Inventory = { }
Inventory.__index = Inventory

function mod.new(opt_owner, slot_count: number)
	opt_owner = opt_owner or false
	slot_count = slot_count or -1

	local inv = {
		DS3Versions = {
			Latest = "v1",
			["v1"] = Inventory.Deserialize,
		},

		Owner = opt_owner,
		Slots = { },
		Size = slot_count
	}

	for i = 1, slot_count do
		inv.Slots[i] = false
	end

	setmetatable(inv, Inventory)

	return inv
end

function Inventory:Serialize()
	local t = {
		Slots = { },
		Size = self.Size
	}

	for i,v in self.Slots do
		if v == false then
			continue
		end

		t.Slots[tostring(i)] = {
			v.Id,
			v.Stack
		}
	end

	return t
end

function Inventory:Deserialize(data)
	self:SetSize(data.Size or self.Size)

	for i,v in data.Slots do
		local id = v[1]
		local stack = v[2]
		self:Set(Items.FromId[id], tonumber(i), stack)
	end

	return true
end

function Inventory:SetSize(size: number)
	self.Size = size

	for i = 1, size do
		self.Slots[i] = false
	end
end

function Inventory:SetSlot(item, slot, stack)
	self.Slots[slot] = item
	item.Stack = stack
end

function Inventory:Add(item): boolean
	local function try_add_new_item(): boolean
		for i = 1, self.Size do
			if self.Slots[i] == false then
				self.Slots[i] = item

				return true
			end
		end

		return false
	end

	local function try_add_to_stack(): boolean
		for i = 1, self.Size do
			local _item = self.Slots[i]
			if _item and _item.Id == item.Id then
				_item.Stack += 1

				return true
			end
		end

		return false
	end

	if item.StackSize > 1 then
		local did_add = try_add_to_stack()
		if not did_add then
			return try_add_new_item()
		else
			-- must be true at this point
			return did_add
		end
	else
		return try_add_new_item()
	end
end

function Inventory:RemoveItem(item)
	local function try_remove_item(): boolean
		for i = 1, self.Size do
			local _item = self.Slots[i]
			if _item and _item.Id == item.Id then
				self.Slots[i] = false

				return true
			end
		end

		return false
	end

	local function try_remove_from_stack(): boolean
		for i = 1, self.Size do
			local _item = self.Slots[i]
			if _item and _item.Id == item.Id then
				_item.Stack -= 1

				if _item.Stack == 0 then
					self.Slots[i] = false
				end

				return true
			end
		end

		return false
	end

	if item.StackSize > 1 then
		return try_remove_from_stack()
	else
		return try_remove_item()
	end
end

function Inventory:RemoveCountFromSlot(item, slot, count)
	local _item = self.Slots[slot]
	if _item and _item.Id == item.Id then
		if _item.Stack < count then
			-- Cannot remove more than exists in the stack
			return false
		end

		_item.Stack -= count

		if _item.Stack == 0 then
			self.Slots[slot] = false
		end

		return true
	end

	-- The slot contains the wrong item
	return false
end

return mod
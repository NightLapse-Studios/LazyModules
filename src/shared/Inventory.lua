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
			v.ID,
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
		self:SetSlot(Items.FromId[id], tonumber(i), stack)
	end

	return true
end

function Inventory:SetSize(size: number)
	self.Size = size

	for i = 1, size do
		self.Slots[i] = false
	end
end

function Inventory:SetSlot(item_type, slot, stack)
	local remaining = stack
	item_type = item_type:Instantiate()
	self.Slots[slot] = item_type
	item_type.Stack = math.min(item_type.StackSize, stack)

	return remaining - item_type.Stack
end

-- returns the amount of items not able to be added
function Inventory:Add(item_type, amount): boolean
	amount = amount or item_type.Stack

	local function try_add_new_item(): boolean
		local remaining = amount
		for i = 1, self.Size do
			if self.Slots[i] == false then
				remaining = self:SetSlot(item_type, i, remaining)

				if remaining <= 0 then
					break
				end
			end
		end

		return remaining
	end

	local function try_add_to_stack(): boolean
		local remaining = amount
		for i = 1, self.Size do
			local _item = self.Slots[i]
			local can_add = _item.StackSize - _item.Stack

			if _item and _item.ID == item_type.ID and can_add > 0 then
				_item.Stack += can_add
				remaining -= can_add
			end
		end

		return remaining
	end

	if item_type.StackSize > 1 then
		local remaining = try_add_to_stack()
		if remaining > 0 then
			return try_add_new_item()
		else
			-- must be true at this point
			return remaining
		end
	else
		return try_add_new_item()
	end
end

function Inventory:RemoveItem(item_type)
	local function try_remove_item(): boolean
		for i = 1, self.Size do
			local _item = self.Slots[i]
			if _item and _item.ID == item_type.ID then
				self.Slots[i] = false

				return true
			end
		end

		return false
	end

	local function try_remove_from_stack(): boolean
		for i = 1, self.Size do
			local _item = self.Slots[i]
			if _item and _item.ID == item_type.ID then
				_item.Stack -= 1

				if _item.Stack == 0 then
					self.Slots[i] = false
				end

				return true
			end
		end

		return false
	end

	if item_type.StackSize > 1 then
		return try_remove_from_stack()
	else
		return try_remove_item()
	end
end

function Inventory:RemoveCountFromSlot(item_type, slot, count)
	local _item = self.Slots[slot]
	if _item and _item.ID == item_type.ID then
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
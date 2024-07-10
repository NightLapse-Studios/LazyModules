--!strict

--[[
	This module simply uses a provided constructore function `ctor` to create some data which is
		caused by an event, and a corresponding event will remove that data and its entry from the registry

	Types of registries based on this file must create a list of registries of its type, and effect them all when
		the corresponding events fire
		E.G. `PlayerRegistry.lua`

	It is highly suggested that registries are only created around game startup

	--TODO: Tests
	--TODO: Analyze if this module covers all the sensible use cases
]]
local Globals

local mod = { }
local mt_Registry = { __index = mod }


local function default_ctor()
	return { }
end
local function default_insert(self, plr, i, v)
	return table.insert(self.Registry[plr], i, v)
end
local function default_remove(self, plr, i)
	local t = self.Registry[plr]
	local e = t[i]
	t[i] = nil
	return e
end

function mod.new(ctor)
	local t = {
		insert = default_insert,
		remove = default_remove,
		-- __list is used to point to a table which lists all registries of a certain type
		-- E.G. PlayerRegistries are all stored in a table, pointed to by __list
		__list = -1,
		__ctor = ctor or default_ctor,
		__ID = -1,
		Registry = { }
	}

	setmetatable(t, mt_Registry)

	return t
end

--[[
	Builder functions
]]
function mod:Insert(func)
	self.insert = func
	return self
end
function mod:Remove(func)
	self.remove = func
	return self
end
function mod:Constructor(func)
	self.__ctor = func
	return self
end
function mod:List(table)
	self.__list = table
	return self
end
function mod:LoadExisting(func)
	if not self:__check_is_valid() then
		error("A Constructor, insert func, and remove func are necessary before loading existing entites")
	end

	func(self)
	return self
end

--[[
	Builder support functions
]]

--[[ function mod:__load_existing_players()
	for i, plr in game.Players:GetPlayers() do
		self.Registry[plr.UserId] = self.__ctor()
	end
end ]]

function mod:__check_is_valid()
	return self.__ctor and self.insert and self.remove
end

--[[
	Funcitonality
]]
function mod:destroy()
	assert(self.__list ~= -1)
	table.remove(self.__list, self.__ID)
end

function mod:get(thing)
	return self.Registry[thing]
end

function mod:set(thing, val)
	self.Registry[thing] = val
end



function mod.__init(G)
	Globals = G
end

return mod
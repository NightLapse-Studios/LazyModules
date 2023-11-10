--!strict
local Enums = _G.Game.Enums
local Tables = _G.Game.Load("Tables")


local EachRound = Enums.ResetType.EachRound
local Both = Enums.ResetType.Both

local Stats = {
	ByName = { },
	ById = { },
	createdPlayerStats = {},
}


local defaultOptions = {}

local groupNames = {}

function Stats.new_base(default, name, options)
	options = options or defaultOptions

	for i = #groupNames, 1, -1 do
		local group = groupNames[i]
		if group.Type == "Back" then
			name = name .. group.Name
		else
			name = group.Name .. name
		end
	end

	local newstat = {
		ID = nil,
		Name = name,
		DefaultValue = default,

		ResetType = options.Reset or false,
		BroadcastChange = options.Network or false,
		IsLowerGood = options.IsLowerGood or false,

		Copy = Stats.Copy,
	}

	Stats.ByName[name] = newstat

	-- if we create a stat base after any playerstats have been created, insert them.
	for _, plrStatObj in Stats.createdPlayerStats do
		plrStatObj[name] = newstat:Copy()
	end

	return newstat
end

function Stats:new_perm(default, name, options: any?)
	local new = Stats.new_base(default, name, options)

	new.IsPerm = true
	new.ID = self.ID
	Stats.ById[new.ID] = new

	return new
end

function Stats.get_perms()
	local ret = {}

	for i,v in pairs(Stats.ById) do
		if v.IsPerm then
			ret[v.Name] = v
		end
	end

	return ret
end

function Stats.get_bases()
	local ret = {}

	for i,v in pairs(Stats.ByName) do
		if not v.IsPerm then
			ret[v.Name] = v
		end
	end

	return ret
end

function Stats:Copy(newVal)
	local realValue
	if newVal ~= nil then
		realValue = newVal
	else
		realValue = self.DefaultValue
	end

	if type(realValue) == "table" then
		--One time duplication so players aren't refrencing the same table.
		realValue = Tables.DeepDuplicate(realValue)
	end

	local newCopy = {
		ID = self.ID,
		Value = realValue,
	}

	return newCopy
end

function Stats.id(id)
	if Stats.ById[id] then
		error("StatsID overwrite: " .. tostring(id))
	end

	return {
		ID = id,
		new_perm = Stats.new_perm,
	}
end

-- following stats have this name prepended to the beginning of their name.
function Stats.group(name)
	local idx = #groupNames + 1
	groupNames[idx] = {
		Type = "Front",
		Name = name,
	}

	return function(...)
		table.remove(groupNames, idx)
	end
end

-- following stats have this name appended to the end of their name.
function Stats.fgroup(name)
	local idx = #groupNames + 1
	groupNames[idx] = {
		Type = "Back",
		Name = name,
	}

	return function(...)
		table.remove(groupNames, idx)
	end
end

Stats.new_base( true, "IsDead", {Network = "All"})
Stats.new_base( true, "CanRespawn")
Stats.new_base( 60, "Ping", {Network = "All"})

Stats.new_base( 0, "cur_torso_ang", {Network = "All"})
Stats.new_base( 0, "cur_char_pitch", {Network = "All"})
Stats.new_base( 0, "cur_head_ang", {Network = "All"})

Stats.id(1):new_perm( false, "Banned")
Stats.id(2):new_perm( false, "BannedReason")
Stats.id(3):new_perm( false, "BannedRelease")


function Stats:__init(G)
end

return Stats

--!strict

local DS3 = require(game.ReplicatedFirst.Modules.DataStore3)
local Enums = require(game.ReplicatedFirst.Lib.Enums)

local mod = { }

local PlrStats = { }
PlrStats.__index = PlrStats

function PlrStats:GetStat(stat_name: string)
	return self.TempStats[stat_name]
end

function PlrStats:GetPermStat(stat_name: string)
	return self.PermStats[stat_name]
end

function PlrStats:SetStat(stat_name: string, value: any)
	self.TempStats[stat_name] = value
end

function PlrStats:SetPermStat(stat_name: string, value: any)
	self.PermStats[stat_name] = value
end

function mod.new()
    local stats = {
        DSConfig = false,
        DataBinding = false,

		PermStats = {
			-- Settings
			EffectsVolumeSetting = 1,
			MusicVolumeSetting = 1,
			KeyboardLayoutSetting = Enums.KeyboardLayout.QWERTY,
			MoveLeftBinding = Enum.KeyCode.A,
			MoveRightBinding = false,
			MoveBackBinding = false,
			MoveForwardBinding = false,
			SwitchCameraLeftBinding = false,
			SwitchCameraRightBinding = false,
			UnlockMouseBinding = false,
			JumpBinding = false,
			SprintBinding = false,
			PlayerListBinding = false,
		},

		TempStats = {
			cur_torso_ang = 0.0,
			cur_char_pitch = 0.0,
			cur_head_ang = 0.0,
		}
    }

	setmetatable(stats, PlrStats)
    
	type ThisStatClass = typeof(stats)
	local v1: DS3.DSSerializationVersion<ThisStatClass> = {
		Serialize = function(stats: ThisStatClass)
			local t: DS3.DSSavable = { }

			for i,v in stats.PermStats do
				if i == "DSConfig" or i == "DataBinding" then
					continue
				end

				t[tostring(i)] = tostring(v)
			end

			return t
		end,
		Deserialize = function(stats: ThisStatClass, data: DS3.DSSavable)
            for i,v in data do
                stats[i] = v
            end

		    return true
		end
	}

	local SerializationVersions: DS3.DSSerializationVersions<ThisStatClass> = {
		v1 = v1,
		Latest = "v1"
	}

	local DSConfig: DS3.DSConfig<ThisStatClass> = {
		StoreRetrieved = false,
		SerializationVersions = SerializationVersions
	}

	stats.DSConfig = DSConfig

	return stats
end

return mod
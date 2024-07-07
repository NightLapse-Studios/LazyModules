--!strict

local DS3 = require(game.ReplicatedFirst.Modules.DataStore3)

local mod = { }

function mod.new()
    local stats = {
        DSConfig = false,
        DataBinding = false,
    }
    
	type ThisStatClass = typeof(stats)
	local v1: DS3.DSSerializationVersion<ThisStatClass> = {
		Serialize = function(stats: ThisStatClass)
			local t: DS3.DSSavable = { }

			for i,v in stats do
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
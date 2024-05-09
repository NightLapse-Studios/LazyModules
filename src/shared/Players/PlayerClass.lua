--!strict

local DS3 = require(game.ReplicatedFirst.Modules.DataStore3)

local mod = { }

local PlayerClass = {}
PlayerClass.__index = PlayerClass

function mod.new(plr)
	local self = {
		Player = plr,
		
		DSConfig = false,
		DataBinding = false
	}

	type ThisPlrClass = typeof(self)
	local v1: DS3.DSSerializationVersion<ThisPlrClass> = {
		Serialize = function(self: ThisPlrClass)
			local t: DS3.DSSavable = { }

			for i,v in self do
				t[tostring(i)] = tostring(v)
			end

			return t
		end,
		Deserialize = function(self: ThisPlrClass, data: DS3.DSSavable)

		end
	}

	local SerializationVersions: DS3.DSSerializationVersions<ThisPlrClass> = {
		v1 = v1,
		Latest = "v1"
	}

	local DSConfig: DS3.DSConfig<ThisPlrClass> = {
		StoreRetrieved = false,
		SerializationVersions = SerializationVersions
	}

	self.DSConfig = DSConfig

	setmetatable(self, PlayerClass)

	local a: DS3.DSObject<ThisPlrClass> = self
	
	return a
end

export type PlayerClass = typeof(mod.new(game.Players.LocalPlayer))

function PlayerClass:Destroy()
	
end

type thing1 = { }
type thing2 = {
	ReservedKey: false | thing1
}
function mod.new2()
	local t: thing2 = {
		ReservedKey = false
	}

	t.ReservedKey = { } :: thing1

	return t
end

return mod
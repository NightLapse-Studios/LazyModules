--!strict

local DS3 = require(game.ReplicatedFirst.Modules.DataStore3)

local mod = { }

local PlayerClass = {}
PlayerClass.__index = PlayerClass

function mod.new(plr)
	local self = {
		Player = plr,
		
		Stats = false,
		DataBinding = false
	}

	setmetatable(self, PlayerClass)
	
	return self
end

export type PlayerClass = typeof(mod.new(game.Players.LocalPlayer))

function PlayerClass:Destroy()
	
end

return mod
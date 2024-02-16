local PlayerClass = {}
PlayerClass.__index = PlayerClass

function PlayerClass.new(plr)
	local self = setmetatable({
		ServerLoaded = false,
		ClientLoaded = false,
		
		Player = plr,

		--Reserve keys
		DataBinding = nil,
	}, PlayerClass)
	
	return self
end

return PlayerClass
--!strict
--[[
	TODO: This fild turned out to be a bad idea; get rid of it
]]
local mod = {
}

--local INIT_CONTEXT = if game:GetService("RunService"):IsServer()  then "SERVER" else "CLIENT"

local LazyString = { 
	__tostring = function(self)
		local s = ""
		for i,v in self do
			s = s .. tostring(v)
		end

		return s
	end
}


function mod.new(...)
	local str = setmetatable({...}, LazyString)

	return str
end

return mod
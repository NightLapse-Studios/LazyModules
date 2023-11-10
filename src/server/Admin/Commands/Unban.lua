local DS3
local PlayerStatList

local unban = {}

unban.Parameters = {"PlayerId"}
function unban.execute(argument, sender)
	local id = argument[1]

	if not id then
		return
	end

	DS3.OffserverUpdateAsync(DS3.GetStoreName(), DS3.GetUserIdMasterKey(id), "PlrStats", function(moduleSerialData)
		moduleSerialData[tostring(PlayerStatList.ByName["Banned"].ID)] = false
		moduleSerialData[tostring(PlayerStatList.ByName["BannedReason"].ID)] = false
		moduleSerialData[tostring(PlayerStatList.ByName["BannedRelease"].ID)] = false
	end)
end

function unban:__init(G)
	DS3 = G.Load("DataStore3")
	PlayerStatList = G.Load("PlayerStatList")
end

return unban
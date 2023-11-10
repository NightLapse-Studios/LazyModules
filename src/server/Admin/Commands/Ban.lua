
local ServerGlobals = _G.Game
local Ban = {}

local BAN_MESSAGE = "\n [You have been banned]\n Reason: "

Ban.Parameters = {"Player", "Number", "Text"}
function Ban.execute(sender, commandDataTable)
    local player, banDuration, banReason = table.unpack(commandDataTable)

    if not player then
        return
    end
    
    if not banDuration then
        banDuration = 60*60*24*4
    end
    
    if not banReason then
        banReason = " Unspecified"
    end

    ServerGlobals[player].PlayerStats:ChangeStat("Banned", true, "set", true)
    ServerGlobals[player].PlayerStats:ChangeStat("BannedReason", banReason, "set", true)
    ServerGlobals[player].PlayerStats:ChangeStat("BannedRelease", math.round(tick() + banDuration), "set", true)
    
    player:Kick(BAN_MESSAGE..banReason)
end

return Ban
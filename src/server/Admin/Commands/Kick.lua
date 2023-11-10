local Kick = {}

local KICK_MESSAGE = "\n [You have been kicked]\n Reason: "

Kick.Parameters = {"Players", "Text"}
function Kick.execute(sender, commandDataTable)
    local players, kickReason = table.unpack(commandDataTable)
    
    if kickReason == nil then
        kickReason = KICK_MESSAGE .. "Unspecified"
    else
        kickReason = KICK_MESSAGE .. kickReason
    end
    
    if players then
        for i,plr in pairs(players) do
            plr:Kick(kickReason)
        end
    end
end

return Kick
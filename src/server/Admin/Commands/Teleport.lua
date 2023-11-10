--[[
    Use:

    :teleport [player] [playyer]
    :teleport me [player]
    :teleport [player] me
    :teleport all me
]]

local Teleport = {}
local MIN_COMMAND_PARAMETERS = 2

Teleport.Aliases = {"tp"}
Teleport.Parameters = {"Players", "Player"}
function Teleport.execute(sender, commandDataTable, callback)
    if #commandDataTable < MIN_COMMAND_PARAMETERS then
        return print("Minimum of: "..MIN_COMMAND_PARAMETERS.." command parameters required")
    end

    for i,plr in pairs(commandDataTable[1]) do
        callback(plr, commandDataTable[2])
    end
end

return Teleport
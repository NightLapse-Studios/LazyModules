local Fly = {}
local CommandFolder = script.Parent
local AdminFolder = CommandFolder.Parent
local MiscFolder = AdminFolder.Misc

local Globals

Fly.Parameters = {"Players", "Bool"}
function Fly.execute(sender, commandDataTable)
    local players, state = table.unpack(commandDataTable)
    
    if not players then
        players = {sender}
    end
    
    for i,plr in pairs(players) do
        local character = plr.Character
        if character and not Globals[plr].PlayerStats:GetStatValue("IsDead") then
            local flightScript = character:FindFirstChild("Flight")
            
            if flightScript and not state then
                character.Flight:Destroy()
                return
            end
    
            if not flightScript and (not state or state == true) then
                local cflightScript = MiscFolder:FindFirstChild("Flight")
                
                cflightScript = cflightScript:Clone()
                cflightScript.Disabled = true
            
                cflightScript.Parent = character
                cflightScript.Disabled = false
            end
        end
    end
end

function Fly:__init(G)
    Globals = G
end

return Fly
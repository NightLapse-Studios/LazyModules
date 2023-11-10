local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

--[[
    Admin API written by cryphowns | gd6.rysing@gmail.com
    Intellectual Property of NightLapse Studios
    11/3/2022
    
    Edited by Gavin Oppegard
    
    Usage Examples
    
    :kill all{Alive=true}   --Kills all players who are alive (this is just an example, in the code killing a dead player is impossible so this is redundant)
    :kill others            --Kills everyone but you
    :fly                    --toggles the state of you flying
    :ban vij annoying       --bans vijet1 with reason annoying
    := 9*100/(32*pi())+rnd()--compute math
]]

--[ Services ]
--[ Directories ]
--[ Imports ]
local ServerGlobals
local Permissions
local Character
local CommandParameters
local Audio
local Assets

--[ Constants ]
local COMMAND_SEPARATOR = " " -- whitespace
local COMMAND_INITIATOR = ":"

--[ Variables ]
local Admin = {
    CharacterHandlerReference = nil
}

local Commands = {}

--[ Functions ]
local function lockServer(value)
    ServerGlobals.ServerLocked = value
end

local function connectToChat()
    local generalChannel : TextChannel = TextChatService:WaitForChild("TextChannels"):WaitForChild("RBXGeneral")

    generalChannel.ShouldDeliverCallback = function(textChatMessage: TextChatMessage, targetTextSource: TextSource)
        local userid = targetTextSource.UserId
        local player = Players:GetPlayerByUserId(userid)
        local name = player and player.Name
        
        return Admin:handleMessageData(textChatMessage.Text, name)
    end
end

function Admin:handleMessageData(message, sender)
    sender = Players:FindFirstChild(sender)
    
    if not sender then
        return true
    end
    
    return self:parseMessage(sender, message)
end

function Admin:parseMessage(sender, message)
    message = string.lower(message)
    if string.sub(message, 1, 1) == COMMAND_INITIATOR then
        local arguments = string.split(string.sub(message, 2, #message), COMMAND_SEPARATOR)
        local command = arguments[1]
        
        if not Commands[command] then
            for i,v in pairs(Commands) do
                if not v.Aliases then
                    continue
                end
                if table.find(v.Aliases, command) then
                    command = i
                    break
                end
            end
        end

        local hasPermission, emessage = Permissions.hasPermission(sender, command)
        if hasPermission == false then
            warn(emessage)
            return
        end
        
        local commandFile = Commands[command]
        
        if commandFile == nil then
            warn("Command [ "..COMMAND_INITIATOR..command.." ] does not exist!") --can probably warn the admins with a ui
            return
        end

        local commandData = {}
        for i = 2, #arguments do
            local argument = arguments[i]
            local argumentType = commandFile.Parameters and commandFile.Parameters[i - 1]
            
            if argumentType then
                local getArgumentData = CommandParameters[argumentType]
                if not getArgumentData then
                    return warn(argumentType .. " does not exist!")
                end
                argument = getArgumentData(argument, sender)
            end
            
            table.insert(commandData, argument)
        end
        
        if self.Callbacks[command] then
            commandFile.execute(sender, commandData, self.Callbacks[command], message)
        else
            commandFile.execute(sender, commandData, nil, message)
        end
        
        return false
    else
        for text, callout in pairs(Assets.Sounds.WarCries) do
            if message == text then
                local asset = callout[1]
                local volume = callout[2]
                Audio.ParentedSound(asset, volume, sender.Character.Head):Play()
            end
        end
    end
    
    return true
end

function Admin:checkIfServerLocked()
    return ServerGlobals.ServerLocked
end

function Admin:checkBan(player)
    local stats = ServerGlobals[player].PlayerStats
    if stats:GetStatValue("Banned", true) then
        local releaseTime = stats:GetStatValue("BannedRelease", true)
        local currentTime = tick()
        
        if currentTime >= releaseTime then
            if releaseTime > 0 then
                stats:ChangeStat("Banned", false, "set", true)
                stats:ChangeStat("BannedRelease", false, "set", true)
                stats:ChangeStat("BannedReason", false, "set", true)
            end
        else
            player:Kick(stats:GetStatValue("BannedReason", true))
            return true
        end
    end
end

--[ Listeners ]
--[ Calls ]
do --load commands and callbacks
end

function Admin:__init(G)
    ServerGlobals = G

    Character = G.Load("Character")
    Permissions = G.Load("Permissions")
    CommandParameters = G.Load("CommandParameters")
    Audio = G.Load("Audio")
    Assets = G.Load("Assets")
end

function Admin:__build_signals(G, B)
    B:NewEvent("RegisterCommand"):Connect(function(name, parameters, execute)
        Commands[name] = {
            execute = execute,
            Parameters = parameters,
        }
    end)
end
function Admin:__finalize(G)
    Admin.Callbacks = {
        lock = function()
            lockServer(true)
        end,
        unlock = function()
            lockServer(false)
        end,
        teleport = function(firstTeleportee, secondTeleportee)
            Character.PlayerTeleport(firstTeleportee, secondTeleportee)
        end,
    }

    for _, module in pairs(script.Commands:GetChildren()) do
        Commands[string.lower(module.Name)] = G.LightLoad(module)
    end
    
    connectToChat()
end

return Admin;
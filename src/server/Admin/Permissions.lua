local Permissions = {}

local Config

function Permissions:__init(G)
    Config = G.Load("BUILDCONFIG")
end

local ALL_PERMISSIONS = "*" -- this keyword suggests that the user/role ahs access to all permissions

Permissions.Whitelist = {
    -- [Role] = Commands
    ["Junior Developer"] = {"Kick"},
    ["Developer"] = {"Teleport", "Ban", "Kick", "Fly"},
    ["Manager"] = {ALL_PERMISSIONS},
    ["Owners"] = {ALL_PERMISSIONS},
    ["Holder"] = {ALL_PERMISSIONS},
}

function Permissions.hasPermission(sender, command)
    local senderRole = sender:GetRoleInGroup(Config.GroupID)
    local availableCommands = Permissions.Whitelist[senderRole]
    if availableCommands ~= nil then
        for _, commandId in pairs(availableCommands) do
            if string.lower(commandId) == "*" or string.lower(commandId) == command then
                return true
            end
        end
        return false, "You do not have permission to execute the command: " .. command
    else
        return false, "You do not have permission to execute commands"
    end
end

return Permissions
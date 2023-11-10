--[[
	Command Parameters allow for text to be processed in a similar way across commands.
]]

local ExpressionParser
local ServerGlobals

local Players = game:GetService("Players")

local theseArguments = {}
local Parameters = {}

local function checkArgument(argument, list)
	for i,v in pairs(list) do
		if argument == v then
			return true
		end
	end
	return false
end

local function getParameterArguments(argument, parameter, sender)
	local leftBracket = string.find(argument, "{")
	if leftBracket then
		local stringParameterArguments = string.sub(argument, leftBracket + 1, -2)
		argument = string.sub(argument, 1, leftBracket - 1)

		local parameterArguments = {}
		for i,v in pairs(string.split(stringParameterArguments, ",")) do
			local nameValue = string.split(v, "=")

			local name, value = nameValue[1], nameValue[2]

			if theseArguments[parameter] then
				value = Parameters[theseArguments[parameter]](value, sender)
			end

			parameterArguments[name] = value
		end

		return argument, parameterArguments
	end

	return argument, {}
end

function Parameters.Text(argument)
	return argument
end

function Parameters.CamelCase(argument)
	argument = string.upper(string.sub(argument, 1,1)) .. string.sub(argument, 2, -1)
end

function Parameters.Bool(argument)
	if checkArgument(argument, {"1", "true", "on", "yes", "t"}) then
		return true
	elseif checkArgument(argument, {"0", "false", "off", "no", "f"}) then
		return false
	end
end

function Parameters.Number(argument)
	return ExpressionParser.Evaluate(argument)
end

function Parameters.UserId(argument)
	local id = Parameters.Number(argument)
	return id
end

function Parameters.Player(argument, sender)
	if argument == "me" then
		return sender
	end

	local MIN_NAME_LEN = 3

	if #argument < MIN_NAME_LEN then
        return print("Cannot find player, try typing their full name")
    end

    local matchCount = 0
	local player = nil
    
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if string.match(string.lower(otherPlayer.Name), argument) ~= nil then
            matchCount += 1
            player = otherPlayer
        end
    end
    
    if matchCount > 1 then
        player = nil
    end

	return player
end

theseArguments.Players = {Alive = "Bool"}
function Parameters.Players(argument, sender)
	local players

	local parameterArguments
	argument, parameterArguments = getParameterArguments(argument, "Players", sender)

	if argument == "all" then
		players = Players:GetPlayers()
	elseif argument == "others" then
		players = Players:GetPlayers()
		table.remove(players, table.find(players, sender))
	else
		players = Parameters.Player(argument, sender)
		if players ~= nil then
			players = {players}
		end
	end

	if parameterArguments.Alive == true then
		for i = #players, 1, -1 do
			if ServerGlobals[players[i]].PlayerStats:GetStatValue("IsDead") then
				table.remove(players, i)
			end
		end
	elseif parameterArguments.Alive == false then
		for i = #players, 1, -1 do
			if not ServerGlobals[players[i]].PlayerStats:GetStatValue("IsDead") then
				table.remove(players, i)
			end
		end
	end

	return players
end

function Parameters:__init(G)
	ServerGlobals = G
	ExpressionParser = G.Load("ExpressionParser")
end

return Parameters
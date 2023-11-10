local compute = {}

local MAX_COMPUTATIONS_AT_ONCE = 1

compute.Aliases = {"comp", "math", "ans", "answer", "sol", "solve", "parse", "par", "equate", "eq", "=", "print", "pr", "eval"}
compute.Parameters = table.create(MAX_COMPUTATIONS_AT_ONCE, "Number")
function compute.execute(sender, commandData, callback, message)
	local split = string.split(message, " ")

	if #commandData > MAX_COMPUTATIONS_AT_ONCE then
		return
	end

	local newMessage = split[1]
	for i = 1, #commandData do
		newMessage ..= " " .. split[i + 1] .. " = " .. commandData[i]
		if commandData[i+1] then
			newMessage ..= "\n"
		end
	end

	callback(sender, newMessage)
end

return compute
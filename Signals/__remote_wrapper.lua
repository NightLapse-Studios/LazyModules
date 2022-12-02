
local IsServer = game:GetService("RunService"):IsServer()

return function(identifier: string, builder_mt: table)
	-- TODO: check that all events made on the server are also made on the client
	local transmitter
	if IsServer then
		transmitter = setmetatable(
			{
				Instance.new("RemoteEvent", game.ReplicatedStorage),
				Configured = {
					Server = false,
					Client = false,
				},
			},
			builder_mt
		)
		transmitter[1].Name = identifier
	else
		transmitter = setmetatable(
			{
				game.ReplicatedStorage:WaitForChild(identifier),
				Configured = {
					Server = false,
					Client = false,
				},
			},
			builder_mt
		)
	end

	return transmitter
end
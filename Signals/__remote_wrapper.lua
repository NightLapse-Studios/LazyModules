
local IsServer = game:GetService("RunService"):IsServer()

local mod = { }

local lazymod_traceback
function mod:__init(G, LazyModules)
	lazymod_traceback = LazyModules.format_lazymodules_traceback
end

function mod.wrapper(identifier: string, builder_mt: table)
	-- TODO: check that all events made on the server are also made on the client
	local transmitter
	if IsServer then
		local remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = identifier
		remoteEvent.Parent = game.ReplicatedStorage
		
		transmitter = setmetatable(
			{
				remoteEvent,
				Configured = {
					Server = false,
					Client = false,
				},
				Name = identifier
			},
			builder_mt
		)
	else
		local event = game.ReplicatedStorage:WaitForChild(identifier, 6)
		
		if not event then
			warn("Waiting for event timed out! - " .. identifier .. "\n" .. lazymod_traceback())
		end
		
		transmitter = setmetatable(
			{
				event,
				Configured = {
					Server = false,
					Client = false,
				},
				Name = identifier
			},
			builder_mt
		)
	end

	return transmitter
end

return mod
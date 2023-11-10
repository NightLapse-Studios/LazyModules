local Players
local Error

local mod = { }

local function OnTick(dt)
	debug.profilebegin("PlrMod")
	local success, err = pcall(Players.Update, dt)
	Error.assert_or_panic(success, err, "OnTick::ServerPlayerModule::Update")
	debug.profileend()
end

function mod:__init(G)
	Players = G.Load("Players")
	Error = G.Load("Error")
end

function mod:__finalize(G)
	game:GetService("RunService").Stepped:Connect(OnTick)
end

return mod

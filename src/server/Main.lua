local Players
local Component
local Error

local mod = { }

local function OnTick(dt)
	debug.profilebegin("PlrMod")
	local success, err = pcall(Players.Update, dt)
	Error.assert_or_panic(success, err, "OnTick::ServerPlayerModule::Update")
	debug.profileend()

	debug.profilebegin("Components")
	local success, err = pcall(Component.Update, dt)
	Error.assert_or_panic(success, err, "OnTick::ServerPlayerModule::Update")
	debug.profileend()
end

function mod:__init(G)
	Players = G.Load("Players")
	Component = G.Load("Component")
	Error = G.Load("Error")
end

function mod:__finalize(G)
	game:GetService("RunService").Stepped:Connect(OnTick)
end

return mod

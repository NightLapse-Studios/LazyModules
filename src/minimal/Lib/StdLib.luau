--!strict
--[[
	Loads a set of modules, places their API exports in the Game object on __init
]]

local Config = require(game.ReplicatedFirst.Config)

local Enums = game.ReplicatedFirst.Lib:FindFirstChild("Enums")
local Meta = game.ReplicatedFirst.Lib:FindFirstChild("Meta")
local Debug = game.ReplicatedFirst.Lib:FindFirstChild("Debug")
local DebugMenu = game.ReplicatedFirst.Lib:FindFirstChild("DebugMenu")
local Maskables = game.ReplicatedFirst.Lib:FindFirstChild("Maskables")

local mod = { }
local Libs = {
	Enums = if Enums then require(Enums) else nil,
	Meta = if Meta then require(Meta) else nil,
	Debug = if Debug then require(Debug) else nil,
	DebugMenu = if DebugMenu then require(DebugMenu) else nil,
	Maskables = if Maskables then require(Maskables) else nil,
	Config = require(game.ReplicatedFirst.Config),
}

local Game

local function print_s(...)
	if Game.CONTEXT == "SERVER" then
		print(...)
	end
end

local function print_c(...)
	if Game.CONTEXT == "CLIENT" then
		print(...)
	end
end


local APIUtils = require(game.ReplicatedFirst.Lib.APIUtils)
local exports = APIUtils.EXPORT_LIST(Libs)
	:ADD("empty_table", { })
	:ADD("no_op_func", function() end)
	:ADD("ContextVar", Config.ContextVar)
	:ADD("PlatformVar", Config.PlatformVar)
	:ADD("IsMobile", Config.PlatformVar(false, true))
	:ADD("print_s", print_s)
	:ADD("print_c", print_c)

for i,v in Libs do
	exports:ADD(i, v)
end

if game:GetService("RunService"):IsClient() then
	-- These are unreliable if the screen changes size, but they work in a quick pinch.
	-- TODO: A real solution to this
	local mouse = game.Players.LocalPlayer:GetMouse()

	exports:ADD("ScreenSizeXRatio", mouse.ViewSizeX / 1920)
	exports:ADD("ScreenSizeYRatio", mouse.ViewSizeY / 1080)
else
	exports:ADD("ScreenSizeXRatio", 1)
	exports:ADD("ScreenSizeYRatio", 1)
end

function mod.LoadExports(G)
	Game = G
	APIUtils.LOAD_EXPORTS(Libs, G)

	for i,v in Libs do
		if APIUtils.HAS_API_EXPORTS(v) then
			APIUtils.LOAD_EXPORTS(v, G)
		end
	end
end

return mod
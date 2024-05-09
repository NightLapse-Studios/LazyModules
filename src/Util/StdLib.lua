--!strict
--[[
	Loads a set of modules, places their API exports in the Game object on __init
]]

local Config = require(game.ReplicatedFirst.Util.Config.Config)

local mod = { }
local Libs = {
	Enums = require(game.ReplicatedFirst.Util.Enums),
	Meta = require(game.ReplicatedFirst.Util.Meta),
	Debug = require(game.ReplicatedFirst.Util.Debug),
	DebugMenu = require(game.ReplicatedFirst.Util.Debug.DebugMenu),
	Maskables = require(game.ReplicatedFirst.Util.Maskables),
	Config = require(game.ReplicatedFirst.Util.Config.Config),
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


local APIUtils = require(game.ReplicatedFirst.Util.APIUtils)
local exports = APIUtils.EXPORT_LIST(Libs)
	:ADD("Enums")
	:ADD("Meta")
	:ADD("Debug")
	:ADD("DebugMenu")
	:ADD("Maskables")
	:ADD("Config")
	:ADD("empty_table", { })
	:ADD("no_op_func", function() end)
	:ADD("ContextVar", Config.ContextVar)
	:ADD("PlatformVar", Config.PlatformVar)
	:ADD("IsMobile", Config.PlatformVar(false, true))
	:ADD("print_s", print_s)
	:ADD("print_c", print_c)

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
--!strict
--[[
	Loads a set of modules, places their API exports in the Game object on __init
]]

local Config = require(game.ReplicatedFirst.Config)

local Enums = game.ReplicatedFirst.Lib:FindFirstChild("Enums")
local Meta = game.ReplicatedFirst.Lib:FindFirstChild("Meta")
local Debug = game.ReplicatedFirst.Lib:FindFirstChild("Debug")
local DebugMenu = if Debug then Debug:FindFirstChild("DebugMenu") else nil
local Maskables = game.ReplicatedFirst.Lib:FindFirstChild("Maskables")

local mod = { }

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

local ExportList = {
	Enums = if Enums then require(Enums) else nil,
	Meta = if Meta then require(Meta) else nil,
	Debug = if Debug then require(Debug) else nil,
	DebugMenu = if DebugMenu then require(DebugMenu) else nil,
	Maskables = if Maskables then require(Maskables) else nil,
	Config = require(game.ReplicatedFirst.Config),
	empty_table = { },
	no_op_func =  function() end,
	ContextVar =  Config.ContextVar,
	PlatformVar =  Config.PlatformVar,
	IsMobile =  Config.PlatformVar(false, true),
	print_s =  print_s,
	print_c =  print_c,
}

if game:GetService("RunService"):IsClient() then
	-- These are unreliable if the screen changes size, but they work in a quick pinch.
	-- TODO: A real solution to this
	local mouse = game.Players.LocalPlayer:GetMouse()

	ExportList.ScreenSizeXRatio = mouse.ViewSizeX / 1920
	ExportList.ScreenSizeYRatio = mouse.ViewSizeY / 1080
else
	ExportList.ScreenSizeXRatio = 1
	ExportList.ScreenSizeYRatio = 1
end

local APIUtils = require(game.ReplicatedFirst.Lib.APIUtils)
local ApiExports = APIUtils.ExportList(ExportList)
mod = ApiExports:ExposeTo(mod)

function mod.LoadExports<T>(G: T): T & typeof(ApiExports:LoadExports({}))
	Game = G
	G = ApiExports:LoadExports(G)

	return G
end

local a = { }

return mod
--[[
	Loads a set of modules, places their API exports in the Game object on __init
 ]]

local Game = _G.Game
assert(Game, "StdLib is running prior to LazyModules initialization\n\tOr LazyModules is not running as expected")

local mod = { }
local Libs = {
	Enums = Game.PreLoad(game.ReplicatedFirst.Util.Enums),
	Meta = Game.PreLoad(game.ReplicatedFirst.Util.Meta),
	Debug = Game.PreLoad(game.ReplicatedFirst.Util.Debug),
	Maskables = Game.PreLoad(game.ReplicatedFirst.Util.Maskables),
}

local APIUtils = require(game.ReplicatedFirst.Util.APIUtils)
local exports = APIUtils.EXPORT_LIST(Libs)
	:ADD("Enums")
	:ADD("Meta")
	:ADD("Debug")
	:ADD("Maskables")
	:ADD("empty_table", { })
	:ADD("no_op_func", function() end)

if game:GetService("RunService"):IsClient() then
	local mouse = game.Players.LocalPlayer:GetMouse()

	exports:ADD("ScreenSizeXRatio", mouse.ViewSizeX / 1920)
	exports:ADD("ScreenSizeYRatio", mouse.ViewSizeY / 1080)
else
	exports:ADD("ScreenSizeXRatio", 1)
	exports:ADD("ScreenSizeYRatio", 1)
end

function mod.LoadExports(G)
	APIUtils.LOAD_EXPORTS(Libs, Game)
	
	for i,v in Libs do
		if APIUtils.HAS_API_EXPORTS(v) then
			APIUtils.LOAD_EXPORTS(v, Game)
		end
	end
end

return mod
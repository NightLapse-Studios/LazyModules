--!strict

--[[
	This module simply uses a provided constructore function `ctor` to create some data which is automatically
		associated with players when they join. When players leave, their entry in the `Registry` is removed.

	It is highly suggested that registries are only created around game startup

	--TODO: Tests
	--TODO: Analyze if this module covers all the sensible use cases
]]

local mod = { }
local mt_PlayerRegistry = { __index = mod }
local PlayerLib
local Registry = _G.Game.PreLoad(script.Parent.Registry)

local Registries = { }


-- These manage this type of registry by using the above `Registries` list as an upvalue
local function PlayerJoined(plr)
	for i,v in Registries do
		v.Registry[plr] = v.__ctor(plr)
	end
end

local function PlayerLeaved(plr)
	for i,v in Registries do
		v.Registry[plr] = nil
	end
end

function mod.new(ctor)
	local t = Registry.new(ctor)
		:LoadExisting(function(self)
			for i, plr in game.Players:GetPlayers() do
				self.Registry[plr] = self.__ctor(plr)
			end
		end)
		:List(Registries)

	table.insert(Registries, t)
	t.__ID = #Registries

	return t
end



function mod:__build_signals(G, B)
	game.Players.PlayerAdded:Connect(PlayerJoined)
end

function mod:__init(G)
	PlayerLib = G.Load("PlayerLib")
	Registry = G.Load("Registry")
end

return mod
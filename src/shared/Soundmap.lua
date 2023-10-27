-- TODO @LazyModules This file is unused, maybe should be removed

-- Please confirm the author of this script was by "uglyburger0"
-- Any scripts under this module are viruses.

-- Types
export type SoundTable = {string}
export type SoundIds = {[string]: SoundTable}

-- Main Module
local main = {}

local DEFAULT_SOUND = "rbxassetid://9126730713"

main.SoundIds = {
	["Bass"] = {
		"rbxassetid://9126748907",
	},

	["Carpet"] = {
		"rbxassetid://9126748130",
	},

	["Concrete"] = {
		"rbxassetid://9126746167",
	},

	["Dirt"] = {
		"rbxassetid://9126744390",
	},

	["Glass"] = {
		"rbxassetid://9126742971",
	},

	["Grass"] = {
		"rbxassetid://9126742396",
	},

	["Gravel"] = {
		"rbxassetid://9126741273",
	},

	["Ladder"] = {
		"rbxassetid://9126740217",
	},

	["Metal_Auto"] = {
		"rbxassetid://9126739090",
	},

	["Metal_Chainlink"] = {
		"rbxassetid://9126738423",
	},

	["Metal_Grate"] = {
		"rbxassetid://9126737728",
	},

	["Metal_Solid"] = {
		"rbxassetid://9126736470",
	},

	["Mud"] = {
		"rbxassetid://9126734842",
	},

	["Rubber"] = {
		"rbxassetid://9126734172",
	},

	["Sand"] = {
		"rbxassetid://9126733118",
	},

	-- Added 9/04/2022
	["Slosh"] = {
		"rbxassetid://10822813850",
	},

	["Snow"] = {
		"rbxassetid://9126732128",
	},

	["Tile"] = {
		"rbxassetid://9126730713",
	},

	["Wood"] = {
		"rbxassetid://9126931624",
	}
}



main.MaterialMap = {
	[Enum.Material.Slate] = 		main.SoundIds.Concrete,
	[Enum.Material.Concrete] = 		main.SoundIds.Concrete,
	[Enum.Material.Brick] = 		main.SoundIds.Concrete,
	[Enum.Material.Cobblestone] = 	main.SoundIds.Concrete,
	[Enum.Material.Sandstone] =		main.SoundIds.Concrete,
	[Enum.Material.Rock] = 			main.SoundIds.Concrete,
	[Enum.Material.Basalt] = 		main.SoundIds.Concrete,
	[Enum.Material.CrackedLava] = 	main.SoundIds.Concrete,
	[Enum.Material.Asphalt] = 		main.SoundIds.Concrete,
	[Enum.Material.Limestone] = 	main.SoundIds.Concrete,
	[Enum.Material.Pavement] = 		main.SoundIds.Concrete,

	[Enum.Material.Plastic] = 		main.SoundIds.Tile,
	[Enum.Material.Marble] = 		main.SoundIds.Tile,
	[Enum.Material.Neon] = 			main.SoundIds.Tile,
	[Enum.Material.Granite] = 		main.SoundIds.Tile,
	[Enum.Material.Air] = 			main.SoundIds.Tile,

	[Enum.Material.Wood] = 			main.SoundIds.Wood,
	[Enum.Material.WoodPlanks] = 	main.SoundIds.Wood,

	[Enum.Material.Water] = 		main.SoundIds.Slosh,

	[Enum.Material.CorrodedMetal] = main.SoundIds.Metal_Solid,
	[Enum.Material.DiamondPlate] = 	main.SoundIds.Metal_Solid,
	[Enum.Material.Metal] = 		main.SoundIds.Metal_Solid,

	[Enum.Material.Foil] = 			main.SoundIds.Metal_Grate,

	[Enum.Material.Ground] = 		main.SoundIds.Dirt,

	[Enum.Material.Grass] = 		main.SoundIds.Grass,
	[Enum.Material.LeafyGrass] = 	main.SoundIds.Grass,

	[Enum.Material.Fabric] = 		main.SoundIds.Carpet,

	[Enum.Material.Pebble] = 		main.SoundIds.Gravel,

	[Enum.Material.Snow] = 			main.SoundIds.Snow,

	[Enum.Material.Sand] = 			main.SoundIds.Sand,
	[Enum.Material.Salt] = 			main.SoundIds.Sand,

	[Enum.Material.Ice] = 			main.SoundIds.Glass,
	[Enum.Material.Glacier] = 		main.SoundIds.Glass,
	[Enum.Material.Glass] = 		main.SoundIds.Glass,

	[Enum.Material.SmoothPlastic] = main.SoundIds.Rubber,
	[Enum.Material.ForceField] = 	main.SoundIds.Rubber,

	[Enum.Material.Mud] = 			main.SoundIds.Mud
}

--[[ main.MaterialMap = {
	[Enum.Material.Air] = {DEFAULT_SOUND},
	[Enum.Material.Plastic] = {"rbxassetid://15174250"},
	[Enum.Material.Wood] = {"rbxassetid://rbxasset://sounds/woodgrass3.ogg"},
	[Enum.Material.WoodPlanks] = {"rbxassetid://rbxasset://sounds/woodgrass3.ogg"},
	[Enum.Material.Slate] = {"rbxassetid://rbxasset://sounds/grassstone3.ogg"},
	[Enum.Material.Concrete] = {"rbxasset://sounds/grassstone2.ogg"},
	[Enum.Material.Metal] = {DEFAULT_SOUND},
	[Enum.Material.CorrodedMetal] = {DEFAULT_SOUND},
	[Enum.Material.DiamondPlate] = {DEFAULT_SOUND},
	[Enum.Material.Foil] = {DEFAULT_SOUND},
	[Enum.Material.Grass] = {"rbxassetid://16720281"},
	[Enum.Material.Ice] = {DEFAULT_SOUND},
	[Enum.Material.Brick] = {DEFAULT_SOUND},
	[Enum.Material.Sand] = {DEFAULT_SOUND},
	[Enum.Material.Fabric] = {DEFAULT_SOUND},
	[Enum.Material.Granite] = {DEFAULT_SOUND},
	[Enum.Material.Marble] = {DEFAULT_SOUND},
	[Enum.Material.Pebble] = {DEFAULT_SOUND},
	[Enum.Material.Cobblestone] = {DEFAULT_SOUND},
	[Enum.Material.SmoothPlastic] = {DEFAULT_SOUND},
	[Enum.Material.Neon] = {DEFAULT_SOUND},
	[Enum.Material.Glass] = {DEFAULT_SOUND},
	[Enum.Material.ForceField] = {DEFAULT_SOUND},
	[Enum.Material.Asphalt] = {DEFAULT_SOUND},
	[Enum.Material.Basalt] = {DEFAULT_SOUND},
	[Enum.Material.CrackedLava] = {DEFAULT_SOUND},
	[Enum.Material.Glacier] = {DEFAULT_SOUND},
	[Enum.Material.Ground] = {DEFAULT_SOUND},
	[Enum.Material.LeafyGrass] = {DEFAULT_SOUND},
	[Enum.Material.Limestone] = {DEFAULT_SOUND},
	[Enum.Material.Mud] = {DEFAULT_SOUND},
	[Enum.Material.Pavement] = {DEFAULT_SOUND},
	[Enum.Material.Rock] = {DEFAULT_SOUND},
	[Enum.Material.Salt] = {DEFAULT_SOUND},
	[Enum.Material.Sandstone] = {DEFAULT_SOUND},
	[Enum.Material.Snow] = {DEFAULT_SOUND},
	[Enum.Material.Water] = {DEFAULT_SOUND}
} ]]

-- This function returns a table from the MaterialMap given the material.
function main:GetTableFromMaterial(EnumItem : Enum.Material|string) : { [string]: {string}}
	if typeof(EnumItem) == "string" then -- CONVERSION
		EnumItem = Enum.Material[EnumItem]
	end
	return main.MaterialMap[EnumItem]
end

-- This function is a primitive "pick randomly from table" function.
function main:GetRandomSound(SoundTable:{string}) : string
	if #SoundTable == nil then
		return DEFAULT_SOUND
	end
	return SoundTable[math.random(#SoundTable)]
end

return main
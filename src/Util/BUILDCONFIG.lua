
local RunService = game:GetService("RunService")
local IsStudio = RunService:IsStudio()

local config = { }

--=============================================--
--=                                           =--
--=           LazyModules variables           =--
--=                                           =--
--=============================================--

-- Run lazymodules tests stage
config.TESTING = true
config.FocusTestOn = "Main"

-- The `Load` tree
config.LogLoads = false
config.LogPreLoads = false
-- Files which are not in the `Game` object
config.LogReallyLazyLoads = false
-- Files which are not in the `Game` object and could not be found by LazyModules
config.LogUnfoundLoads = false
config.LogUIInit = false
config.LogSearchResults = false

config.LogNewAbilities = false
config.FreePowerUps = if not IsStudio then false else true

-- UserInput handlers
config.LogInputListeners = false
config.LogInputProcessing = false
-- List of filtering criteria to make the above logs less noisy
-- A value of true means the input will not be logged
config.LogInputProcessingFilters = {
    UserInputType = {
        [2001] = true, -- Gestures
        [Enum.UserInputType.MouseMovement] = true,
        [Enum.UserInputType.TextInput] = true
    },
    KeyCode = {

    }
}

config.ModuleCollectionFolders = {
    game.ReplicatedFirst.Util,
    game.ReplicatedFirst.Modules,
    if RunService:IsServer() then game.ServerScriptService else game.StarterPlayer.StarterPlayerScripts
}
config.ModuleCollectionBlacklist = {
    game.ReplicatedFirst.Modules.Roact,
    game.ReplicatedFirst.Util.LazyModules,
    Server = {
        game.ReplicatedFirst.Modules.GUI
    },
    Client = {
        
    }
}



--=============================================--
--=                                           =--
--=          Runtime debug features           =--
--=                                           =--
--=============================================--

-- Debug hooks features for adjusting values at runtime from DebugMenu
config.VolumeOverrides = if not IsStudio then false else false

config.TestMap = if not IsStudio then false else false



--=============================================--
--=                                           =--
--=          Runtime configuration            =--
--=                                           =--
--=============================================--
-- Must point to the one main place, no matter what.
config.PlaceId = 8256020164
config.MaxPlayers = 35
config.GroupID = 5418470

return config
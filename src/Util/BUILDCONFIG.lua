
local RunService = game:GetService("RunService")
local IsStudio = RunService:IsStudio()

local config = { }


--=============================================--
--=                                           =--
--=          Runtime configuration            =--
--=                                           =--
--=============================================--
-- Must point to the one main place, no matter what.
config.PlaceId = 8256020164
config.TestPlaceId = 13489727259
config.MaxPlayers = 35
config.GroupID = 5418470

config.AnimationFadeTime = 0.1

-- Set up ContextVar for StdLib
-- This file can't rely on StdLib so functions it needs from StdLib are actually defined here and StdLib will load them
do
    -- Fun optimization to make the function never have to check values
    -- Instead, we give each path of the ContextVar function an equivalent function here, and set the exposed func to it
    local function return_prod_value(prod, _, _, _)
        return prod
    end
    local function return_debug_value(_, debug, _, _)
        return debug
    end
    local function return_test_realm_value(_, _, test_realm, _)
        return test_realm
    end
    local function return_other_value(_, _, _, other)
        return other
    end

    local function __context_var(prod, debug, test_realm, other)
        if IsStudio then
            return return_debug_value
        elseif config.TestPlaceId == game.PlaceId then
            return return_test_realm_value
        elseif config.PlaceId == game.PlaceId then
            return return_prod_value
        else
            return return_other_value
        end
    end

    config.ContextVar = __context_var()
end

local ContextVar = config.ContextVar

-- This won't work unless you are also doing device test in studio
-- However some things rely on this flag alone, so the game will be in an undefined-ish state if set true and not doing device emulation
config.EmulateMobile = ContextVar(false, false, false, false)

do
    local function return_mobile_value(_, mobile)
        return mobile 
    end
    local function return_desktop_value(desktop, _)
        return desktop 
    end

    local UserInputService = game:GetService("UserInputService")
    local function __platform_var(desktop, mobile)
        if (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) or config.EmulateMobile then
            return return_mobile_value
        else
            return return_desktop_value
        end
    end

    config.PlatformVar = __platform_var()
end



--=============================================--
--=                                           =--
--=           LazyModules variables           =--
--=                                           =--
--=============================================--

-- Run lazymodules tests stage
config.TESTING = false
-- Optional string, a module name
config.FocusTestOn = false

-- The `Load` tree
config.LogLoads = false
config.LogPreLoads = false
config.LogUIInit = false

-- Log when a network signal is fired (Signals.Monitor(...Signals) can be used for individual events)
config.MonitorAllSignals = false

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
        game.ReplicatedFirst.Modules.GUI,
        game.ReplicatedFirst.Util.UserInput
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
config.VolumeOverrides = ContextVar(false, true, false, false)

return config
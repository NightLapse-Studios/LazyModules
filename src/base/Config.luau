
local RunService = game:GetService("RunService")
local IsStudio = RunService:IsStudio()

local Config = { }

Config.PlaceId = 17373496574
Config.TestPlaceId = 13489727259

-- Set up ContextVar for StdLib
-- This file can't rely on StdLib so functions it needs from StdLib are actually defined here and StdLib will load them
-- I don't like having to do this here, but this file shouldn't need anything else from StdLib ever (hopefully)
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
        elseif Config.TestPlaceId == game.PlaceId then
            return return_test_realm_value
        elseif Config.PlaceId == game.PlaceId then
            return return_prod_value
        else
            return return_other_value
        end
    end

    Config.ContextVar = __context_var()
end

local ContextVar = Config.ContextVar

-- This won't work unless you are also doing device test in studio
-- However some things rely on this flag alone, so the game will be in an undefined-ish state if set true and not doing device emulation
Config.EmulateMobile = ContextVar(false, false, false, false)

do
    local function return_mobile_value(_, mobile)
        return mobile 
    end
    local function return_desktop_value(desktop, _)
        return desktop 
    end

    local UserInputService = game:GetService("UserInputService")
    local function __platform_var(desktop, mobile)
        if (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) or Config.EmulateMobile then
            return return_mobile_value
        else
            return return_desktop_value
        end
    end

    Config.PlatformVar = __platform_var()
end


--=============================================--
--=                                           =--
--=          Runtime configuration            =--
--=                                           =--
--=============================================--

-- Must point to the one main place, no matter what.
Config.MaxPlayers = 35
Config.GroupID = 5418470

Config.AnimationFadeTime = 0.1

Config.BaseWalkSpeed = ContextVar(12, 12, 12, 12)
Config.Gravity = Vector3.new(0, -32.2, 0)-- Bullets



--=============================================--
--=                                           =--
--=           LazyModules variables           =--
--=                                           =--
--=============================================--

-- Run lazymodules tests stage
Config.TESTING = false
-- Optional string, a module name
Config.FocusTestOn = false

-- The `Load` tree
Config.LogLoads = false
Config.LogLMRequires = false
Config.LogUIInit = false

-- Log when a network signal is fired (Signals.Monitor(...Signals) can be used for individual events)
Config.MonitorAllSignals = false

-- UserInput handlers
Config.LogInputListeners = false
Config.LogInputProcessing = false
-- List of filtering criteria to make the above logs less noisy
-- A value of true means the input will not be logged
Config.LogInputProcessingFilters = {
    UserInputType = {
        [2001] = true, -- Gestures
        [Enum.UserInputType.MouseMovement] = true,
        [Enum.UserInputType.TextInput] = true
    },
    KeyCode = {

    }
}

Config.ModuleCollectionFolders = {
    game.ReplicatedFirst.Lib,
    game.ReplicatedFirst.Modules,
    if RunService:IsServer() then game.ServerScriptService else game.StarterPlayer.StarterPlayerScripts
}
Config.ModuleCollectionBlacklist = {
    game.ReplicatedFirst.Lib.LazyModules,
    Server = {
		game.ReplicatedFirst.Lib.Pumpkin
	},
    Client = {
		game.StarterPlayer.StarterPlayerScripts:WaitForChild("PlayerModule"),
		game.ReplicatedFirst.Lib.Pumpkin
    }
}

Config.ReleaseType = "base"



--=============================================--
--=                                           =--
--=          Runtime debug features           =--
--=                                           =--
--=============================================--

-- Debug hooks features for adjusting values at runtime from DebugMenu
Config.VolumeOverrides = ContextVar(false, true, false, false)

Config.SaveDatastoresInStudio = true

return Config
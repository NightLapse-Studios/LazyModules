--!strict

local Enums = { }

export type InputGesture =
	{ Name: "Left", Value: number } |
	{ Name: "Right", Value: number } |
	{ Name: "Up", Value: number } |
	{ Name: "Down", Value: number } |
	{ Name: "None", Value: number }

local InputGestures: {
	Left: InputGesture,
	Right: InputGesture,
	Up: InputGesture,
	Down: InputGesture,
	None: InputGesture,
} = {
	Left = { Name = "Left", Value = 800 },
	Right = { Name = "Right", Value = 801 },
	Up = { Name = "Up", Value = 802 },
	Down = { Name = "Down", Value = 803 },
	None = { Name = "None", Value = 804 },
}
Enums.InputGestures = InputGestures

export type AuxKeyCode =
	{ Name: "Any", Value: number }

export type AuxInputGesture =
	{ Name: "Any", Value: number } |
	{ Name: "Total", Value: number } |
	{ Name: "Last", Value: number }

export type AuxCode = AuxKeyCode | AuxInputGesture

local AuxKeyCodes: {
	Any: AuxKeyCode,	
} = {
	Any = { Name = "Any", Value = 901 },
}
local AuxInputGestures: {
	Any: AuxInputGesture,
	Total: AuxInputGesture,
	Last: AuxInputGesture,
} = {
	Any = { Name = "Any", Value = 1001 },
	Total = { Name = "Total", Value = 1002 },
	Last = { Name = "Last", Value = 1003 },
}
Enums.AuxInputCodes = { AuxKeyCodes = AuxKeyCodes, AuxInputGestures = AuxInputGestures }

export type DataStoreName =
	{ Name: "Players", Value: "Players" } |
	{ Name: "TestStore", Value: "TestStore" }

local DataStoreNames: {
	Players: DataStoreName,
	Test: DataStoreName,
} = {
	Players = { Name = "Players", Value = "Players" },
	Test = { Name = "TestStore", Value = "TestStore" }
}
Enums.DataStores = DataStoreNames

-- Stack-based list of contexts
-- There are brief ones and lasting ones, the brief ones are reset once the context wraps up
-- wheras the lasting ones are set permenantly prior to the associated brief contexts being used
-- Mostly for internal soundness checking
--
-- Also allows a thread from some stage to wait for specific stages to pass
-- 	for example loading players takes time and is "done" at known stages on client
--
-- This enum must be numerically sorted acording to the order the steps are executed

export type LoadingContext =
	{ Name: "UNSET", Value: number } |
	{ Name: "COLLECTION", Value: number } |
	{ Name: "REQUIRE", Value: number } |
	{ Name: "COLLECTED", Value: number } |
	{ Name: "RUNNING_STAGES", Value: number } |
	{ Name: "FINISHED", Value: number }

local LoadingContexts: {
	UNSET: LoadingContext,
	COLLECTION: LoadingContext,
	REQUIRE: LoadingContext,
	COLLECTED: LoadingContext,
	RUNNING_STAGES: LoadingContext,
	FINISHED: LoadingContext,
} = {
	UNSET = { Name = "UNSET", Value = -1 },
	COLLECTION = { Name = "COLLECTION", Value = 1 },
	REQUIRE = { Name = "REQUIRE", Value = 2 },
	COLLECTED = { Name = "COLLECTED", Value = 3 },
	RUNNING_STAGES = { Name = "RUNNING_STAGES", Value = 4 },
	FINISHED = { Name = "FINISHED", Value = 1000 }
}
Enums.LoadingContexts = LoadingContexts

export type MetaContext = 
	{ Name: "CLIENT", Value: number } |
	{ Name: "SERVER", Value: number } |
	{ Name: "AUTO", Value: number } |
	{ Name: "BOTH", Value: number }

local MetaContexts: {
	CLIENT: MetaContext,
	SERVER: MetaContext,
	AUTO: MetaContext,
	BOTH: MetaContext,
	[number]: string?,
} = {
	CLIENT = { Name = "CLIENT", Value = 1 },
	SERVER = { Name = "SERVER", Value = 2 },
	AUTO = { Name = "AUTO", Value = 3 },
	BOTH = { Name = "BOTH", Value = 4 },
	[1] = "CLIENT",
	[2] = "SERVER",
	[3] = "AUTO",
	[4] = "BOTH",
}
Enums.MetaContexts = MetaContexts

export type UserInputType2 =
	{ Name: "Gesture", Value: number } |
	{ Name: "DPad", Value: number }

local UserInputType: {
	Gesture: UserInputType2,
	DPad: UserInputType2,	
} = {
	Gesture = { Name = "Gesture", Value = 2001 },
	DPad = { Name = "DPad", Value = 2002 },
}
Enums.UserInputType = UserInputType

-- TODO: Reimplement this functionality
export type GestureDisplayMode =
	{ Name: "Off", Value: number } |
	{ Name: "Last", Value: number } |
	{ Name: "Temp", Value: number }

local GestureDisplayMode: {
	Off: GestureDisplayMode,
	Last: GestureDisplayMode,
	Temp: GestureDisplayMode,	
} = {
	Off = { Name = "Off", Value = 1 },
	Last = { Name = "Last", Value = 2 },
	Temp = { Name = "Temp", Value = 3 },
}
Enums.GestureDisplayMode = GestureDisplayMode

local AllInputs = { }
Enums.AllInputs = AllInputs

for _, enums in Enum:GetEnums() do
	local items = enums:GetEnumItems()
	local enum_name = tostring(enums)

	Enums[enum_name] = Enums[enum_name] or table.create(#items)
	local these_enums = Enums[enum_name]

	for _, item in enums:GetEnumItems() do
		these_enums[item.Name] = item
	end
end

export type CameraMode =
	{ Name: "TopDownOrbital", Value: number } |
	{ Name: "ThirdPerson", Value: number } |
	{ Name: "FirstPerson", Value: number }

local CameraMode: {
	TopDownOrbital: CameraMode,
	ThirdPerson: CameraMode,
	FirstPerson: CameraMode
} = {
	TopDownOrbital = { Name = "TopDownOrbital", Value = 1 },
	ThirdPerson = { Name = "ThirdPerson", Value = 2 },
	FirstPerson = { Name = "FirstPerson", Value = 3 },
}
Enums.CameraMode = CameraMode

export type LookAlignment =
	{ Name: "AimFollowsCamera", Value: number } |
	{ Name: "AimFollowsMouseHit", Value: number } |
	{ Name: "CharacterFollowsCamera", Value: number } |
	{ Name: "CharacterFollowsMouseHit", Value: number } |
	{ Name: "None", Value: number } |
	{ Name: "CharacterFollowsCallback", Value: number } |
	{ Name: "AbsolutelyNone", Value: number }

local LookAlignment: {
	AimFollowsCamera: LookAlignment,
	AimFollowsMouseHit: LookAlignment,
	CharacterFollowsMouseHit: LookAlignment,
	CharacterFollowsCamera: LookAlignment,
	None: LookAlignment,
	CharacterFollowsCallback: LookAlignment,
	AbsolutelyNone: LookAlignment
} = {
	AimFollowsCamera = { Name = "AimFollowsCamera", Value = 1},
	AimFollowsMouseHit = { Name = "AimFollowsMouseHit", Value = 2},
	CharacterFollowsCamera = { Name = "CharacterFollowsCamera", Value = 3},
	CharacterFollowsMouseHit = { Name = "CharacterFollowsMouseHit", Value = 7},
	CharacterFollowsCallback = { Name = "CharacterFollowsCallback", Value = 4},
	None = { Name = "None", Value = 5},
	AbsolutelyNone = { Name = "AbsolutelyNone", Value = 6}
}
Enums.LookAlignment = LookAlignment

export type KeyboardLayout = 
	{ Name: "QWERTY", Value: number } |
	{ Name: "Dvorak", Value: number }

local KeyboardLayout: {
	QWERTY: KeyboardLayout,
	Dvorak: KeyboardLayout
} = {
	QWERTY = { Name = "QWERTY", Value = 1},
	Dvorak = { Name = "Dvorak", Value = 2},
}
Enums.KeyboardLayout = KeyboardLayout

for _, v in pairs(Enum.KeyCode:GetEnumItems())do
	Enums.AllInputs[ string.split(tostring(v), ".")[3] ] = v
end
for _, v in pairs(Enum.UserInputType:GetEnumItems())do
	Enums.AllInputs[ string.split(tostring(v), ".")[3] ] = v
end
Enums.AllInputs.Unknown = nil

return Enums

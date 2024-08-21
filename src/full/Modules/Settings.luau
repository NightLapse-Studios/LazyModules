--!strict

local LMT = require(game.ReplicatedFirst.Lib.LMTypes)
local Game: LMT.LMGame = _G.Game
local Enums = require(game.ReplicatedFirst.Lib.Enums)
local Roact = require(game.ReplicatedFirst.Lib.Pumpkin.lib.Roact)
local Signal = require(game.ReplicatedFirst.Lib.ClassicSignal)
local Signals = require(game.ReplicatedFirst.Lib.Signals)
local PlrObjs = require(game.ReplicatedFirst.Modules.Players).Objects

local SettingChangedTransmitter = Signals.NewTransmitter("SettingChangedTransmitter")
	:UpConnectionType(function(plr, name: string, value: any) end)

local mod = { }

local DecodeBinding = {
	["KC.None"] = Enum.UserInputType.None,
	["KC.Esc"] = Enum.KeyCode.Escape,
	["KC.F1"] = Enum.KeyCode.F1,
	["KC.F2"] = Enum.KeyCode.F2,
	["KC.F3"] = Enum.KeyCode.F3,
	["KC.F4"] = Enum.KeyCode.F4,
	["KC.F5"] = Enum.KeyCode.F5,
	["KC.F6"] = Enum.KeyCode.F6,
	["KC.F7"] = Enum.KeyCode.F7,
	["KC.F8"] = Enum.KeyCode.F8,
	["KC.F9"] = Enum.KeyCode.F9,
	["KC.F10"] = Enum.KeyCode.F10,
	["KC.F11"] = Enum.KeyCode.F11,
	["KC.F12"] = Enum.KeyCode.F12,
	["KC.~"] = Enum.KeyCode.Tilde,
	["KC.1"] = Enum.KeyCode.One,
	["KC.2"] = Enum.KeyCode.Two,
	["KC.3"] = Enum.KeyCode.Three,
	["KC.4"] = Enum.KeyCode.Four,
	["KC.5"] = Enum.KeyCode.Five,
	["KC.6"] = Enum.KeyCode.Six,
	["KC.7"] = Enum.KeyCode.Seven,
	["KC.8"] = Enum.KeyCode.Eight,
	["KC.9"] = Enum.KeyCode.Nine,
	["KC.0"] = Enum.KeyCode.Zero,
	["KC.-"] = Enum.KeyCode.Minus,
	["KC.="] = Enum.KeyCode.Equals,
	["KC.Bksp"] = Enum.KeyCode.Backspace,
	["KC.Tab"] = Enum.KeyCode.Tab,
	["KC.Q"] = Enum.KeyCode.Q,
	["KC.W"] = Enum.KeyCode.W,
	["KC.E"] = Enum.KeyCode.E,
	["KC.R"] = Enum.KeyCode.R,
	["KC.T"] = Enum.KeyCode.T,
	["KC.Y"] = Enum.KeyCode.Y,
	["KC.U"] = Enum.KeyCode.U,
	["KC.I"] = Enum.KeyCode.I,
	["KC.O"] = Enum.KeyCode.O,
	["KC.P"] = Enum.KeyCode.P,
	["KC.["] = Enum.KeyCode.LeftBracket,
	["KC.]"] = Enum.KeyCode.RightBracket,
	["KC.\\"] = Enum.KeyCode.BackSlash,
	["KC.Caps"] = Enum.KeyCode.CapsLock,
	["KC.A"] = Enum.KeyCode.A,
	["KC.S"] = Enum.KeyCode.S,
	["KC.D"] = Enum.KeyCode.D,
	["KC.F"] = Enum.KeyCode.F,
	["KC.G"] = Enum.KeyCode.G,
	["KC.H"] = Enum.KeyCode.H,
	["KC.J"] = Enum.KeyCode.J,
	["KC.K"] = Enum.KeyCode.K,
	["KC.L"] = Enum.KeyCode.L,
	["KC.;"] = Enum.KeyCode.Semicolon,
	["KC.'"] = Enum.KeyCode.Quote,
	["KC.->"] = Enum.KeyCode.Return,
	["KC.Z"] = Enum.KeyCode.Z,
	["KC.X"] = Enum.KeyCode.X,
	["KC.C"] = Enum.KeyCode.C,
	["KC.V"] = Enum.KeyCode.V,
	["KC.B"] = Enum.KeyCode.B,
	["KC.N"] = Enum.KeyCode.N,
	["KC.M"] = Enum.KeyCode.M,
	["KC.,"] = Enum.KeyCode.Comma,
	["KC.."] = Enum.KeyCode.Period,
	["KC./"] = Enum.KeyCode.Slash,
	["KC.LShft"] = Enum.KeyCode.LeftShift,
	["KC.RShft"] = Enum.KeyCode.RightShift,
	["KC.LCtrl"] = Enum.KeyCode.LeftControl,
	["KC.LSuper"] = Enum.KeyCode.LeftSuper,
	["KC.LAlt"] = Enum.KeyCode.LeftAlt,
	["KC.Space"] = Enum.KeyCode.Space,
	["KC.RAlt"] = Enum.KeyCode.RightAlt,
	["KC.RSuper"] = Enum.KeyCode.RightSuper,
	["KC.Menu"] = Enum.KeyCode.Menu,
	["KC.RCtrl"] = Enum.KeyCode.RightControl,
	["IT.LMB"] = Enum.UserInputType.MouseButton1,
	["IT.RMB"] = Enum.UserInputType.MouseButton2,
}

local EncodeBinding = {
	[Enum.UserInputType.None] = "KC.None",
	[Enum.KeyCode.Escape] = "KC.Esc",
	[Enum.KeyCode.F1] = "KC.F1",
	[Enum.KeyCode.F2] = "KC.F2",
	[Enum.KeyCode.F3] = "KC.F3",
	[Enum.KeyCode.F4] = "KC.F4",
	[Enum.KeyCode.F5] = "KC.F5",
	[Enum.KeyCode.F6] = "KC.F6",
	[Enum.KeyCode.F7] = "KC.F7",
	[Enum.KeyCode.F8] = "KC.F8",
	[Enum.KeyCode.F9] = "KC.F9",
	[Enum.KeyCode.F10] = "KC.F10",
	[Enum.KeyCode.F11] = "KC.F11",
	[Enum.KeyCode.F12] = "KC.F12",
	[Enum.KeyCode.Tilde] = "KC.~",
	[Enum.KeyCode.One] = "KC.1",
	[Enum.KeyCode.Two] = "KC.2",
	[Enum.KeyCode.Three] = "KC.3",
	[Enum.KeyCode.Four] = "KC.4",
	[Enum.KeyCode.Five] = "KC.5",
	[Enum.KeyCode.Six] = "KC.6",
	[Enum.KeyCode.Seven] = "KC.7",
	[Enum.KeyCode.Eight] = "KC.8",
	[Enum.KeyCode.Nine] = "KC.9",
	[Enum.KeyCode.Zero] = "KC.0",
	[Enum.KeyCode.Minus] = "KC.-",
	[Enum.KeyCode.Equals] = "KC.=",
	[Enum.KeyCode.Backspace] = "KC.Bksp",
	[Enum.KeyCode.Tab] = "KC.Tab",
	[Enum.KeyCode.Q] = "KC.Q",
	[Enum.KeyCode.W] = "KC.W",
	[Enum.KeyCode.E] = "KC.E",
	[Enum.KeyCode.R] = "KC.R",
	[Enum.KeyCode.T] = "KC.T",
	[Enum.KeyCode.Y] = "KC.Y",
	[Enum.KeyCode.U] = "KC.U",
	[Enum.KeyCode.I] = "KC.I",
	[Enum.KeyCode.O] = "KC.O",
	[Enum.KeyCode.P] = "KC.P",
	[Enum.KeyCode.LeftBracket] = "KC.[",
	[Enum.KeyCode.RightBracket] = "KC.]",
	[Enum.KeyCode.BackSlash] = "KC.\\",
	[Enum.KeyCode.CapsLock] = "KC.Caps",
	[Enum.KeyCode.A] = "KC.A",
	[Enum.KeyCode.S] = "KC.S",
	[Enum.KeyCode.D] = "KC.D",
	[Enum.KeyCode.F] = "KC.F",
	[Enum.KeyCode.G] = "KC.G",
	[Enum.KeyCode.H] = "KC.H",
	[Enum.KeyCode.J] = "KC.J",
	[Enum.KeyCode.K] = "KC.K",
	[Enum.KeyCode.L] = "KC.L",
	[Enum.KeyCode.Semicolon] = "KC.;",
	[Enum.KeyCode.Quote] = "KC.'",
	[Enum.KeyCode.Return] = "KC.->",
	[Enum.KeyCode.Z] = "KC.Z",
	[Enum.KeyCode.X] = "KC.X",
	[Enum.KeyCode.C] = "KC.C",
	[Enum.KeyCode.V] = "KC.V",
	[Enum.KeyCode.B] = "KC.B",
	[Enum.KeyCode.N] = "KC.N",
	[Enum.KeyCode.M] = "KC.M",
	[Enum.KeyCode.Comma] = "KC.,",
	[Enum.KeyCode.Period] = "KC..",
	[Enum.KeyCode.Slash] = "KC./",
	[Enum.KeyCode.LeftShift] = "KC.LShft",
	[Enum.KeyCode.RightShift] = "KC.RShft",
	[Enum.KeyCode.LeftControl] = "KC.LCtrl",
	[Enum.KeyCode.LeftSuper] = "KC.LSuper",
	[Enum.KeyCode.LeftAlt] = "KC.LAlt",
	[Enum.KeyCode.Space] = "KC.Space",
	[Enum.KeyCode.RightAlt] = "KC.RAlt",
	[Enum.KeyCode.RightSuper] = "KC.RSuper",
	[Enum.KeyCode.Menu] = "KC.Menu",
	[Enum.KeyCode.RightControl] = "KC.RCtrl",
	[Enum.UserInputType.MouseButton1] = "IT.LMB",
	[Enum.UserInputType.MouseButton2] = "IT.RMB",
}

mod.Settings = {
	EffectsAudioVolume = {
		Order = 1,
		Type = "NumberSlider",
		DisplayStr = "Effects Volume",
		CorrespondingEnum = false,
		EnumOrder = { },
		CorrespondingStat = "EffectsVolumeSetting",
		Binding = { Roact.createBinding(1.0) },
		OnChange = Signal.new(),
	},
	MusicAudioVolume = {
		Order = 2,
		Type = "NumberSlider",
		DisplayStr = "Music Volume",
		CorrespondingEnum = false,
		EnumOrder = { },
		CorrespondingStat = "MusicVolumeSetting",
		Binding = { Roact.createBinding(1.0) },
		OnChange = Signal.new(),
	},
	KeyboardLayout = {
		Order = "Custom",
		Type = "EnumCyclerButton",
		DisplayStr = "Keyboard Layout",
		CorrespondingEnum = Enums.KeyboardLayout,
		EnumOrder = { Enums.KeyboardLayout.QWERTY, Enums.KeyboardLayout.Dvorak },
		CorrespondingStat = "KeyboardLayoutSetting",
		Binding = { Roact.createBinding(Enums.KeyboardLayout.QWERTY) },
		OnChange = Signal.new(),
	},
	MoveLeftBinding = {
		Order = 1,
		Type = "KeyBinding",
		DisplayStr = "Move Left",
		CorrespondingEnum = false,
		EnumOrder = { },
		CorrespondingStat = "MoveLeftBinding",
		Binding = { Roact.createBinding(Enum.KeyCode.A) },
		OnChange = Signal.new()
	},
	MoveRightBinding = {
		Order = 2,
		Type = "KeyBinding",
		DisplayStr = "Move Right",
		CorrespondingEnum = false,
		EnumOrder = { },
		CorrespondingStat = "MoveRightBinding",
		Binding = { Roact.createBinding(Enum.KeyCode.D) },
		OnChange = Signal.new()
	},
	MoveBackBinding = {
		Order = 3,
		Type = "KeyBinding",
		DisplayStr = "Move Back",
		CorrespondingEnum = false,
		EnumOrder = { },
		CorrespondingStat = "MoveBackBinding",
		Binding = { Roact.createBinding(Enum.KeyCode.S) },
		OnChange = Signal.new()
	},
	MoveForwardBinding = {
		Order = 4,
		Type = "KeyBinding",
		DisplayStr = "Move Forward",
		CorrespondingEnum = false,
		EnumOrder = { },
		CorrespondingStat = "MoveForwardBinding",
		Binding = { Roact.createBinding(Enum.KeyCode.W) },
		OnChange = Signal.new()
	},
	SwitchCameraLeftBinding = {
		Order = 5,
		Type = "KeyBinding",
		DisplayStr = "Switch Camera Left",
		CorrespondingEnum = false,
		EnumOrder = { },
		CorrespondingStat = "SwitchCameraLeftBinding",
		Binding = { Roact.createBinding(Enum.KeyCode.Q) },
		OnChange = Signal.new()
	},
	SwitchCameraRightBinding = {
		Order = 6,
		Type = "KeyBinding",
		DisplayStr = "Switch Camera Right",
		CorrespondingEnum = false,
		EnumOrder = { },
		CorrespondingStat = "SwitchCameraRightBinding",
		Binding = { Roact.createBinding(Enum.KeyCode.E) },
		OnChange = Signal.new()
	},
	UnlockMouseBinding = {
		Order = 7,
		Type = "KeyBinding",
		DisplayStr = "Unlock Mouse",
		CorrespondingEnum = false,
		EnumOrder = { },
		CorrespondingStat = "UnlockMouseBinding",
		Binding = { Roact.createBinding(Enum.KeyCode.LeftControl) },
		OnChange = Signal.new()
	},
	JumpBinding = {
		Order = 13,
		Type = "KeyBinding",
		DisplayStr = "Jump",
		CorrespondingEnum = false,
		EnumOrder = { },
		CorrespondingStat = "JumpBinding",
		Binding = { Roact.createBinding(Enum.KeyCode.Space) },
		OnChange = Signal.new()
	},
	SprintBinding = {
		Order = 14,
		Type = "KeyBinding",
		DisplayStr = "Sprint",
		CorrespondingEnum = false,
		EnumOrder = { },
		CorrespondingStat = "SprintBinding",
		Binding = { Roact.createBinding(Enum.KeyCode.LeftShift) },
		OnChange = Signal.new()
	},
	PlayerListBinding = {
		Order = 15,
		Type = "KeyBinding",
		DisplayStr = "Toggle Player List",
		CorrespondingEnum = false,
		EnumOrder = { },
		CorrespondingStat = "PlayerListBinding",
		Binding = { Roact.createBinding(Enum.KeyCode.Tab) },
		OnChange = Signal.new()
	},
}

local EncodedSettings = {
	MoveLeftBinding = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	MoveRightBinding = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	MoveBackBinding = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	MoveForwardBinding = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	SwitchCameraLeftBinding = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	SwitchCameraRightBinding = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	WeaponPrimaryBinding = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	WeaponSecondaryBinding = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	BuildModeBinding = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	UnlockMouseBinding = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	CycleBuildingLeftBinding = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	CycleBuildingRightBinding = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	PlayerListBinding = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	EmotesBinding = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	UnequipAllBinding = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	JumpBinding = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	SprintBinding = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	WeaponSlot1 = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	WeaponSlot2 = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	WeaponSlot3 = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	WeaponSlot4 = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	WeaponSlot5 = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	WeaponSlot6 = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	WeaponSlot7 = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	WeaponSlot8 = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	WeaponSlot9 = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	UsePowerUp1 = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	UsePowerUp2 = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	UsePowerUp3 = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	UsePowerUp4 = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
	SpotEnemyBinding = {
		Encode = EncodeBinding,
		Decode = DecodeBinding
	},
}

mod.EncodedSettings = EncodedSettings

mod.KeyBindings = { }
for i,v in mod.Settings do
	if v.Type == "KeyBinding" then
		mod.KeyBindings[i] = v
	end

	assert(v.Order)
	assert(v.Type)
	-- This assertion is easier to understand than the resulting error that PlayerStats will throw
	assert(v.CorrespondingStat)
	assert(v.Binding)
	assert(v.EnumOrder)
	assert(v.OnChange)
	assert(v.DisplayStr)
end

for i,v in EncodeBinding do
	assert(DecodeBinding[v] == i, i.Name .. " " .. v)
end
for i,v in DecodeBinding do
	assert(EncodeBinding[v] == i, i .. " " .. v.Name)
end

function mod.DecodeKeyBinding(str: string): Enum.KeyCode|Enum.UserInputType
	return DecodeBinding[str]
end

function mod.EncodeKeyBinding(enum: Enum.KeyCode|Enum.UserInputType): string
	return EncodeBinding[enum]
end

function mod.GetSetting(name)
	local setting = mod.Settings[name]
	assert(setting)
	
	return setting.Binding[1]:getValue()
end

function mod.ChangeSetting(plr: Player?, name: string, value, opt_dont_transmit: boolean?)
	local setting = mod.Settings[name]
	assert(setting)

	if setting.Type == "EnumCyclerButton" then
		if typeof(setting.EnumOrder[value]) ~= "string" then
			value = setting.CorrespondingStat.DefaultValue
		end
	elseif setting.Type == "NumberSlider" then
		if typeof(value) ~= "number" or value ~= value then
			value = setting.CorrespondingStat.DefaultValue
		end
	elseif setting.Type == "Toggle" then
		if typeof(value) ~= "boolean" then
			value = setting.CorrespondingStat.DefaultValue
		end
	end

	local old = setting.Binding[1]:getValue()
	setting.Binding[2](value)
	setting.OnChange:Fire(plr, old, value)

	if Game.CONTEXT == "CLIENT" then
		if not opt_dont_transmit then
			SettingChangedTransmitter:TransmitUp(name, value)
		end
	end
	
	-- Encodings only affect the storage in stats
	if EncodedSettings[name] then
		local new_value = EncodedSettings[name].Encode[value]
		assert(new_value, value)
		value = new_value
	end

	PlrObjs[plr].Stats:ChangePermStat(setting.CorrespondingStat, value, "set")
end

function mod.OnChange(name: string)
	local setting = mod.Settings[name]
	assert(setting)

	return setting.OnChange
end

function mod.__init(G: LMT.LMGame)
	for setting_name, setting in mod.Settings do
		setting.Name = setting_name
		if setting.Type == "EnumCyclerButton" then
			for enum_name, value in setting.CorrespondingEnum do
				setting.EnumOrder[value] = enum_name
			end

			assert(setting.EnumOrder[0] == nil and setting.EnumOrder[1] ~= nil, "Setting enums must start at 1 and be continuous all the way to the max value")
		else
			assert(setting.CorrespondingEnum == false)
		end
	end
end

SettingChangedTransmitter:UpConnection(function(plr, name: string, value: any)
		local setting = mod.Settings[name]
		if not setting then
			return
		end

		assert(value == value)

		mod.ChangeSetting(plr, name, value)
	end)

return mod
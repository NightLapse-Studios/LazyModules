--!strict

local LMT = require(game.ReplicatedFirst.Lib.LMTypes)
local Game: LMT.LMGame = _G.Game
local Config = require(game.ReplicatedFirst.Config)
local DebugMenu = require(game.ReplicatedFirst.Lib.Debug.DebugMenu)
local Tweens = require(game.ReplicatedFirst.Modules.Tweens)
local Assets = require(game.ReplicatedFirst.Modules.Assets)
local SettingsMod = require(game.ReplicatedFirst.Modules.Settings)
local Settings = SettingsMod.Settings

local SoundSerivce = game:GetService("SoundService")

local mod = { }

local PlayingSounds = { }

local MusicBinding = Settings.MusicAudioVolume.Binding[1]
local EffectsBinding = Settings.EffectsAudioVolume.Binding[1]

local GroupCallbacks = {
	Music = function(s: SoundBuilder)
		local sound = s.__Sound
		local volume = sound.Volume
		volume *= MusicBinding:getValue()
		sound.Volume = volume								
	end,
	Effects = function(s: SoundBuilder)
		local sound = s.__Sound
		local volume = sound.Volume
		volume *= EffectsBinding:getValue()
		sound.Volume = volume								
	end,
--[[ 	BugelSync = function(sound: SoundBuilder)
		if not sound.__Sound.IsLoaded then
			sound.__Sound.Loaded:Wait()
		end

		if BugelSyncTime >= 0 then
			sound.__Sound.TimePosition = os.clock() - BugelSyncTime
		else
			BugelSyncTime = os.clock()
			BugelSyncLength = sound.__Sound.TimeLength
			local con
			con = RunService.RenderStepped:Connect(function(dt)
				if (os.clock() - BugelSyncTime) >= BugelSyncLength then
					con:Disconnect()
					BugelSyncTime = -1
					BugelSyncLength = -1
				end
			end)
		end
	end ]]
}

local SoundBuilder = { }
SoundBuilder.__index = SoundBuilder

function mod.__init(G)
	if G.CONTEXT == "SERVER" then
		return
	end

	SettingsMod.OnChange("EffectsAudioVolume"):Connect(function(plr, old, new)
		for i,v in PlayingSounds do
			if not (v.__Sound and v.__Sound.Parent) then continue end

			if table.find(v.__groups, "Effects") then
				v.__Sound.Volume = new
			end
		end
	end)

	SettingsMod.OnChange("MusicAudioVolume"):Connect(function(plr, old, new)
		for i,v in PlayingSounds do
			if not (v.__Sound and v.__Sound.Parent) then continue end

			if table.find(v.__groups, "Music") then
				v.__Sound.Volume = new
			end
		end
	end)
end

type Self<T> = T

type SoundBuilder = {
	__Sound: Sound,
	__part: BasePart | false,
	__parent: Instance | false,
	__destroyed: boolean,
	__conections: { RBXScriptConnection },
	__endedConnection: RBXScriptConnection | false,
	__group: string,

	Play: (SoundBuilder, dont_manage: boolean?) -> SoundBuilder,
	DebugPlay: (SoundBuilder, dont_manage: boolean?) -> SoundBuilder,
	Pause: (SoundBuilder) -> SoundBuilder,
	Resume: (SoundBuilder) -> SoundBuilder,
	SetPlaybackSpeed: (SoundBuilder, speed: number) -> SoundBuilder,
	SetRollOff: (SoundBuilder, min: number, max: number, mode: Enum.RollOffMode) -> SoundBuilder,
	SetVolume: (SoundBuilder, vol: number, fade_duration: number?) -> SoundBuilder,
	SetLooped: (SoundBuilder, looped: boolean?) -> SoundBuilder,
	OnLoop: (SoundBuilder, callback: (Sound) -> ()) -> SoundBuilder,
	FadeOut: (SoundBuilder, duration: number, delay: number?, easing_style: Enum.EasingStyle?) -> SoundBuilder,
	FadeIn: (SoundBuilder, duration: number, delay: number?, easing_style: Enum.EasingStyle?) -> SoundBuilder,
	Destroy: (SoundBuilder) -> (),
}

function mod.SoundBuilder(asset_str, volume, ...: string)
	local groups = { ... }
	if #groups == 0 then
		table.insert(groups, "Effects")
	end

	local s = Instance.new("Sound")

	s.SoundId = asset_str
	s.RollOffMinDistance = 7
	s.RollOffMaxDistance = 1500
	s.RollOffMode = Enum.RollOffMode.Inverse
	s.PlayOnRemove = false
	s.Looped = false
	s.SoundGroup = SoundSerivce.Master
	s.Volume = volume or 1

	local t = {
		__Sound = s,
		__part = false,
		__parent = false,
		__destroyed = false,
		__connections = {},
		__endedConnection = false,
		__groups = groups
	}

	setmetatable(t, SoundBuilder)

	if Game.CONTEXT ~= "SERVER" then
		if Config.VolumeOverrides then
			local asset_name = if Config.OnlyHookKnownSounds then nil else asset_str
			for i,v in Assets.Sounds do
				if v == asset_str then
					asset_name = i
					break
				end
			end

			if asset_name then
				local override = DebugMenu.GetOverrideBinding(asset_name) or DebugMenu.RegisterOverrideSlider(asset_name, volume, volume / 4, 10, 0.01, "Volume Overrides")
				s.Volume = override:getValue()

				override:subscribe(function(v)
					s.Volume = v
				end)
			end
		end
	end

	return (t :: any) :: SoundBuilder
end

function SoundBuilder:Play(dont_manage: boolean?)
	if Config.MuteNormalSounds == true then
		return self
	end

	if (not dont_manage) and not self.__endedConnection then
		local con = self.__Sound.Ended:Once(function()
			self:Destroy()
		end)
		table.insert(self.__connections, con)
	end

	table.insert(PlayingSounds, self)

	self.__Sound:Play()

	return self
end
function SoundBuilder:DebugPlay(dont_manage: boolean?)
	if (not dont_manage) and not self.__endedConnection then
		local con = self.__Sound.Ended:Once(function()
			self:Destroy()
		end)
		table.insert(self.__connections, con)
	end

	self.__Sound:Play()

	return self
end
function SoundBuilder:Pause()
	self.__Sound:Pause()
	
	local idx = table.find(PlayingSounds, self)
	if idx then
		table.remove(PlayingSounds, idx)
	end

	return self
end
function SoundBuilder:Resume()
	self.__Sound:Resume()
	return self
end

function SoundBuilder:SetPlaybackSpeed(speed)
	self.__Sound.PlaybackSpeed = speed
	return self
end

function SoundBuilder:SetRollOff(min, max, mode)
	self.__Sound.RollOffMinDistance = min
	self.__Sound.RollOffMaxDistance = max

	if mode then
		self.__Sound.RollOffMode = mode
	end

	return self
end

function SoundBuilder:SetVolume(vol, fade_duration)
	if fade_duration then
		Tweens.new()
			:SetLength(fade_duration)
			:Run(self.__Sound, {Volume = vol})
	else
		self.__Sound.Volume = vol
	end

	return self
end

function SoundBuilder:SetLooped(looped)
	self.__Sound.Looped = looped
	return self
end

function SoundBuilder:SetTimePosition(t)
	self.__Sound.TimePosition = t
	return self
end

function SoundBuilder:OnLoop(callback)
	local con = self.__Sound.DidLoop:Connect(function()
		callback(self.__Sound)
	end)
	table.insert(self.__connections, con)
	return self
end

function SoundBuilder:FadeOut(duration, delay: number?, easing_style: Enum.EasingStyle?)
	delay = delay or 0

	local t = Tweens.new()
		:SetLength(duration)
		:SetDelay(delay)

	if easing_style then
		t:SetEasingStyle(easing_style)
	end
		
	t:Run(self.__Sound, {Volume = 0}, nil, true)

	return self, t
end

function SoundBuilder:FadeIn(duration, delay: number?, easing_style: Enum.EasingStyle?)
	local volume = self.__Sound.Volume
	self.__Sound.Volume = 0
	
	local t = Tweens.new()
		:SetLength(duration)

		if easing_style then
			t:SetEasingStyle(easing_style)
		end
			
	t:Run(self.__Sound, {Volume = volume}, nil, true)

	return self, t
end

function SoundBuilder:Destroy()
	if self.__destroyed then
		return
	end

	self:Pause()
	
	self.__destroyed = true
	
	if self.__part then
		self.__part:Destroy()
	end

	if self.__Sound then
		self.__Sound:Destroy()
	end

	if self.__connections then
		for _, con in self.__connections do
			con:Disconnect()
		end
		self.__connections = nil
	end
end


local SoundHostPart = Instance.new("Part")
SoundHostPart.Anchored = true
SoundHostPart.CanQuery = false
SoundHostPart.CanCollide = false
SoundHostPart.Transparency = 1
SoundHostPart.Size = Vector3.new(1, 1, 1)

function mod.PositionalSound(asset_str, volume, position: Vector3, ...)
	local groups = { ... }
	local t = mod.SoundBuilder(asset_str, volume, ...)

	local p = SoundHostPart:Clone()
	p.Position = position
	p.Parent = workspace.Invisibles

	t.__part = p
	t.__Sound.Parent = p

	for _,group in groups do
		if GroupCallbacks[group] then
			GroupCallbacks[group](t)
		else
			warn(`Sound {asset_str} played with unknown group {group}`)
		end
	end

	return t
end

function mod.ParentedSound(asset_str, volume, parent, ...)
	local groups = { ... }
	parent = if parent then parent else SoundSerivce

	local t = mod.SoundBuilder(asset_str, volume, ...)

	t.__Sound.Parent = parent
	
	for _,group in groups do
		--print(group)
		if GroupCallbacks[group] then
			task.spawn(GroupCallbacks[group], t)
		else
			warn(`Sound {asset_str} played with unknown group {group}`)
		end
	end

	return t
end


return mod
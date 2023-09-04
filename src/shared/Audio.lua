local Config
local DebugMenu
local Tweens

local SoundSerivce = game:GetService("SoundService")

local mod = { }

local SoundBuilder = { }
local mt_SoundBuilder = { __index = SoundBuilder }

function mod:__init(G)
	Config = G.Load("BUILDCONFIG")
	Tweens = G.Load("Tweens")
	
	if G.CONTEXT == "CLIENT" then
		DebugMenu = G.Load("DebugMenu")
	end
end

function mod.SoundBuilder(asset_str, volume)
	local s = Instance.new("Sound")

	s.SoundId = asset_str
	s.RollOffMinDistance = 7
	s.RollOffMaxDistance = 10000
	s.RollOffMode = Enum.RollOffMode.Inverse
	s.PlayOnRemove = false
	s.Looped = false
	s.SoundGroup = SoundSerivce.Master
	s.Volume = volume or 1

	local t = {
		__Sound = s,
		__part = false,
		__parent = false,
		__connections = {},
	}

	setmetatable(t, mt_SoundBuilder)

	if Config.VolumeOverrides then
		local override = DebugMenu.GetOverrideBinding(asset_str) or DebugMenu.RegisterOverrideSlider(asset_str, volume, 1, 15)
		s.Volume = override:getValue()
	end

	return t
end

function SoundBuilder:Play(dont_manage: boolean?)
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
	return self
end
function SoundBuilder:Resume()
	self.__Sound:Resume()
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

function SoundBuilder:OnLoop(callback)
	local con = self.__Sound.DidLoop:Connect(function()
		callback(self.__Sound)
	end)
	table.insert(self.__connections, con)
	return self
end

function SoundBuilder:FadeOut(duration, delay, dont_manage)
	delay = delay or 0
	
	Tweens.new()
		:SetLength(duration)
		:SetDelay(delay)
		:SetCleanup(function()
			if not dont_manage then
				self:Destroy()
			end
		end)
		:Run(self.__Sound, {Volume = 0})
end

function SoundBuilder:Destroy()
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

function mod.PositionalSound(asset_str, volume, position: Vector3)
	local t = mod.SoundBuilder(asset_str, volume)

	local p = SoundHostPart:Clone()
	p.Position = position
	p.Parent = workspace.Invisibles

	t.__part = p
	t.__Sound.Parent = p
	
	return t
end

function mod.ParentedSound(asset_str, volume, parent)
	parent = parent or SoundSerivce
	
	local t = mod.SoundBuilder(asset_str, volume)
	
	t.__Sound.Parent = parent

	return t
end


return mod
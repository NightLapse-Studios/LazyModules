--!strict

--[[
	Animation preloading/caching, replicating, and utils

	If you play an animation on you player, roblox handles the rest.

	For other animations, this module will replicate them to the server, where the server will
	verify if you are allowed to animate the model, and replicate it to all clients.

	For this to work, you must call:
	Animation.SetAllowCustomReplication(model, plr: Player?)
	on the server. You don't have to if the NetworkOwner is the plr.

	So that we don't recieve our own replications, we must remove the shared animator and replace it with a local one
	for as long as we have ownership.

	For this to work, you must call:
	Animation.MakeLocal(model)
	and when your done:
	Animation.RemoveLocal(model)
	on the client

	after that, you can use this file like usual.

	THIS SHOULD BE THE ONLY PLACE that gets animation tracks.
	.AnimationPlayed is connected in remotePlayers, those tracks do not have to worry about any of this.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Storage = RunService:IsServer() and game:GetService("ServerStorage") or game:GetService("ReplicatedStorage")

local Folder = Instance.new("Folder", Storage)
Folder.Name = "Animations"

local LMT = require(game.ReplicatedFirst.Lib.LMTypes)
local CRC = require(game.ReplicatedFirst.Modules.CRC32)
local Config = require(game.ReplicatedFirst.Config)
local Signals = require(game.ReplicatedFirst.Lib.Signals)

local AnimationAdjustSpeedTransmitter = Signals.NewTransmitter("AnimationAdjustSpeedTransmitter")
	:UpConnectionType(function(plr, model: Model, animID: string, speed: number) end)
local AnimationAdjustWeightTransmitter = Signals.NewTransmitter("AnimationAdjustWeightTransmitter")
	:UpConnectionType(function(plr, model: Model, animID: string, weight: number, fadeTime: number) end)
local AnimationPlayTransmitter = Signals.NewTransmitter("AnimationPlayTransmitter")
	:UpConnectionType(function(plr, model: Model, animID: string, fadeTime: number, weight: number, speed: number) end)
local AnimationStopTransmitter = Signals.NewTransmitter("AnimationStopTransmitter")
	:UpConnectionType(function(plr, model: Model, animID: string, fadeTime: number) end)

local Animation = {}
Animation.__index = Animation

local AnimationTracks = { }
local RandomAnimLoops = { }

local WrapTrackHash = setmetatable({}, {__mode = "kv"})

function Animation.GetWrappedTrack(animationTrack)
	return WrapTrackHash[animationTrack]
end

local Track = {}

function Track:__index(newKey)
	if Track[newKey] then
		return Track[newKey]
	else
		local extends = self.__Track
		local extendsIndex = extends[newKey]

		if type(extendsIndex) == 'function' then
			return function(_, ...)
				return extendsIndex(extends, ...)
			end
		else
			return extendsIndex
		end
	end
end

function Track:__newindex(key, value)
	self.__Track[key] = value
end

function Track.new(animationTrack, model, animID)
	local DoReplicate = RunService:IsClient() and model ~= Players.LocalPlayer.Character

	local newTrack = setmetatable({
		__Track = animationTrack,

		Model = model,
		AnimationID = animID,
		DoReplicate = DoReplicate,
	}, Track)

	WrapTrackHash[animationTrack] = newTrack

	return newTrack
end

function Track:AdjustSpeed(speed)
	self.__Track:AdjustSpeed(speed)

	if self.DoReplicate then
		AnimationAdjustSpeedTransmitter:TransmitUp(self.Model, self.AnimationID, speed)
	end
end

function Track:AdjustWeight(weight, fadeTime)
	self.__Track:AdjustWeight(weight, fadeTime)

	if self.DoReplicate then
		AnimationAdjustWeightTransmitter:TransmitUp(self.Model, self.AnimationID, weight, fadeTime)
	end
end

function Track:Play(fadeTime, weight, speed)
	self.__Track:Play(fadeTime, weight, speed)

	if self.DoReplicate then
		AnimationPlayTransmitter:TransmitUp(self.Model, self.AnimationID, fadeTime, weight, speed)
	end
end

function Track:Stop(fadeTime)
	self.__Track:Stop(fadeTime)

	if self.DoReplicate then
		AnimationStopTransmitter:TransmitUp(self.Model, self.AnimationID, fadeTime)
	end
end

function Track:Destroy()
	WrapTrackHash[self.__Track] = nil
	self.__Track:Destroy()
	setmetatable(self, nil)
end

-- cleaned up at the bottom of the file
local allowsCustomForHash = {}

-- use this function for anchored parts you want to allow to the plr or stop so
function Animation.SetAllowCustomReplication(model, plr: Player?)
	allowsCustomForHash[model] = plr
end

function Animation.ShouldAllowCustomReplication(plr, model)
	if plr.Character == model then
		-- roblox handles this for us, no reason we should be doing it.
		return false
	end

	local suc, ret = pcall(function()
		return model.PrimaryPart:GetNetworkOwner() == plr
	end)

	-- will be the case for physically simulated assemblies that we own.
	if suc and ret then
		return true
	end

	if allowsCustomForHash[model] == plr then
		return true
	end

	return false
end

function Animation.GetAnimatorLoader(model)
	if model:IsA("Animator") then
		error("requires Model")
	end

	if model:IsA("Humanoid") or model:IsA("AnimationController") then
		error("requires Model")
	end

	-- our humanoid is expected to already load (see top of Globals)
	local controller = model:FindFirstChild("Humanoid") or model:WaitForChild("AnimationController")

	return controller:WaitForChild("Animator")
end

local serverAnimators = {}

function Animation.MakeLocal(model)
	assert(model:IsA("Model"))

	local animator = Animation.GetAnimatorLoader(model)
	serverAnimators[model] = {
		Animator = animator,
		Connection = model.Destroying:Once(function()
			serverAnimators[model] = nil
		end),
	}

	local oldParent = animator.Parent
	animator.Parent = nil

	-- the client animator
	Instance.new("Animator", oldParent)
end

function Animation.RemoveLocal(model)
	if serverAnimators[model] then
		if model:IsDescendantOf(game) then
			local cAnimator = Animation.GetAnimatorLoader(model)
			local parent = cAnimator.Parent

			cAnimator:Destroy()
			serverAnimators[model].Animator.Parent = parent
		end

		serverAnimators[model].Connection:Disconnect()
		serverAnimators[model] = nil
	end
end


function Animation.PreloadAnimation(model, animID, looped_verification)
	local controller = Animation.GetAnimatorLoader(model)

	local cachedAnimation = Folder:FindFirstChild(animID)

	if cachedAnimation == nil then
		cachedAnimation = Instance.new("Animation", Folder)
		cachedAnimation.AnimationId = animID
		cachedAnimation.Name = animID
	end

	AnimationTracks[controller] = AnimationTracks[controller] or {}

	local cache = AnimationTracks[controller]
	local cachedTrack: AnimationTrack = cache[animID]

	if cachedTrack == nil then
		cachedTrack = Track.new(controller:LoadAnimation(cachedAnimation), model, animID)

		cache[animID] = cachedTrack
	end

	if looped_verification ~= nil then
		task.delay(5, function()
			if cachedTrack.Looped ~= looped_verification then
				warn("Exported Loop property for animation is different from argument.")
			end
		end)
	end

	return cachedTrack
end

function Animation.Animate(model: Model, animID: string, looped_verification: boolean?, speed: number?, fade_time: number?): AnimationTrack
	local cachedTrack = Animation.PreloadAnimation(model, animID, looped_verification)

	if cachedTrack.IsPlaying == false then
		cachedTrack:Play(fade_time or Config.AnimationFadeTime, nil, speed)
	end

	return cachedTrack
end

function Animation.GetAnimation(model: Model, asset_str: string)
	local controller = Animation.GetAnimatorLoader(model)

	if not controller then
		return nil
	end

	for _, v in pairs(controller:GetPlayingAnimationTracks())do
		v = Animation.GetWrappedTrack(v)

		if v.AnimationID == asset_str then
			return v
		end
	end
end

function Animation.GetAnimationFromList(model: Model, asset_str_tbl: table)
	local controller = Animation.GetAnimatorLoader(model)

	if not controller then
		return nil
	end

	for _,asset_str in pairs(asset_str_tbl) do
		for _, v in pairs(controller:GetPlayingAnimationTracks())do
			v = Animation.GetWrappedTrack(v)

			if v.AnimationID == asset_str then
				return v
			end
		end
	end
end

--This is a yielding function
--TODO: Make a version that calls functions instead
--Not just because that's useful, but because otherwise animations can only be default speed
local function LoopedAnimSelect(loopID)
	local loop = RandomAnimLoops[loopID]

	if not loop then
		--The loop has been stopped
		return
	end

	local model = loop[1]
	local PR = loop[2]
	local animID = PR:getRandom()

	local track = Animation.Animate(model, animID)
	track.Stopped:Wait()

	LoopedAnimSelect(loopID)
end

function Animation.LoopAnimsRandomly(model: Model, loopName: String, PR: FastProbabilityRange)
	--Note that using a model's name, and some loop name, will generate collisions if the model's name doesn't embedd
	-- some sort of ID the way that mobs do.
	local loopID = CRC(string.format("%f", tick()) .. loopName)

	if RandomAnimLoops[loopID] then
		return
	end

	local IDValue = Instance.new("IntValue", model)
	IDValue.Value = loopID
	IDValue.Name = loopName

	RandomAnimLoops[loopID] = { model, PR }
	local co = coroutine.create(LoopedAnimSelect)
	coroutine.resume(co, loopID)

	return loopID
end

function Animation.StopRandomAnimLoop(model: Model, loopName: string)
	local loopIDInstance = model:FindFirstChild(loopName)

	if not loopIDInstance then
		return
	end

	local loopID = loopIDInstance.Value
	RandomAnimLoops[loopID] = nil
	loopIDInstance:Destroy()
end

function Animation.StopAllAnimations(model: Model)
	for _, v in pairs(Animation.GetAnimatorLoader(model):GetPlayingAnimationTracks()) do
		v = Animation.GetWrappedTrack(v)

		v:Stop(Config.AnimationFadeTime)
	end
end

function Animation.StopAllAnimationsExcept(model: Model, assetID: string)
	for _, v in pairs(Animation.GetAnimatorLoader(model):GetPlayingAnimationTracks()) do
		v = Animation.GetWrappedTrack(v)

		if v.AnimationID == assetID then
			continue
		end

		v:Stop(Config.AnimationFadeTime)
	end
end

function Animation.StopAllAnimationsExceptList(model: Model, assetIDList: table)
	for _, v in pairs(Animation.GetAnimatorLoader(model):GetPlayingAnimationTracks()) do
		v = Animation.GetWrappedTrack(v)

		local found = false
		for _,assetID in pairs(assetIDList) do
			if v.AnimationID == assetID then
				found = true
				break
			end
		end

		if found == false then
			v:Stop(Config.AnimationFadeTime)
		end
	end
end

function Animation.StopAnimationIfPlaying(model, asset_str, fade_time)
	local anim = Animation.GetAnimation(model, asset_str)
	if anim then
		anim:Stop(fade_time or Config.AnimationFadeTime)
	end
end

function Animation.AdjustAnimationSpeedIfPlaying(model, asset_str, speed)
	local anim = Animation.GetAnimation(model, asset_str)
	if anim then
		anim:AdjustSpeed(speed)
	end
end

function Animation.AdjustAnimationSpeeds(model, speed)
	for _, v in pairs(Animation.GetAnimatorLoader(model):GetPlayingAnimationTracks()) do
		v = Animation.GetWrappedTrack(v)

		v:AdjustSpeed(speed)
	end
end

function Animation.__run()
	if RunService:IsServer() then
		-- Clean up allowsCustomForHash leftovers

		task.spawn(function()
			while true do
				task.wait(10)

				for model, plr in allowsCustomForHash do
					if (not plr:IsDescendantOf(game)) or (not model:IsDescendantOf(game)) then
						allowsCustomForHash[model] = nil
					end
				end
			end
		end)
	end
end

AnimationAdjustSpeedTransmitter:UpConnection(function(plr, model, animID, speed)
		if not Animation.ShouldAllowCustomReplication(plr, model) then
			return
		end

		local track = Animation.GetAnimation(model, animID)
		if track then
			track:AdjustSpeed(speed)
		end
	end)
AnimationAdjustWeightTransmitter:UpConnection(function(plr, model, animID, weight, fadeTime)
		if not Animation.ShouldAllowCustomReplication(plr, model) then
			return
		end
		
		local track = Animation.GetAnimation(model, animID)
		if track then
			track:AdjustWeight(weight, fadeTime)
		end
	end)
AnimationPlayTransmitter:UpConnection(function(plr, model, animID, fadeTime, weight, speed)
		if not Animation.ShouldAllowCustomReplication(plr, model) then
			return
		end

		Animation.Animate(model, animID, nil, speed, fadeTime)
	end)
AnimationStopTransmitter:UpConnection(function(plr, model, animID, fadeTime)
		if not Animation.ShouldAllowCustomReplication(plr, model) then
			return
		end

		local track = Animation.GetAnimation(model, animID)
		if track then
			track:Stop(fadeTime)
		end
	end)


return Animation
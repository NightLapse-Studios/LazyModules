-- Extends the player service, but Better, ahahah!
-- handles players that join before server

local PlayerService = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")

local Game
local Config
local AssociativeList
local NameAssociations
local IDAssociations
local DS3
local Entity
local Admin
local SpawnHandler
local Instances
local Animation

local JoinedGameGE
local LeavedGameGE
local AddRemotePlayerTransmitter

local ERR_DATA_MODULE_INVALID = "Data module %s is missing method(s) or function(s)"
local PlayerDataModules = { }
local PlayerDataModulesOrder = { }

local mod = { }
local ActualList = { }

local CharacterFolder

function mod:__init(G)
	Game = G
	Config = G.Load("BUILDCONFIG")
	AssociativeList = G.Load("AssociativeList")
	NameAssociations = AssociativeList.new()
	IDAssociations = AssociativeList.new()
	DS3 = G.Load("DataStore3")
	Entity = G.Load("Entity")
	Admin = G.Load("Admin")
	SpawnHandler = G.Load("SpawnHandler")
	Instances = G.Load("Instances")
	Animation = G.Load("Animation")
	
	if _G.Game.CONTEXT == "SERVER" then
		CharacterFolder = Instance.new("Folder", workspace)
		CharacterFolder.Name = "Characters"
	else
		CharacterFolder = workspace:WaitForChild("Characters")
	end
end

-- A better PlayerAdded event
local PlayerAddedBindable = Instance.new("BindableEvent")
mod.PlayerAdded = {
	Connect = function(_, func)
		local con = PlayerAddedBindable.Event:Connect(func)

		for _,plr in pairs(ActualList) do
			coroutine.wrap(func)(plr)
		end

		return {
			Disconnect = function()
				con:Disconnect()
			end
		}
	end
}

local function RemovePlayer( plr )
	local plrTbl = Game[plr]

	if plrTbl then
		SpawnHandler.ServerDespawnPlayer(plr)

		plrTbl.DataBinding:Finalize()

		local entity = Entity.GetFromPlayer(plr)
		if entity then
			Entity.Destroy(entity)
		end

		Game[plr] = nil
		Game[plrTbl] = nil
	end
end

local function PlayerJoined(_, plr)
	IDAssociations:add(plr.UserId, plr)
	NameAssociations:add(plr.Name, plr)

	coroutine.wrap(function()
		table.insert(ActualList, plr)
		PlayerAddedBindable:Fire(plr)
	end)()
end

local function PlayerLeaved(_, plr)
	IDAssociations:remove(plr.UserId, plr)
	NameAssociations:remove(plr.Name, plr)

	for i = 1, #ActualList, 1 do
		if ActualList[i] == plr then
			table.remove(ActualList, i)
			break
		end
	end
end

local function ServerJoinGE(plr)
	while not (Game.LOADING_CONTEXT > Game.Enums.LOAD_CONTEXTS.FINALIZE) do
		task.wait()
	end

	-- Event must fire after the insertions
	PlayerJoined(plr, plr)
	JoinedGameGE:Fire(plr, plr)
end

local function ServerLeaveGE(plr)
	while not (Game.LOADING_CONTEXT > Game.Enums.LOAD_CONTEXTS.FINALIZE) do
		task.wait()
	end

	-- Event must fire before the removals
	LeavedGameGE:Fire(plr, plr)
	PlayerLeaved(plr, plr)
end

local function OnPlayerLoadFinished( binding, char )
	local plr: Player = char.Player

	if not plr:IsDescendantOf(game) then
		return
	end

	Game[plr] = char
	Game[char] = plr

	if Admin:checkIfServerLocked() then
		plr:Kick("This server is currently locked!")
		return
	end

	if Admin:checkBan(plr) then
		return
	end

	local character = plr.Character
	while not character do
		task.wait()
		character = plr.Character
	end
	-- Instances.ClientsNeed(character, character:GetChildren())

	character:SetPrimaryPartCFrame(workspace.DeadBox:GetPivot())
	character.Parent = CharacterFolder

	Instances.ClientsNeed(character, character:GetChildren())

	local ent = Entity.new(character, plr, "Character")
	ent.Weight = 5
	ent.Radius = 1000

	local serial_stats = { }
	for i,v in PlayerDataModules do
		serial_stats[i] = char[i]:Serialize()
	end

	-- late clients remotePlayers handled by PlayerStats
	for i, other_plr in mod.GetPlayers() do
		AddRemotePlayerTransmitter:Transmit(other_plr, plr.UserId, serial_stats)
	end

	char.Loaded = true

	-- remove player on character Removing because .PlayerRemoving fires after Player.Character has been set to nil.
	plr.CharacterRemoving:Connect(function(character)
		RemovePlayer(plr)
	end)

	SpawnHandler.ServerSpawnPlayer(plr, workspace.SpawnLocation.Position, Vector3.new(0, 0, -1))
	-- MugShotLoader.Load(plr)
	-- Purchases.CheckOwnedGamepasses(plr)
end

local function LoadClientData(plr_id, plr)
	if Game[plr] then
		--Players could forge this event, which we'll just ignore
		return
	end

	local storeName = DS3.GetStoreName()
	local DSkey = DS3.GetUserIdMasterKey(plr.UserId)

	local char = {
		Loaded = false,
		ClientLoaded = false,
		
		Player = plr,

		--Reserve keys
		DataBinding = -1,
	}

	local data_bindings = { }

	for i,v in PlayerDataModules do
		local module = v[1]
		local args = v[2]
		local obj = module.new(plr, table.unpack(args))
		char[i] = obj
		data_bindings[i] = obj
	end

	char.DataBinding = DS3.NewDataBinding(storeName, DSkey, data_bindings, char, OnPlayerLoadFinished, PlayerDataModulesOrder)
end

-- Data modules will be serialized and deserialized in the order they are registered by this function
function mod.RegisterPlayerDataModule(file, ctor_args)
	local Game = _G.Game
	assert(Game.LOADING_CONTEXT < Game.Enums.LOAD_CONTEXTS.LOAD_INIT, "RegisterPlayerDataModule must be called before Game.Begin")

	local name = file.Name
	local mod = Game.PreLoad(file)
	assert(typeof(mod.new) == "function", string.format(ERR_DATA_MODULE_INVALID, name))

	ctor_args = ctor_args or { }
	PlayerDataModules[name] = { mod, ctor_args }
	table.insert(PlayerDataModulesOrder, name)
end

local function AddRemotePlayer(plr_id, data)
	local plr = game.Players:GetPlayerByUserId(plr_id)

	if not plr then
		local t = 0
		repeat t += task.wait() ; plr = game.Players:GetPlayerByUserId(plr_id) until (plr or t > 6)
	end

	if not plr then
		return
	end

	local rPlr = {
		StatConnections = { },
		AnimationTracks = { }
	}

	for i,v in data do
		local mod = Game.Load(i)
		local obj = mod.new(plr)
		obj:Deserialize(v)
		rPlr[i] = obj
	end

	Game[plr] = rPlr
	Game[rPlr] = plr

	local humanoid = plr.Character:WaitForChild("Humanoid")

	humanoid.AnimationPlayed:Connect(function(track: AnimationTrack)
		rPlr.AnimationTracks[track.Animation.AnimationId] = track
	end)

	for _,v in humanoid:GetPlayingAnimationTracks() do
		rPlr.AnimationTracks[v.Animation.AnimationId] = v
	end

	task.spawn(function()
		-- default roblox sound
		local running = plr.Character:WaitForChild("HumanoidRootPart"):WaitForChild("Running", 6)
		if running then
			running:Destroy()
		end
	end)
end

local function RemoveRemotePlayer( plr )
	local rPlr = Game[plr]

	Game[plr] = nil
	Game[rPlr] = nil
end

function mod:__build_signals(G, B)
	-- Set up player joined GE so that it is authored and detected by the server only
	JoinedGameGE = B:NewGameEvent("Joined", "Game")
		:RequiresVerification(true)
		:ClientConnection(PlayerJoined)
		:ServerConnection(LoadClientData)
	LeavedGameGE = B:NewGameEvent("Leaved", "Game")
		:RequiresVerification(true)
		:ClientConnection(PlayerLeaved)

	AddRemotePlayerTransmitter = B:NewTransmitter("AddRemotePlayerTransmitter")
		:ClientConnection(AddRemotePlayer)

	if Game.CONTEXT == "SERVER" then
		PlayerService.PlayerAdded:Connect(ServerJoinGE)
		PlayerService.PlayerRemoving:Connect(ServerLeaveGE)
	elseif Game.CONTEXT == "CLIENT" then
		PlayerService.PlayerRemoving:Connect(RemoveRemotePlayer)
	end
end

function mod.GetAssociatedPlayer(id_or_name: number | string)
	if typeof(id_or_name) == "string" then
		return NameAssociations:get(id_or_name)
	elseif typeof(id_or_name) == "number" then
		return IDAssociations:get(id_or_name)
	end
end

function mod.GetPlayers()
	return ActualList
end

function mod.GetCharacters()
	local PlayerCount = #ActualList
	local tbl = table.create(PlayerCount)

	local Increment = 0
	for i = 1, PlayerCount do
		local Char = ActualList[i].Character
		if Char then
			Increment += 1
			tbl[Increment] = Char
		end
	end

	return tbl
end

function mod.GetAnimator(plr)
	local Character = plr.Character or plr.CharacterAdded:Wait()
	local Humanoid = Character:WaitForChild("Humanoid")
	local Animator = Humanoid:WaitForChild("Animator")
	return Animator
end

function mod.AwardBadge(plr, badgeid)
	for name, id in Config.Badges do
		if id == badgeid then
			print("Attempting to reward " .. name .. " badge with id " .. tostring(badgeid) .. " to player " .. tostring(plr))
			break
		end
	end
	
	local success, badgeInfo = pcall(function()
		return BadgeService:GetBadgeInfoAsync(badgeid)
	end)

	if success then
		-- Confirm that badge can be awarded
		if badgeInfo.IsEnabled then
			-- Award badge
			local success2, hasBadge = pcall(function()
				return BadgeService:UserHasBadgeAsync(plr.UserId, badgeid)
			end)

			if success2 and not hasBadge then
				local awarded, errorMessage = pcall(function()
					BadgeService:AwardBadge(plr.UserId, badgeid)
				end)
				if not awarded then
					warn("Error while awarding badge:", errorMessage)
				end
			end
		end
	else
		warn("Error while fetching badge info!")
	end
end

function mod.Update()
	if Game.CONTEXT ~= "SERVER" then
		error()
	end

	for i,plr in pairs(mod.GetPlayers()) do
		local char = Game[plr]
		if not char then
			continue
		end

		local primaryPart = plr.Character and plr.Character.PrimaryPart
		if not primaryPart then
			continue
		end

		local position = primaryPart.Position

		if position.Y < -200 then
			SpawnHandler.ServerDespawnPlayer(plr)
			local stats = char.PlayerStats
			stats:ChangeStat("CanRespawn", true, "set", false)
		end
	end
end


--[[
	Used when logic depends on an animation. For the local player, you will play the animation, but for
		remote players, you will need to yield for their track.
	
	Only yields if the animation has not been played on the other player for a first time

	There is no good fallback for if this times out, so using it in core loops such as system update loops can
		cause the whole game to error
]]
function mod.YieldForRemoteAnimTrack(plr, id, timeout): AnimationTrack?
	if Game.CONTEXT ~= "CLIENT" then
		error()
	end

	timeout = timeout or 2.0

	if plr:IsA("Model") then
		local track = nil

		local loader = Animation.GetAnimatorLoader(plr)

		for _, v in loader:GetPlayingAnimationTracks() do
			if v.Animation.AnimationId == id then
				return v
			end
		end

		local played = loader.AnimationPlayed:Connect(function(atrack)
			if atrack.Animation.AnimationId == id then
				track = atrack
			end
		end)

		local start = tick()

		while not track do
			if tick() - start > timeout then
				played:Disconnect()
				return nil
			end

			task.wait()
		end

		played:Disconnect()
		return track
	end

	local rPlr = Game[plr]
	if not rPlr then return nil end

	local start = tick()

	while not rPlr.AnimationTracks[id] do
		task.wait()
		if tick() - start > timeout then
			return nil
		end
	end

	return rPlr.AnimationTracks[id]
end



return mod


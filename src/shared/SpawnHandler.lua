local Game
local Enums
local Entity
local Config
local Controllers

local SpawnRequestTransmitter
local DespawnRequestTransmitter

local dbg_LastSpawnPosition

local mod = { }

function mod:__init(G)
	Game = G
	Enums = G.Load("Enums")
	Entity = G.Load("Entity")
	Config = G.Load("BUILDCONFIG")
	Controllers = G.Load("Controllers")
end

function mod.ServerSpawnPlayer(plr: Player, position, look_vector)
	local stats = Game[plr].PlayerStats

	if not (stats:GetStatValue("IsDead") and stats:GetStatValue("CanRespawn")) then
		return
	end

	stats:ChangeStat("CanRespawn", false, "set", false)

	local character = plr.Character

	local health = 100

	character:SetAttribute("MaxHealth", health)
	character:SetAttribute("Health", health)

	Entity.MakeInvincible(plr.Character, 5)

	local targetSpawnPosition
	if Config.SpawnPlayersClose then
		if dbg_LastSpawnPosition then
			targetSpawnPosition = dbg_LastSpawnPosition
		else
			targetSpawnPosition = position + Vector3.new(0,6,0)
			dbg_LastSpawnPosition = targetSpawnPosition
		end
	else
		targetSpawnPosition = position + Vector3.new(0,6,0)
	end

	character.PrimaryPart.CFrame = CFrame.new(targetSpawnPosition, look_vector)
	character.PrimaryPart:SetNetworkOwner(plr)

	stats:ChangeStat("IsDead", false, "set", false)

	SpawnRequestTransmitter:Transmit(plr, true)
end

-- Called on player death and when round ends, etc
-- Disarms powerups, unreadies weapons
function mod.ServerDespawnPlayer(plr)
	local char = Game[plr]

	if not char then
		return
	end
	
	local stats = char.PlayerStats
	
	plr.Character.PrimaryPart.Anchored = false

	stats:ChangeStat("CanRespawn", false, "set", false)
	stats:ChangeStat("IsDead", true, "set", false)
	
	local destSpawn = workspace.DeadBox.PrimaryPart.Position

	local dest = CFrame.new(destSpawn + Vector3.new(0,5,0))

	-- Note: setting the cframe of a part on the server might not work AT ALL if the part is owned by a client who is
	-- either setting the cframe without considering the previous cframe, or if they are using any roblox constraints/joints on the part
	-- even if you destroy them on the server first, because the destruction of them must network.
	plr.Character.PrimaryPart:SetNetworkOwner(nil)
	plr.Character:PivotTo(dest)
	
	stats:Wipe(Enums.ResetType.OnDeath)
	plr.Character:ScaleTo(1)
	
	task.delay(2.5, function()
		stats:ChangeStat("CanRespawn", true, "set", false)
	end)

	DespawnRequestTransmitter:Transmit(plr, true)
end

local function ClientSpawnPlayer()
	Controllers.new(game.Players.LocalPlayer.Character, "Character")
	Controllers.SetActive("Character")
end

local function ClientDespawnPlayer()
	Controllers:DestroyAll()
end

function mod:__build_signals(G, B)
	SpawnRequestTransmitter = B:NewTransmitter("SpawnRequestTransmitter")
		:ClientConnection(function(did_spawn)
			if did_spawn then
				ClientSpawnPlayer()
			end
		end)
		:ServerConnection(function(plr)
			-- If you have a basis to decide if a player should spawn, this is the place to do it
			mod.ServerSpawnPlayer(plr, workspace.SpawnLocation.Position, Vector3.new(0, 0, -1))
		end)

	DespawnRequestTransmitter = B:NewTransmitter("DespawnRequestTransmitter")
		:ClientConnection(function(did_despawn)
			if did_despawn then
				ClientDespawnPlayer()
			end
		end)
		:ServerConnection(function(plr)
			-- If you have a basis to decide if a player should despawn, this is the place to do it
			mod.ServerDespawnPlayer(plr)
		end)

	if G.CONTEXT == "SERVER" then return end
	G.Load("UserInput"):Handler(Enum.KeyCode.F, function()
		DespawnRequestTransmitter:Transmit()
	end)
	G.Load("UserInput"):Handler(Enum.KeyCode.G, function()
		SpawnRequestTransmitter:Transmit()
	end)
end

return mod
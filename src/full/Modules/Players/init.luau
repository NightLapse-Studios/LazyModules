--!strict
-- Extends the player service, but Better, ahahah!
-- handles players that join before server

local PlayerService = game:GetService("Players")

local LMT = require(game.ReplicatedFirst.Lib.LMTypes)

local Game: LMT.LMGame = _G.Game
local AssociativeList = require(game.ReplicatedFirst.Lib.AssociativeList)
local DataStore3 = require(game.ReplicatedFirst.Modules.DataStore3)
local PlayerClass = require(game.ReplicatedFirst.Modules.Players.PlayerClass)
local Enums = require(game.ReplicatedFirst.Lib.Enums)
local Signals = require(game.ReplicatedFirst.Lib.Signals)

local IDAssociations = AssociativeList.new()
local NameAssociations = AssociativeList.new()

local AddRemotePlayerTransmitter = Signals.NewTransmitter("AddRemotePlayerTransmitter")
	:DownConnectionType(function(plr_id: number, data: unknown) end)

local ERR_DATA_MODULE_INVALID = "Data module %s is missing method(s) or function(s)"
local PlayerDataModules = { }
local PlayerDataModulesOrder = { }

local mod = { }
local Objects: { [Player]: PlayerObject } = { } 
local LoadedPlayers: { Player } = { }

mod.Objects = Objects

-- A better PlayerAdded event
local PlayerAddedBindable = Instance.new("BindableEvent")
mod.PlayerAdded = {
	Connect = function(_, func)
		local con = PlayerAddedBindable.Event:Connect(func)

		for _,plr in pairs(LoadedPlayers) do
			task.spawn(func, plr)
		end

		return {
			Disconnect = function()
				con:Disconnect()
			end
		}
	end
}

-- @Context SERVER
local function OnPlayerLoadFinished( binding: PlayerDataBinding, plrClass )
	local plr: Player = plrClass.Player

	if not plr:IsDescendantOf(game) then
		return
	end

	while Game.LoadingContext.Value < Enums.LoadingContexts.FINISHED.Value do
		task.wait()
	end

	Objects[plr] = plrClass

	IDAssociations:add(plr.UserId, plr)
	NameAssociations:add(plr.Name, plr)
	table.insert(LoadedPlayers, plr)
	
	-- Reserialize everything with the latest version, then send it to clients
	local serial_data, private_serial_data = {}, {}
	for mod_name,v in PlayerDataModules do
		local ds_obj = plrClass[mod_name] :: DataStore3.DSObject<unknown>
		serial_data[mod_name] = DataStore3.SerializeObject(ds_obj)
	end

	for i, other_plr in LoadedPlayers do
		AddRemotePlayerTransmitter:TransmitDown(other_plr, plr.UserId, serial_data)
	end
	
	PlayerAddedBindable:Fire(plr)
	
	Game.LoadedPlayers[plr] = true
end

-- @Context SERVER
local function LoadClientData(plrClass: PlayerClass.PlayerClass)
	local plr = plrClass.Player
	
	local storeName = DataStore3.GetStoreName()
	local DSkey = DataStore3.GetUserIdMasterKey(plr.UserId)

	local data_bindings = { }

	for i,v in PlayerDataModules do
		local module = v[1]
		local args = v[2]
		local obj = module.new(plr, table.unpack(args))
		plrClass[i] = obj
		data_bindings[i] = obj
	end

	local binding = DataStore3.NewDataBinding(storeName.Value, DSkey, data_bindings, plrClass, OnPlayerLoadFinished, PlayerDataModulesOrder)
	plrClass.DataBinding = binding

	return binding
end

type PlayerDataBinding = typeof(LoadClientData(game.Players.LocalPlayer))

-- @Context SERVER
-- Data modules will be serialized and deserialized in the order they are registered by this function
function mod.RegisterPlayerDataModule(name, ctor_args)
	local Game = _G.Game
	assert(Game.LoadingContext.Value < Enums.LoadingContexts.RUNNING_STAGES.Value, "RegisterPlayerDataModule must be called before Game.Begin")

	local mod = Game:Get(name)
	assert(typeof(mod.new) == "function", string.format(ERR_DATA_MODULE_INVALID, name))

	ctor_args = ctor_args or { }
	PlayerDataModules[name] = { mod, ctor_args }
	table.insert(PlayerDataModulesOrder, name)
end

-- @Context CLIENT
local function AddRemotePlayer(plr_id: number, data)
	local plr = PlayerService:GetPlayerByUserId(plr_id)

	if not plr then
		local t = 0
		repeat t += task.wait() ; plr = PlayerService:GetPlayerByUserId(plr_id) until (plr or t > 6)
	end

	if not plr then
		return
	end

	local plrClass = PlayerClass.new(plr)

	for mod_name, data in data do
		local mod = Game:Get(mod_name)
		local obj = mod.new(plr) :: DataStore3.DSObject<unknown>
		local latest = DataStore3.GetLatestVersion(obj)
		latest.Deserialize(obj, data)
		plrClass[mod_name] = obj
	end

	Objects[plr] = plrClass
	Game.LoadedPlayers[plr] = true
end

AddRemotePlayerTransmitter:DownConnection(AddRemotePlayer)

local function RemoveRemotePlayer( plr )
	local plrClass = Objects[plr]

	for i,v in plrClass do
		if typeof(v) == "table" and v.Destroy then
			v:Destroy()
		end
	end

	Objects[plr] = nil
	Game.LoadedPlayers[plr] = nil
	
	plrClass:Destroy()
end

function mod.__run(G: LMT.LMGame)
	if Game.CONTEXT == "SERVER" then
		game.ReplicatedStorage:WaitForChild("ClientReadyEvent").OnServerEvent:Connect(function(plr)
			while not plr:IsDescendantOf(game) do
				task.wait()
			end
			
			if not plr:IsDescendantOf(game) then
				print("Player added, but not in game")
				return
			end
			
			local plrClass = PlayerClass.new(plr)
			LoadClientData(plrClass)
		end)
		
		PlayerService.PlayerRemoving:Connect(function(plr)
			while not (Game.LoadingContext.Value >= Enums.LoadingContexts.FINISHED.Value) do
				task.wait()
			end
			
			local plrClass = Objects[plr]

			if plrClass then
				plrClass.DataBinding:Finalize()
				
				for i,v in plrClass do
					if typeof(v) == "table" and v.Destroy then
						v:Destroy()
					end
				end
				
				Objects[plr] = nil
				Game.LoadedPlayers[plr] = nil
				
				plrClass:Destroy()
			end
			
			local idx = table.find(LoadedPlayers, plr)
			if idx then
				IDAssociations:remove(plr.UserId, plr)
				NameAssociations:remove(plr.Name, plr)
				
				table.remove(LoadedPlayers, idx)
			end
		end)
	elseif Game.CONTEXT == "CLIENT" then
		PlayerService.PlayerRemoving:Connect(function(plr)
			RemoveRemotePlayer(plr)
		end)
	end
end

function mod.__load_gamestate(serial, loaded, after)
	for plr_id, stats in serial do
		AddRemotePlayer(tonumber(plr_id), stats)
	end

	loaded()
end

function mod.__get_gamestate(plr)
	local t = {}

	for i, other_plr in mod.GetPlayers() do
		if other_plr ~= plr then
			local plrClass = Objects[other_plr]
			
			local serial_data = { }
			for k,v in PlayerDataModules do
				serial_data[k] = DataStore3.SerializeObject(plrClass[k])
			end
			
			t[tostring(other_plr.UserId)] = serial_data
		end
	end
	
	return t
end

function mod.GetAssociatedPlayer(id_or_name: number | string): Player
	if typeof(id_or_name) == "string" then
		return NameAssociations:get(id_or_name)
	elseif typeof(id_or_name) == "number" then
		return IDAssociations:get(id_or_name)
	end
end

function mod.GetPlayers()
	return LoadedPlayers
end

function mod.GetCharacters()
	local PlayerCount = #LoadedPlayers
	local tbl = table.create(PlayerCount)

	local Increment = 0
	for i = 1, PlayerCount do
		local Char = LoadedPlayers[i].Character
		if Char then
			Increment += 1
			tbl[Increment] = Char
		end
	end

	return tbl
end

return mod
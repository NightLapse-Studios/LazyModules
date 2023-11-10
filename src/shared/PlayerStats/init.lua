--!strict
local Enums = _G.Game.Enums
local StatList = require(script.PlayerStatList)
local Players

local Game
local PermStatChangedTransmitter
local ClassicSignal
local Roact = require(game.ReplicatedFirst.Modules.Roact)

local PlayerStats = {
	Items = nil,-- THIS IS INJECTED
	__init = function(self, G)
		Game = G
		StatList = G.Load("PlayerStatList")
		ClassicSignal = G.Load("ClassicSignal")
		Players = G.Load("Players")
	end,
}

local RunService = game:GetService("RunService")
local IsClient = RunService:IsClient()

function PlayerStats:__build_signals(G, B)
	if G.CONTEXT == "SERVER" then
		PermStatChangedTransmitter = B:NewTransmitter("PermStatChangedTransmitter")
	end
end

local mt = { __index = PlayerStats }

local createdPlayerStats = setmetatable({}, {__mode = "v"})
StatList.createdPlayerStats = createdPlayerStats


function PlayerStats.new(plr): PlayerStats
	--Initialization is saved for when the datastore loads
	--No stat name should be the same, even from permStats to stats.

	local stats = {
		DS3Versions = {
			Latest = "v1",
			["v1"] = PlayerStats.Deserialize_v1,
		},

		--This is a flag that lets us know when to update unlockables
		StatChanged = false,

		TickData_Round = {},

		Player = plr,
		--These are the stats which are not derrived from gear and are carried over between saves.
		--No other stats are stored directly in datastores!
		--@Important These stats MAY NOT be modified directly for temporary purposes. Otherwise they could be saved and become permenant.
		PermStats = {},

		JoinedOn = tick(),
		LastSecondAdded = 0,
		PreviousTimePlayed = nil,
	}

	--Copy and initialize all stats with their default value
	for i,v in pairs(StatList.get_bases()) do
		stats[i] = v:Copy()
	end

	setmetatable(stats, mt)

	table.insert(createdPlayerStats, stats)

	return stats
end

function PlayerStats:Wipe(resetType)
	if resetType == Enums.ResetType.EachRound then
		self:StoreHistoryPoints()
	end

	for i,v in pairs(StatList.get_perms()) do
		if v.ResetType == resetType or v.ResetType == Enums.ResetType.Both then
			self:ChangeStat(i, v.DefaultValue, "set", true)
		end
	end
	for i,v in pairs(StatList.get_bases()) do
		if v.ResetType == resetType or v.ResetType == Enums.ResetType.Both then
			self:ChangeStat(i, v.DefaultValue, "set", false)
		end
	end
end

function PlayerStats:LoadData(data)
	data = data or {}

	for i,v in pairs(StatList.get_bases()) do
		self[i] = v:Copy()
	end

	for i,v in pairs(StatList.get_perms()) do
		self.PermStats[i] = v:Copy(data[tostring(v.ID)])
	end
end

function PlayerStats:GetStat(statName: string, isPerm)
	local stat
	if isPerm then
		stat = self.PermStats[statName]
	else
		stat = self[statName]
	end

	if not stat then
		error("Stat `" .. statName .. "` does not exist")
	end

	return stat
end

function PlayerStats:GetStatValue(statName: string, isPerm)
	local stat
	if isPerm then
		stat = self.PermStats[statName]
	else
		stat = self[statName]
	end

	if not stat then
		error("Stat `" .. statName .. "` does not exist")
	end

	return stat.Value
end

function PlayerStats:LazyGetBinding(statName: string, isPerm)
	local stat = self:GetStat(statName, isPerm)

	local bind = stat.Binding
	if not bind then
		local updBind
		bind, updBind = Roact.createBinding(stat.Value)

		stat.Binding = bind
		stat.UpdBinding = updBind
	end

	return bind
end

function PlayerStats:OnChange(statName: string, isPerm)
	local stat = self:GetStat(statName, isPerm)

	local Event = stat.Event
	if not Event then
		Event = ClassicSignal.new()
		stat.Event = Event
	end

	return Event
end

function PlayerStats:Serialize(IsFinalSize)
	local SavedStats = { }
	for i,v in pairs(self.PermStats) do
		local stat = StatList.ById[v.ID]
		if stat == nil or stat.Name ~= i then
			--The stat has been removed or changed IDs.
			--Changing IDs causes lost data. Don't do it.
			continue
		end

		SavedStats[tostring(v.ID)] = v.Value
	end

	return SavedStats
end

--[[ Datastore stuff ]]

function PlayerStats:Deserialize_v1(tbl, binding)
	--Note that `tbl` may be nil. That's fine.
	for i,v in pairs(StatList.get_perms()) do
		self.PermStats[i] = v:Copy(tbl[tostring(v.ID)])
	end

	return true
end


function PlayerStats:ChangeStat(statName, adjustment, opperation, isPerm)
	local stat = self:GetStat(statName, isPerm)
	local old = stat.Value

	if opperation == nil or opperation == "+" then
		stat.Value += adjustment
	elseif opperation == "/" then
		stat.Value /= adjustment
	elseif opperation == "*" then
		stat.Value *= adjustment
	elseif opperation == "set" then
		stat.Value = adjustment
	end

	self.StatChanged = true

	if stat.Value ~= old then
		if IsClient then
			local updBind = stat.UpdBinding
			if updBind then
				updBind(stat.Value)
			end
		else
			local BroadcastChange = StatList.ByName[statName].BroadcastChange
			if BroadcastChange == "All" then
				PermStatChangedTransmitter:TransmitAll(self.Player.UserId, statName, stat.Value)
			elseif BroadcastChange == "Me" then
				PermStatChangedTransmitter:Transmit(self.Player, self.Player.UserId, statName, stat.Value)
			elseif BroadcastChange then
				for _, plr in pairs(game.Players:GetPlayers()) do
					if plr ~= self.Player then
						PermStatChangedTransmitter:Transmit(plr, self.Player.UserId, statName, stat.Value)
					end
				end
			end
		end
	end

	local Event = stat.Event
	if Event then
		Event:Fire(stat.Value, old)
	end

	return stat.Value, old
end

function PlayerStats:GetPermStat(statName)
	local stat = self.PermStats[statName]

	if not stat then
		error("Attempt to retrieve non-existent stat value `" .. statName .. "`")
		return
	end

	return stat.Value
end


function PlayerStats:StatExists(statName)
	if self.PermStats[statName] == nil and self[statName] == nil then
		return false
	end
	return true
end

function PlayerStats:__load_gamestate(serial, loaded, after)
	for plr_id, stats in serial do
		Players.AddRemotePlayer(tonumber(plr_id), stats)
	end

	loaded()
end

function PlayerStats:__get_gamestate(plr)
	local t = { }

	for i,v in game.Players:GetPlayers() do
		if v == plr then
			continue
		end

		if not Game[v] then
			continue
		end

		if not Game[v].Loaded then
			continue
		end

		t[tostring(v.UserId)] = Game[v].PlayerStats:Serialize()
	end

	return t, "PlayerStats"
end

return PlayerStats

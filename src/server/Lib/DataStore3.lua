
local game = game

--[[
	Trait-like module for datastores

	Example of a binding being set up:
	```
		local DSkey = "P_" .. plr.UserId
		char.DataBinding = DS3.NewDataBinding(storeName, DSkey,
		{
		--Store name    object to be stored
			Inventory = char.Inventory,
		},
			char, OnPlayerLoadFinished
		)
	```

	Example Inventory as a DS3Compliant "trait":
	```
		local function Deserialize_v1( stored_tbl )
			--Version one stuff
		end
		local function Deserialize_v2( stored_tbl )
			--Version two stuff
		end
		char.Inventory = {
			StoreRetrieved = false

			--The Contents table is just for example, it is not part of the DS3 requirements.
			Contents = { 1, 0, 0, 3, 4, 0, 1 }

			DS3Versions = {
				Latest = "v2",
				["v1"] = Deserialize_v1,
				["v2"] = Deserialize_v2
			}

			Serialize = function()
				local tbl = { }

				for i = 1, Inventory.Contents, 1 do
					tbl[#tbl + 1] = Inventory.Contents[i]
				end

				return tbl
			end
		}
	```

About Versions:
	Every time you save something with a datastore, the layout of the data can only be understood with the correct Deserialize procedure, which is not surprising.
	To enable games to not be restricted to work with their data, we support multi-versioning of Deserialize functions so that you can
		convert to new layouts without abandoning any older data

	To add a new version, you create a new Deserialze function and point at it via the DS3Versions table, using the version tag as a key.
		You do not erase old versions, that undermines the purpose of the versioning system.

	Serialize functions don't get versions. They should always be writing the most up-to-date spec that you have a Deserialize function for.
		Because of that, older data layouts are automatically converted to new ones as long as they can be deserialized by the correct older function.

	The "current" version is specified by DS3Versions.Latest ; Any new saves will be tagged as that version since the Serialize funcs are intended to be up to date
		E.G. the above code will tag new saves as "v2"
]]

local Globals
local config
local PSA
local BindingsList
local Enums = _G.Game.Enums
assert(Enums)

local SaveInStudio

local DS3 = { }

local RunService = game:GetService("RunService")
local DataStores = game:GetService("DataStoreService")
local EnableAutosaves = true
local Autosave_Interval = 360.0
local IsStudio = RunService:IsStudio()

function DS3:__init(G)
	config = G.Load("BUILDCONFIG")
	PSA = G.Load("SparseList")
	Globals = G
	SaveInStudio = config.SaveDatastoresInStudio
	BindingsList = PSA.new()
end

function DS3:__build_signals(G, B)

end

function DS3:__finalize(G)
	if (IsStudio and not SaveInStudio) then
		return
	end

	game:BindToClose(function()
		DS3.FinalizeAll()
	end)
end

local Stores = { }

local ERR_NOT_DS3_OBJ = "Unserializable object in DS3 binding! Store: `%s` Master-key: `%s` Sub-key: `%s`"
local ERR_REBINDING = "Attempt to overwrite DS3 binding / Sub-key: `%s` for Master-key: `%s` (same binding passed twice?)" ---asdfasdfasdfasdfa
local ERR_NO_BINDING = "Binding is nil after Get()! Master-key: `%s` Sub-key: `%s`\nRaw data:"
local ERR_NO_VERSIONS = "DS3Compliant has no listed versions! Master-key: `%s` Sub-key: `%s`"
local ERR_INCOMPLETE_VERSIONS = "DS3Compliant has missing Deserialze function! Master-key: `%s` Sub-key: `%s` Version: `%s`"
local ERR_NO_LATEST_VERSION = "DS3Compliant has no specified latest version! Master-key: `%s` Sub-key: `%s`"
local ERR_INVALID_LATEST = "DS3Compliant has latest version, but version does not exist! Master-key: `%s` Sub-key: `%s` Version: `%s`"
local ERR_DESERIALIZE = "Deserialize failed! Master-key: `%s` Sub-key: `%s`"
local ERR_EARLY_SAVE = "DS3 saved before any Get(); possible data corruption! Store: `%s` Master-key: `%s`"
local ERR_NO_SAVE = "DataStore save failed with code: %s"
local ERR_NO_GET = "DataStore get failed with code: %s This DataBinding will not save!"
--This is a big error that's easy to make. All keys for a specific sub-table of a store (or sub-key) must be EITHER numerical indices OR string-keys
local ERR_INVALID_TBL = "DATA LOST!!! Keys to table were not exclusively strings or ints! Store: `%s` Master-key: `%s` Sub-key: `%s`"

local USER_MASTER_KEY_PREFIX = "P_"

type array<T> = 		{ [number]: T }
type JSONTable =		{ [string]: (string | number | boolean | array<(string | number | boolean)> ) }
type DeserializeFunc = 	( JSONTable ) -> boolean
type SerializeFunc = 	(DS3Compliant) -> { [string]: any }
type DS3Compliant = 	{ StoreRetrieved: boolean, DS3Versions: { [number]: number }, Serialize: SerializeFunc, Deserialize: DeserializeFunc }
type BindingList = 		{ [string]: DS3Compliant }

function DS3.NewDataBinding(StoreName: string, MasterKey: string, Bindings: BindingList, Parent: any, OnLoadFinished: (DS3Binding, any) -> nil, DeserializeOrder: array<string> ): DS3Binding
	assert(typeof(StoreName) == "string")
	assert(typeof(MasterKey) == "string")
	assert(typeof(Bindings) == "table")

	if not Stores[StoreName] then
		--TODO: Log the creation of new data stores to have a record of mis-named stores and keys
		Stores[StoreName] = DataStores:GetDataStore(StoreName)
	end

	local self = {
		--Metadata
		DeserializeOrder = DeserializeOrder,
		storeName = StoreName,
		masterKey = MasterKey,
		masterTbl = { [MasterKey] = { } },
		bindings = { },
		--The parent is used as an argument passed back to the callback function
		--A decision made to avoid the use of anonymous functions when possible
		Parent = Parent,

		--State
		_retrieved = false,
		_dontSave = false,

		--Callback events
		--TODO: @Undecided Should we even support this kind of design with datastores?
		_onGetList = { },
		_onSaveList = { },

		--DS Functions
		SaveAsync = DS3.SaveAsync,
		GetAsync = DS3.GetAsync,
		Finalize = DS3.Finalize,
		Reset = DS3.Reset,

		OnLoadFinished = OnLoadFinished
	}

	--Verify bindings are actual DS3Compliant before going forward
	for key, DS3Obj in pairs(Bindings) do
		if self.bindings[key] ~= nil then
			error(string.format(ERR_REBINDING, key, MasterKey))
		end

		if DS3Obj.Serialize == nil then
			error(string.format(ERR_NOT_DS3_OBJ, StoreName, MasterKey, key))
		end

		do
			if DS3Obj.DS3Versions == nil or type(DS3Obj.DS3Versions) ~= "table" then
				error(string.format(ERR_NO_VERSIONS, MasterKey, key))
			end

			for version, deserialize_func in pairs(DS3Obj.DS3Versions) do
				assert(typeof(version) == "string")
				if version == "Latest" then
					continue
				end

				if not deserialize_func or typeof(deserialize_func) ~= "function" then
					error(string.format(ERR_INCOMPLETE_VERSIONS, MasterKey, key, tostring(version)))
				end
			end

			local latest = DS3Obj.DS3Versions.Latest
			if not latest then
				error(string.format(ERR_NO_LATEST_VERSION, MasterKey, key))
			end

			local latest_found = false
			for version, _ in pairs(DS3Obj.DS3Versions) do
				if version == latest then
					latest_found = true
					break
				end
			end

			if not latest_found then
				error(string.format(ERR_INVALID_LATEST, MasterKey, key, tostring(latest)))
			end
		end

		self.bindings[key] = DS3Obj
	end

	BindingsList:insert(self)

	self:GetAsync()

	return self
end

function DS3.Connect_OnGet(self: DS3Binding, fn: (DS3Binding) -> nil)
	self._onGetList[#self._onGetList + 1] = fn
end
function DS3.Connect_OnSave(self: DS3Binding, fn: (DS3Binding) -> nil)
	self._onSaveList[#self._onSaveList + 1] = fn
end

--These should be avoided in my opinion
function DS3.Disconnect_OnGet(self: DS3Binding, fn: (DS3Binding) -> nil)
	table.remove(self._onGetList, table.find(self._onGetList, fn))
end
function DS3.Disconnect_OnSave(self: DS3Binding, fn: (DS3Binding) -> nil)
	table.remove(self._onSaveList, table.find(self._onSaveList, fn))
end

--[[
	In a perfect world, this function would not be necessary or could be safely optimized out of the run-time
]]
local function is_array(t)
	local i = 0
	for _ in pairs(t) do
		i += 1
		if t[i] == nil then
			return false
		end
	end
	return true
end

local function verify_table_recursive(tbl: table): boolean
	local str_found, int_found = false, false
	local checked_array = false

	for i, v in pairs(tbl) do
		local _type = type(i)
		if _type == "string" then
			str_found = true
		elseif _type == "number" then
			int_found = true
		end

		if str_found == true and int_found == true then
			return false
		elseif int_found and not checked_array then
			checked_array = true
			if not is_array(tbl) then
				return false
			end
		end

		if type(v) == "table" then
			local sub_valid = verify_table_recursive(v)

			if not sub_valid then
				return false
			end
		end
	end

	return true
end

local function _SaveAsync(self: DS3Binding, callback: (boolean) -> nil)
	if not self._retrieved then
		warn(string.format(ERR_EARLY_SAVE, self.storeName, self.masterKey), "\nSave skipped!")
		return
	end

	local IsFinalSize = false
	if callback and callback == OnFinalSave then
		IsFinalSize = true
	end

	local masterKey = self.masterKey
	for key, DS3Obj in pairs(self.bindings) do
		local serial_data = DS3Obj.Serialize( DS3Obj, IsFinalSize )

		local ObjVersions = DS3Obj.DS3Versions
		if not ObjVersions.Latest or not ObjVersions[ObjVersions.Latest] then
			warn(string.format("SubStore %s has no valid latest version", key))
		end

		serial_data["__VERSION"] = ObjVersions.Latest

		local is_valid = verify_table_recursive(serial_data)

		if is_valid then
			self.masterTbl[masterKey][key] = serial_data
		else
			warn(string.format(ERR_INVALID_TBL, self.storeName, self.masterKey, key))
			print(serial_data)
		end
	end

	-- Config checks
	if game.PlaceId ~= config.PlaceId or (IsStudio and not SaveInStudio) then
		-- This is here so that if you're doing datastore work, or datastore work needs to be done
		-- we won't overwrite our data instantly
		warn("Skipping DS3 save because this is in a test environment")
		warn("Comment out this block to bypass this safeguard")
		return
	end

	if (self._dontSave == true) then
		return
	end

	-- Good to go, save
	local store = Stores[self.storeName]
	local success, code = pcall( store.SetAsync, store, masterKey, self.masterTbl )
	if not success then
		warn(string.format(ERR_NO_SAVE, code))
	end

	if callback then
		callback(self, success)
	end
end

function DS3.SaveAsync(self: DS3Binding, callback: (boolean) -> nil)

	local success, err = coroutine.resume(coroutine.create(_SaveAsync), self, callback)

	if not success then
		error(err)
	end
end

local function _getIndividualBinding(self, key, DS3Obj, data)
	--For uninitialized saves, sub_store can be nil. It's still important to process because the deserialize func is a good initializer
	--  To make things easier, an empty table is passed instead of nil
	local sub_store = data[key] or { }
	if config.WipeStoresOnStart then
		sub_store = { }
	end

	if DS3Obj == nil then
		error(string.format(ERR_NO_BINDING, self.masterKey, key), sub_store)
	end

	local version = sub_store["__VERSION"]
	--Deserialize funcs don't need to see or worry about handling the __VERSION field, so we'll wipe it.
	sub_store["__VERSION"] = nil
	--If a version is somehow missing, fallback to the latest.
	version = version or DS3Obj.DS3Versions.Latest

	local successA, successB = pcall(DS3Obj.DS3Versions[version],  DS3Obj, sub_store, self )
	if successA and successB then
		DS3Obj.StoreRetrieved = true
	else
		warn(string.format(ERR_DESERIALIZE, self.masterKey, key))
		warn(successA)
		warn(successB)
	end
end

local function _GetAsync(self: DS3Binding)
	local store = Stores[self.storeName]
	local success, ret = pcall( store.GetAsync, store, self.masterKey )
	if success == false then
		warn(string.format(ERR_NO_GET, ret))
		self._dontSave = true
		ret = { }
	end

	ret = ret or { }
	local data = ret[self.masterKey] or { }

	for i = 1, #self.DeserializeOrder do
		local key = self.DeserializeOrder[i]
		_getIndividualBinding(self, key, self.bindings[key], data)
	end

	for key, DS3Obj in pairs( self.bindings ) do
		if not table.find(self.DeserializeOrder, key) then
			_getIndividualBinding(self, key, DS3Obj, data)
		end
	end

	self._retrieved = true

	if self.OnLoadFinished then
		self.OnLoadFinished( self, self.Parent )
	end
end

function DS3.GetAsync(self: DS3Binding, bypass_cache: boolean)
	-- TODO: Make this an enum
	while Globals.LOADING_CONTEXT ~= Enums.LOAD_CONTEXTS.FINISHED do
		-- In case the client sends this before we're even ready
		task.wait()
	end

	if self._retrieved and not bypass_cache then
		warn("Attempt to retrieve store multiple times")
		return
	end

	--coroutine.wrap is broken and will not execute the co before continuing this function. I suspect it's going straight to the task scheduler
	local success, err = coroutine.resume(coroutine.create(_GetAsync), self)

	if not success then
		error(err)
	end
end

function DS3.GetStoreName()
	local storeName = Enums.DataStores.Players
	--Lets be sure we're not going to mix test data with production data
	if RunService:IsStudio() then
		storeName = Enums.DataStores.Test
	end

	return storeName
end

function DS3.GetUserIdMasterKey(userId)
	return USER_MASTER_KEY_PREFIX .. tostring(userId)
end

function DS3.OffserverUpdateAsync(storeName, masterKey, moduleKey, updateFunction)
	local store: GlobalDataStore = Stores[storeName]

	local success, err = pcall(store.UpdateAsync, store, masterKey, function(data)
		updateFunction(data[moduleKey])
		return data
	end)

	if err then
		warn("UpdateAsync failed with message: " .. err .. "\n" .. debug.traceback())
	end

	return success
end

function OnFinalSave(self: DS3Binding, success: boolean)
	if success then
		BindingsList:find_remove( self )
	end
end

function DS3.Finalize(self)
	self:SaveAsync(OnFinalSave)
end

function DS3.FinalizeAll()
	if IsStudio == true and SaveInStudio == false then
		return
	end

	for i,DataBinding in pairs(BindingsList.Contents) do
		DataBinding:SaveAsync(OnFinalSave)
	end
end

function DS3.Reset(self)
	local store = Stores[self.storeName]
	local success, code = pcall( store.SetAsync, store, self.masterKey, {} )
	if not success then
		warn(string.format(ERR_NO_SAVE, code))
	end
end

local function AutoSave()
	task.wait(Autosave_Interval)

	for _,binding in pairs(BindingsList.Contents) do
		binding:SaveAsync()
	end

	coroutine.wrap(AutoSave)()
end

if EnableAutosaves then
	coroutine.wrap(AutoSave)()
end

do
	--[[ Debug events for client ]]
	local DebugDS3SaveEvent = Instance.new("RemoteEvent", game.ReplicatedStorage)
	DebugDS3SaveEvent.Name = "DebugDS3SaveEvent"
	local DebugDS3GetEvent = Instance.new("RemoteEvent", game.ReplicatedStorage)
	DebugDS3GetEvent.Name = "DebugDS3GetEvent"

	DebugDS3SaveEvent.OnServerEvent:Connect(function(plr)
		if RunService:IsStudio() then
			Globals[plr].DataBinding:SaveAsync()
		end
	end)
	DebugDS3GetEvent.OnServerEvent:Connect(function(plr)
		--This will almost certainly cause fatal errors and corrupt your inventory but you can do it if you really like
		if RunService:IsStudio() then
			Globals[plr].DataBinding:GetAsync( true )
		end
	end)
end

return DS3
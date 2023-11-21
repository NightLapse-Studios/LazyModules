--[[
	Abilities are comprised of `ClientUse` function which spawns game mechanis such as components.
	Components and such handle their own processing, but are associated with a `Usage` of an `Ability`
	When a Component hits an object, its associated `Usage` is sent to the server via an ID.

	Usage IDs are in sync across client and server, enabled by storing usages per-player rather than in one giant server table
	Usages track when they should expire on the client by looking at ther "owned" instances and if they have been
		destroyed yet. Destruction is detected by checking if the parent of the instance has become nil.

	Components not spawned from a usage will not be associated with any process on the server, and cannot do damage

	Abilities.new("name", "category", interface)
		:ArmFunc(_G.Game.Enums.META_CONTEXTS.SERVER, function(self, ...)

		end)
		:DisarmFunc(_G.Game.Enums.META_CONTEXTS.SERVER, function(self, ...)

		end)
		:UseFunc(_G.Game.Enums.META_CONTEXTS.SERVER, function(usage, use_args)

			return true
		end)
		:LateUseFunc(function(usage, use_args)

		end)
		:CleanupFn(_G.Game.Enums.META_CONTEXTS.SERVER, function(usage)

		end)
		:GetUseArgs(function(plr, usage)
			return "CANCEL" or 1, 2, 3
		end)
		:ShouldAccept(function(plr, ability, args)
			return false
		end)
		:AddResolvableState("Damage", function(self, plr, usage, ...: any)
			return
		end)
		:UpdateFunc(function(usage, dt)

		end)
		:GetComponentModelFn(function(ability, usage)
			return model
		end)
		:SetCooldown(1)
		:SetKillStreak(8)
		:SetDoesConsumeOnUse(false)
		:CancelOnDeath(true)
		:NoAutoReplication(true)
		:ChecksWeaponCompatibility(false)
]]

local mod = {
	Usages = false,
	AsyncList = _G.Game.PreLoad(game.ReplicatedFirst.Util.AsyncList).new(1)
}

function mod.GetAsync(name, cb)
	mod.AsyncList:get(name, cb)
end

local Game

local Weapons
local Cooldowns
local PlayerLib
local PlayerRegistry
local IDList
local Config = _G.Game.PreLoad(game.ReplicatedFirst.Util.BUILDCONFIG)

local AbilityUsedTransmitter
local AbilityUsedBroadcaster
local AbilityExpiredBroadcaster
local AbilityArmedTransmitter
local AbilityDisarmedTransmitter
local Usages

local Players = game:GetService("Players")

local Meta = _G.Game.Meta
local META_CONTEXTS = _G.Game.Enums.META_CONTEXTS

local next_id = 1


local RegisteredAbilities = { }


local function no_op_func()
	return nil
end

local Usage = { }

local mt_AbilityUsage = { __index = Usage }

function Usage:NextInteger(min, max)
	return self.RNG:NextInteger(min, max)
end
function Usage:NextNumber()
	return self.RNG:NextNumber()
end
function Usage:NextUnitVector()
	return self.RNG:NextUnitVector()
end

function Usage:GetComponentModel()
	local a = self.Ability
	return a:__GetComponentModelFn(self)
end

function Usage:OwnInstance(ins: Instance)
	table.insert(self.Allocated, ins)
	
	ins.Destroying:Connect(function()
		table.remove(self.Allocated, table.find(self.Allocated, ins))
	end)
end

function Usage:OwnComponent(component: table, opt_id)
	if opt_id then
		assert(Game.CONTEXT == "SERVER")
		self.Components[opt_id] = component
		return opt_id
	else
		local ID = self.Components:add(component)
		return ID
	end
end

function Usage:DisownComponent(id_or_item: number|table)
	-- If this function is updated to do more than simply un-associate the component, then some server code which does
	-- does this manually will need to be updated in Component.lua
	self.Components:remove(id_or_item)
end

function Usage:HasActiveInstances()
	for i,v in self.Allocated do
		if typeof(v) == "Instance" then
			if v.Parent then
				return true
			else
				self.Allocated[i] = nil
			end
		end
	end

	return false
end

function Usage:Cancel(broadcast: boolean?)
	-- print("Cancel", Game.CONTEXT)
	if self.__Destroyed then
		return
	end

	self.__Destroyed = true

	for i = #self.Allocated, 1, -1 do
		self.Allocated[i]:Destroy()
	end

	for i,v in self.Components:get_obj_list() do
		v:Destroy()
	end

	warn("CANCELED")

	if self.Ability.__CleanupFn then
		self.Ability.__CleanupFn(self)
	end

	Usages:remove(self.Owner, self.ID)

	if broadcast then
		if (Game.CONTEXT == "CLIENT" and self.Owner ~= game.Players.LocalPlayer) then
			warn("Weird call to Usage:Cancel with broadcast == true")
			warn(debug.traceback())
		end

		if Game.CONTEXT == "SERVER" then
			AbilityExpiredBroadcaster:BroadcastLikePlayer(self.Owner, self.ID)
		else
			AbilityExpiredBroadcaster:Broadcast(self.ID)
		end
	end
end

function Usage:SetActive(state: boolean)
	if state == nil then state = false end
	self.__IsActive = state
end

--[[
	Use data's design is not final.
	This is just what seems reasonable for the first implementation.
]]
local function new_use_data(ability, owner, ...)
	local external_args = { ... }

	local seed = math.random() * 9223372036854776000

	local use_data = {
		ID = next_id,
		Owner = owner,
		Ability = ability,
		UseCFrame = owner.Character.PrimaryPart.CFrame,

		Args = false,
		-- A buffer for storing `Parts` which are tracked so that we know when the abiliti is running or not
		Allocated = { },
		-- A list of Components which are tracked so that we can associate a usage with its constituents
		Components = IDList.new(),
		__IsActive = false,
		__Destroyed = false,

		RNG = Random.new(seed),
		Seed = seed,
		Created = tick(),
	}

	use_data.Args = { ability.__GetUseArgsFn(owner, use_data, external_args) }

	if use_data.Args[1] == "CANCEL" then
		-- The args were not able to be gathered
		-- Usually a benign case where the player is e.g. not pointing at an object when one is required
		return
	end

	Usages:insert(owner, next_id, use_data)
	next_id += 1

	setmetatable(use_data, mt_AbilityUsage)

	return use_data, seed
end



--[[
	When a remote player uses
]]
local function use_data_from_args(ability, owner, id, seed, args)

	assert(owner ~= game.Players.LocalPlayer, "use_data_from_args exists to support remote players, not the local player")

	local use_data = {
		ID = id,
		Owner = owner,
		Ability = ability,
		UseCFrame = owner.Character.PrimaryPart.CFrame,

		Args = args,
		Allocated = { },
		Components = IDList.new(),
		__IsActive = false,

		RNG = Random.new(seed),
		Seed = seed,
		Created = tick(),
	}

	Usages:insert(owner, id, use_data)

	setmetatable(use_data, mt_AbilityUsage)

	return use_data
end

function mod.IsReady(self, plr)
	if self.Cooldown then
		if not Cooldowns.IsPastCooldown(self.Name, plr) then
			return false
		end
	end

	return true
end

local mt_Ability = Meta.FUNCTIONAL_METATABLE()
	:METHOD("Arm", function(self, ...)
		if Game.CONTEXT == "SERVER" then
			local plr = select(1, ...)
			if not plr then
				error("No player provided to Ability:Arm\n\tProbably called :Arm manually on the server (don't do that)")
			end

			if self.__Armed[plr] then return end

			local ret = self:__ArmFn(...)
			
			self.__Armed[plr] = true
			
			return ret
		else
			if self.__Armed == true then return end
			
			AbilityArmedTransmitter:Transmit(self.Name)
			local ret = self:__ArmFn(...)

			self.__Armed = true

			return ret
		end
	end)
	:METHOD("Disarm", function(self, ...)
		if Game.CONTEXT == "SERVER" then
			local plr = select(1, ...)
			if not self.__Armed[plr] then return end

			local ret = self:__DisarmFn(...)
			
			self.__Armed[plr] = nil
			
			return ret
		else
			if self.__Armed == false then return end
			
			AbilityDisarmedTransmitter:Transmit(self.Name)
			local ret = self:__DisarmFn(...)

			self.__Armed = false

			return ret
		end
	end)
	:METHOD("CanArm", function(self, plr)
		if self.__CanArmFn then
			return self:__CanArmFn(plr)
		end

		return true
	end)
	:METHOD("Use", function(self, ...)
		local plr = game.Players.LocalPlayer

		if not mod.IsReady(self, plr) then
			warn("Rejected 5")
			return
		end

		local use_data, seed = new_use_data(self, plr, ...)

		if not use_data then
			warn("Rejected 6")
			return
		end

		self:BeginCooldown(plr)

		--Order sensitive due to the protocol
		AbilityUsedTransmitter:Transmit(self.Name, use_data.ID, seed, use_data.Args)

		use_data:SetActive(true)
		-- A little hack to backport old abilities that were originally designed to have their instances tracked
		-- for lifecycle functionaltiy. Older code returns nil, new code returns true or false
		local is_still_active = self.__UseFn(use_data, use_data.Args)

		print("Ability Returned:  ", is_still_active, "  From Use Func.")

		use_data:SetActive(is_still_active)

		return use_data
	end)
	:METHOD("RemoteUse", function(self, plr, usage_id, seed, args)
		local use_data = use_data_from_args(self, plr, usage_id, seed, args)
		self.__UseFn(use_data, use_data.Args)
		return use_data
	end)
	:METHOD("ServerUse", function(self, plr, id, seed, args)
		local use_data = use_data_from_args(self, plr, id, seed, args)
		if self.__UseFn then
			self.__UseFn(use_data, args)
		end
		return use_data
	end)
	:METHOD("ResolveState", function(self, state_name: string, plr, usage, ...)
		local state_func = self.__ResolvableStates[state_name]
		if state_func then
			return state_func(self, plr, usage, ...)
		else
			--warn("Attempt to resolve state `" .. state_name .. "` for ability `" .. self.Name .. "` but the state doesn't exist")
		end
	end)
	:METHOD("BeginCooldown", function(self, plr)
		if self.Cooldown then
			Cooldowns.StartCooldown(self.Cooldown, self.Name, plr)
		end
	end)
	:METHOD("Destroy", function(self)
		RegisteredAbilities[self.Name] = nil
		mod.AsyncList:remove(self.Name)

		for plr, t in Usages.Registry do
			for i, usage in t do
				if usage.Ability == self and not usage.__Destroyed then
					usage:Cancel()
				end
			end
		end
	end)
	:FINISH()

local mt_AbilityBuilder = Meta.CONFIGURATOR(mt_Ability)
	:SETTER(META_CONTEXTS.BOTH, "SetCooldown", "Cooldown")
	:SETTER(META_CONTEXTS.AUTO, "UseFn", "__UseFn")
	:SETTER(META_CONTEXTS.BOTH, "LateUseFn", "__LateUseFn")
	:SETTER(META_CONTEXTS.AUTO, "ArmFn", "__ArmFn")
	:SETTER(META_CONTEXTS.AUTO, "DisarmFn", "__DisarmFn")
	:SETTER(META_CONTEXTS.BOTH, "CanArmFn", "__CanArmFn")
	:SETTER(META_CONTEXTS.CLIENT, "GetUseArgsFn", "__GetUseArgsFn")
	:SETTER(META_CONTEXTS.SERVER, "ShouldAcceptFn", "__ShouldAcceptFn")
	:SETTER(META_CONTEXTS.CLIENT, "UpdateFn", "__UpdateFn")
	:SETTER(META_CONTEXTS.AUTO, "CleanupFn", "__CleanupFn")
	:SETTER(META_CONTEXTS.SERVER, "CancelOnDeath", "__CancelOnDeath")
	:SETTER(META_CONTEXTS.BOTH, "GetComponentModelFn", "__GetComponentModelFn")
	:NAMED_LIST(META_CONTEXTS.BOTH, "AddResolvableStateFn", "__ResolvableStates")
	:SETTER(META_CONTEXTS.SERVER, "NoAutoReplication", "__NoAutoReplication")
	:FINISH()

function mod.new(name: string, category: string, opt_interface: table?)
	assert(RegisteredAbilities[name] == nil, "Ability '" .. name .. "' already exists")

	if Config.LogNewAbilities then
		print("Ability `" .. name .. "` created")
	end

	local defaultArmed = Game.CONTEXT == "SERVER" and 
		setmetatable({}, {__mode = "k"})
		or false

	local a = {
		Category = category,
		Name = name,
		Cooldown = false,
		-- Set an optional interface so that a list of functions can be used, usually to check if an ability can be used
		Interface = opt_interface or false,

		__ShouldAcceptFn = false,
		__UseFn = false,
		__GetUseArgsFn = false,
		__UpdateFn = false,
		-- This is set from *either* ClientCleanup or ServerCleanup in the builder, depending on context
		__CleanupFn = false,
		__ArmFn = no_op_func,
		__DisarmFn = no_op_func,
		__CanArmFn = false,
		__ResolvableStates = { },

		__Armed = defaultArmed,

		__NoAutoReplication = false,
		-- This fires whenever the player is despawned for any reason.
		__CancelOnDeath = false,
		-- Used by the server primarily, to get copies of the models used for components by some ability
		__GetComponentModelFn = no_op_func,
	}

	setmetatable(a, mt_AbilityBuilder)

	RegisteredAbilities[name] = a
	mod.AsyncList:provide(a, name)
	task.wait()

	return a
end

function mod.GetActiveUsage(ability, plr)
	if plr then
		for i, usage in Usages.Registry[plr] do
			if usage.Ability == ability and not usage.__Destroyed then
				return usage
			end
		end
	else
		for plr, t in Usages.Registry do
			for i, usage in t do
				if usage.Ability == ability and not usage.__Destroyed then
					return usage
				end
			end
		end
	end
end



local function ServerAbilityHandler(plr, name, client_use_id, seed, args)
	if not (plr.Character:GetAttribute("Health") > 0) then
		AbilityUsedTransmitter:Transmit(plr, false, client_use_id)
		return
	end

	local a = RegisteredAbilities[name]
	if not a then
		warn("Rejected 1")
		AbilityUsedTransmitter:Transmit(plr, false, client_use_id)
		return
	end

	if not mod.IsReady(a, plr) then
		AbilityUsedTransmitter:Transmit(plr, false, client_use_id)
		return
	end

	if not a.__Armed[plr] then
		warn("Rejected 4")
		AbilityUsedTransmitter:Transmit(plr, false, client_use_id)
		return
	end

	local should_accept = true
	if a.__ShouldAcceptFn then
		should_accept = a.__ShouldAcceptFn(plr, a, args)
	end

	if not should_accept then
		warn("Rejected 5")
		AbilityUsedTransmitter:Transmit(plr, false, client_use_id)
		return
	end

	local usage = a:ServerUse(plr, client_use_id, seed, args)
	usage.ID = client_use_id

	-- success
	AbilityUsedTransmitter:Transmit(plr, true, client_use_id)

	if not a.__NoAutoReplication then
		AbilityUsedBroadcaster:BroadcastLikePlayer(plr, client_use_id, name, seed, args)
	end

	a:BeginCooldown(plr)
end

local function DidServerAccept(answer: boolean, client_id: number, server_id: number)
	--This function running implies that we are the owners of the ability
	local usage = Usages:get(game.Players.LocalPlayer)[client_id]

	if not answer then
		if usage then
			print("Rejected usage: " .. client_id)
			usage:Cancel(false)
		end

		return
	end

	print("Accepted usage: " .. client_id)
end



function mod:__build_signals(G, B)
	AbilityUsedTransmitter = B:NewTransmitter("AbilityUsedTransmitter")
		:ServerConnection(ServerAbilityHandler)
		:ClientConnection(DidServerAccept)

	AbilityUsedBroadcaster = B:NewBroadcaster("AbilityUsedBroadcaster")
		:ClientConnection(function(plr, client_use_id, name, seed, args)
			if plr == game.Players.LocalPlayer then
				return
			end

			local a = RegisteredAbilities[name]
			a:RemoteUse(plr, client_use_id, seed, args)
		end)

	AbilityExpiredBroadcaster = B:NewBroadcaster("AbilityExpiredBroadcaster")
		:ServerConnection(function(plr, server_id)
			local usage = Usages:get(plr)[server_id]

			if not usage then return end
			usage:Cancel(false)
		end)
		:ClientConnection(function(plr, client_use_id)
			local usage = Usages:get(plr)[client_use_id]
			if not usage then return end
			usage:Cancel(false)
		end)

	AbilityArmedTransmitter = B:NewTransmitter("AbilityArmedTransmitter")
		:ClientConnection(function(did_arm: boolean, opt_name: string?)
			if not did_arm then
				local a = RegisteredAbilities[opt_name]
				-- a:Disarm()
			end
		end)
		:ServerConnection(function(plr, name)
			local a = RegisteredAbilities[name]

			if a:CanArm() then
				a:Arm(plr)
				AbilityArmedTransmitter:Transmit(plr, true)

				return
			end

			AbilityArmedTransmitter:Transmit(plr, false, name)
		end)

	AbilityDisarmedTransmitter = B:NewTransmitter("AbilityDisarmedTransmitter")
		:ServerConnection(function(plr, name)
			local a = RegisteredAbilities[name]
			a:Disarm(plr)
		end)
end

function mod.CancelAllUsages(plr)
	if Game.CONTEXT ~= "SERVER" then
		error()
	end

	for i,v in Usages:get(plr) do
		if v.Ability.__CancelOnDeath == true then
			v:Cancel(true)
		end
	end
end

function mod.ResetAllCooldowns()
	if Game.CONTEXT ~= "SERVER" then
		error()
	end

	for _, plr in Players:GetPlayers() do
		for name, _ in RegisteredAbilities do
			Cooldowns.CancelCooldown(name, plr)
		end
	end
end

function mod:__init(G)
	Game = G

	PlayerLib = G.Load("PlayerLib")
	Weapons = G.Load("Weapons")
	PlayerRegistry = G.Load("PlayerRegistry")
	IDList = G.Load("IDList")
	Cooldowns = G.Load("Cooldowns")
	Config = G.Load("BUILDCONFIG")

	mod.Usages = PlayerRegistry.new(function() return { } end)
		:Insert(function(self, plr, i, v)
			return table.insert(self.Registry[plr], i, v)
		end)
		:Remove(function(self, plr, i)
			self.Registry[plr][i] = nil
		end)

	Usages = mod.Usages
end

local function Update(dt)
	if Game.CONTEXT ~= "CLIENT" then
		error()
	end

	local plr_usages = Usages.Registry[game.Players.LocalPlayer]
	for i, usage: SparseList in plr_usages do
		if usage.Owner ~= game.Players.LocalPlayer then
			-- Should be impossible
			usage:Cancel(false)
		end

		if usage.__IsActive == false and #usage.Allocated <= 0 and usage.Components.List.size == 0 then
			usage:Cancel(true)
			continue
		end

		if usage.__UpdateFn then
			usage:__UpdateFn(dt)
		end
	end
end

function mod:__finalize(G)
	if Game.CONTEXT == "CLIENT" then
		game:GetService("RunService").RenderStepped:Connect(Update)
	end
end

function mod:__get_gamestate(plr)
	local serial = {}

	for otherPlr, t in Usages.Registry do
		for i, usage in t do
			if usage.Ability.__LateUseFunc then
				serial[otherPlr] = serial[otherPlr] or {}
				table.insert(serial[otherPlr], {
					usage.ID,
					usage.Args,
					usage.Seed,
					usage.Created,
					usage.Ability.Name,
				})
			end
		end
	end
end

function mod:__load_gamestate(serial, loaded, after)
	after("PlayerStats", function()
		for plr, t in serial do
			local usage_id, args, seed, Created, abilityName = table.unpack(t)

			local ability = RegisteredAbilities[abilityName]

			local use_data = use_data_from_args(ability, plr, usage_id, seed, args)
			use_data.Created = Created

			-- TODO: This needs some sort of a dt argument to let LateUse do anything other than cosmetic states
			-- However it can still be used to e.g. play looping animations on the owner of the usage
			ability.__LateUseFn(use_data, use_data.Args)
		end

		loaded()
	end)
end

function mod:__run()
	local l = 0

	for i,v in RegisteredAbilities do
		l += 1
	end

	print(l .. " registered abilities as of the __run step")
end

return mod
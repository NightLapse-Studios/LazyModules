local RunService = game:GetService("RunService")
local IsClient = RunService:IsClient()
local IsServer = RunService:IsServer()

local mod = { }
local mt_EMPTY = { }

local BUILDER = { }
local mt_BUILDER = { __index = BUILDER }


local Enums = require(game.ReplicatedFirst.Lib.Enums)
local MetaContexts = Enums.MetaContexts
local RUN_CONTEXT = if IsServer then MetaContexts.SERVER else MetaContexts.CLIENT

function mod.FUNCTIONAL_METATABLE()
	local mt_builder = { }

	setmetatable(mt_builder, mt_BUILDER)

	return mt_builder
end

function BUILDER:METHOD(identifier: string, func)
	self[identifier] = func
	return self
end

function BUILDER:FINISH()
	-- Maybe a better way to implement this than to allocate another table? It's tricky to get to work
	local mt = { __index = self }
	setmetatable(mt, mt)

	return mt
end




local CONFIGURATOR = { }
local mt_CONFIGURATOR = { __index = CONFIGURATOR }

local function strategize(strategy: Enums.MetaContext, thing: any)
	if strategy == MetaContexts.BOTH then
		return thing
	elseif strategy == MetaContexts.CLIENT and IsClient then
		return thing
	elseif strategy == MetaContexts.SERVER and IsServer then
		return thing
	elseif strategy == MetaContexts.AUTO then
		error("META_CONTEXTS.AUTO describes accepted contexts, so cannot be used as a strategy")
	end
end

local function make_strategy(fn_identifier: string, strategy: Enums.MetaContext, inner_func: (any)->any)
	if strategy == MetaContexts.BOTH then
		return function(self, ...)
			inner_func(self, ...)

			return self
		end
	elseif strategy == MetaContexts.CLIENT then
		return function(self, ...)
			if RUN_CONTEXT == MetaContexts.CLIENT then
				inner_func(self, ...)
			end

			return self
		end
	elseif strategy == MetaContexts.SERVER then
		return function(self, ...)
			if RUN_CONTEXT == MetaContexts.SERVER then
				inner_func(self, ...)
			end

			return self
		end
	elseif strategy == MetaContexts.AUTO then
		return function(self, context: Enums.MetaContext, ...)
			if context == MetaContexts.AUTO then
				warn("Makes no sense to passe META_CONTEXTS.AUTO to the auto-configurator func\n\tUse BOTH instead?")
				return self
			end

			if context == RUN_CONTEXT or context == MetaContexts.BOTH then
				inner_func(self, ...)
			end

			return self
		end
	end
end

function mod.CONFIGURATOR(target_obj: { [any]: any })
	assert(target_obj, "Configurator must know what it is going to transform into after it's finished")

	local mt_configurator = {
		-- This field stores the metatable that self::FINISH will transform the object into
		__final_mt = target_obj
	}

	setmetatable(mt_configurator, mt_CONFIGURATOR)

	return mt_configurator
end

function CONFIGURATOR:SETTER(context: Enums.MetaContext, fn_identifier: string, field_identifier: string)
	assert(typeof(fn_identifier) == "string")
	assert(typeof(field_identifier) == "string")

	-- The end result of this operation is a self[fn_identifier] = <some function which can set 
	local f = function(_self, value)
		_self[field_identifier] = value
	end
	local strategy = make_strategy(fn_identifier, context, f)
	self[fn_identifier] = strategy

	return self
end

function CONFIGURATOR:NAMED_LIST(context: Enums.MetaContext, fn_identifier: string, field_identifier: string)
	assert(typeof(fn_identifier) == "string")
	assert(typeof(field_identifier) == "string")

	local f = function(_self, name, value)
		_self[field_identifier][name] = value
	end
	local strategy = make_strategy(fn_identifier, context, f)
	self[fn_identifier] = strategy

	return self
end

function CONFIGURATOR:FINISHER(context: Enums.MetaContext, fn_finisher)
	self.__FINISHER = strategize(context, fn_finisher)

	return self
end

function CONFIGURATOR:FINISH()
	assert(self.__final_mt ~= -1, "Use the FINISHER function to configure what this configurator will transform into")

	local mt = { __index = self }
	setmetatable(mt, mt)
	setmetatable(self, mt_EMPTY)

	self.FINISH = function(obj)
		if self.__FINISHER then
			self:__FINISHER(obj)
		end

		setmetatable(obj, self.__final_mt)

		return obj
	end

	return mt
end


function mod.__tests(G, T)
	local UNINIT_VALUE = -1

	local obj = {}
	function obj.test()
		return 1
	end

	local cfg = mod.CONFIGURATOR({ __index = obj})
		:SETTER(MetaContexts.CLIENT, "ClientTest", "__ClientTest")
		:SETTER(MetaContexts.SERVER, "ServerTest", "__ServerTest")
		:SETTER(MetaContexts.AUTO, "AutoTest", "__AutoTest")
		:SETTER(MetaContexts.BOTH, "BothTest", "__BothTest")
		:FINISH()

	local function new_test_cfg()
		return setmetatable(
			{
				__ClientTest = UNINIT_VALUE,
				__ServerTest = UNINIT_VALUE,
				__AutoTest = UNINIT_VALUE,
				__BothTest = UNINIT_VALUE
			},
			cfg
		)
	end

	T:Test( "Make contextual Configurators", function()
		local client_targeted = new_test_cfg()
			:ClientTest(1)
			:ServerTest(2)
			:AutoTest(MetaContexts.CLIENT, 3)
			:BothTest(4)
			:FINISH()

		local server_targeted = new_test_cfg()
			:ClientTest(1)
			:ServerTest(2)
			:AutoTest(MetaContexts.SERVER, 3)
			:BothTest(4)
			:FINISH()

		local both_targeted = new_test_cfg()
			:ClientTest(1)
			:ServerTest(2)
			:AutoTest(MetaContexts.BOTH, 3)
			:BothTest(4)
			:FINISH()

		if RUN_CONTEXT == MetaContexts.CLIENT then
			T:WhileSituation( "on the client",
				T.Equal, client_targeted.__ClientTest, 1,
				T.Equal, client_targeted.__ServerTest, UNINIT_VALUE,
				T.Equal, client_targeted.__AutoTest, 3,
				T.Equal, client_targeted.__BothTest, 4,

				T.Equal, server_targeted.__ClientTest, 1,
				T.Equal, server_targeted.__ServerTest, UNINIT_VALUE,
				T.Equal, server_targeted.__AutoTest, UNINIT_VALUE,
				T.Equal, server_targeted.__BothTest, 4,

				T.Equal, both_targeted.__ClientTest, 1,
				T.Equal, both_targeted.__ServerTest, UNINIT_VALUE,
				T.Equal, both_targeted.__AutoTest, 3,
				T.Equal, both_targeted.__BothTest, 4
			)
		elseif RUN_CONTEXT == MetaContexts.SERVER then
			T:WhileSituation( "on the server",
				T.Equal, client_targeted.__ClientTest, UNINIT_VALUE,
				T.Equal, client_targeted.__ServerTest, 2,
				T.Equal, client_targeted.__AutoTest, UNINIT_VALUE,
				T.Equal, client_targeted.__BothTest, 4,

				T.Equal, server_targeted.__ClientTest, UNINIT_VALUE,
				T.Equal, server_targeted.__ServerTest, 2,
				T.Equal, server_targeted.__AutoTest, 3,
				T.Equal, server_targeted.__BothTest, 4,

				T.Equal, both_targeted.__ClientTest, UNINIT_VALUE,
				T.Equal, both_targeted.__ServerTest, 2,
				T.Equal, both_targeted.__AutoTest, 3,
				T.Equal, both_targeted.__BothTest, 4
			)
		end

		local a, b, c = client_targeted.test(), server_targeted.test(), both_targeted.test()
		T:WhileSituation( "which convert when FINISH-ed",
			T.Equal, a, 1,
			T.Equal, b, 1,
			T.Equal, c, 1
		)
	end)
end


return mod
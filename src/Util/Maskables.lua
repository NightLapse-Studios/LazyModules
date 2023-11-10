local mod = { }

local Enums = require(game.ReplicatedFirst.Util.Enums)
local Meta = require(game.ReplicatedFirst.Util.Meta)
local META_CONTEXTS = Enums.META_CONTEXTS

local no_op_func = function() end

local MaskableStack = { }
local Configurator = Meta.CONFIGURATOR({ __index = MaskableStack })
	:SETTER(META_CONTEXTS.BOTH, "OnTopValueChanged", "__OnTopValueChanged")
	:FINISH()

function MaskableStack:set(thing: any)
	table.insert(self.stack, thing)
	self.__OnTopValueChanged(self.stack[#self.stack])
end

function MaskableStack:remove(thing: any)
	local idx = table.find(self.stack, thing)

	if not idx then
		warn("MaskableStack::remove: object not found")
		return
	end

	local was_top = idx == #self.stack
	table.remove(self.stack, idx)

	if was_top then
		self.__OnTopValueChanged(self.stack[#self.stack])
	end
end

function MaskableStack:forceUpdate()
	self.__OnTopValueChanged(self.stack[#self.stack])
end

function mod.Stack()
	local t = {
		stack = { },
		__OnTopValueChanged = no_op_func
	}

	setmetatable(t, Configurator)

	return t
end

function mod:__tests(G, T)
	local top_according_to_callback = nil

	local stack = mod.Stack()
		:OnTopValueChanged(function(top) top_according_to_callback = top end)
		:FINISH()

	T:Test("Implement a stack", function()
		local new_thing = { }
		stack:set(new_thing)

		T:WhileSituation("Basically",
			T.Equal, top_according_to_callback, new_thing
		)

		local thing_2 = { }
		stack:set(thing_2)

		T:WhileSituation("Basically",
			T.Equal, top_according_to_callback, thing_2
		)

		stack:remove(thing_2)

		T:WhileSituation("Basically",
			T.Equal, top_according_to_callback, new_thing
		)

		stack:remove(new_thing)

		T:WhileSituation("Basically",
			T.Equal, top_according_to_callback, nil
		)
	end)
end

return mod
local mod = { }

local Enums = require(game.ReplicatedFirst.Lib.Enums)
local Meta = require(game.ReplicatedFirst.Lib.Meta)

local no_op_func = function() end

local MaskableStack = { }
local Configurator = Meta.CONFIGURATOR({ __index = MaskableStack })
	:SETTER(Enums.MetaContexts.BOTH, "OnTopValueChanged", "__OnTopValueChanged")
	:FINISH()

function MaskableStack:__getTopValue()
	local highestPriority = 0
	local topThing = nil
	
	for i = #self.stack, 1, -1 do
		local thing = self.stack[i]
		local priority = self.priorities[thing]
		
		if priority > highestPriority then
			topThing = thing
			highestPriority = priority
		end
	end
	
	return topThing
end

function MaskableStack:set(thing: any, priority: number)
	priority = priority or 1
	
	self.priorities[thing] = priority
	
	table.insert(self.stack, thing)
	
	local newTopValue = self:__getTopValue()
	
	if newTopValue ~= self.topValue then
		self.topValue = newTopValue
		self.__OnTopValueChanged(self.topValue)
	end
end

function MaskableStack:remove(thing: any)
	local idx = table.find(self.stack, thing)

	if not idx then
		warn("MaskableStack::remove: object not found")
		return
	end

	local was_top = self.topValue == thing
	table.remove(self.stack, idx)

	self.priorities[thing] = nil
	
	if was_top then
		self.topValue = self:__getTopValue()
		self.__OnTopValueChanged(self.topValue)
	end
end

function MaskableStack:forceUpdate()
	self.__OnTopValueChanged(self.topValue)
end

function mod.Stack()
	local t = {
		topValue = nil,
		stack = { },
		priorities = { },
		
		__OnTopValueChanged = no_op_func
	}

	setmetatable(t, Configurator)

	return t
end

function mod.__tests(G, T)
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
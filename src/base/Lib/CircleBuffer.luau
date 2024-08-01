
--[[
	This implementation is meant to be specifically useful for pushing elements on each frame so that reading from the front
	can be used to read a certain amount into the past
]]--

local module = { }
local CircleBuffer = { }
CircleBuffer.__index = CircleBuffer

export type CircleBuffer<T> = {
	[number]: T,
	NextWrite: number,
	Length: number,
	Written: number,
	
	toidx: (self: CircleBuffer<T>, pos: number) -> number,
	clear: (self: CircleBuffer<T>) -> (),
	push: (self: CircleBuffer<T>, val: T) -> (),
	writeFromFront: (self: CircleBuffer<T>, pos: number, val: T) -> (),
	getElementFromFront: (self: CircleBuffer<T>, pos: number) -> T,
	appendFromFront: (self: CircleBuffer<T>, val: T, key: any) -> (),
	writeAtSequence: (self: CircleBuffer<T>, seq: number, val: T) -> number,
	getSize: (self: CircleBuffer<T>) -> number,
	__rawRead: (self: CircleBuffer<T>, pos: number) -> T?,
	readFromFront: (self: CircleBuffer<T>, val: T) -> number,
}

function module.new<T>(length: number, opt_mock: T)
	local buf = setmetatable(table.create(length + 3), CircleBuffer)

	buf.NextWrite = 1
	buf.Length = length
	buf.Written = 0

	if opt_mock then
		return (buf :: any) :: CircleBuffer<T>
	else
		return (buf :: any) :: CircleBuffer<unknown>
	end
end

local function incriment(self, num)
	--self.End = self.End + 1
	num = (num + 1) % (self.Length)
	if num == 0 then
		num = self.Length
	end

	return num
end

function CircleBuffer:toidx(num)
	num = (self.NextWrite + num - 1) % self.Length

	if num <= 0 then
		num += self.Length
	end

	return num
end

function CircleBuffer:clear()
	self.Written = 0
	self.NextWrite = 1
	for i = 1, #self, 1 do
		self[i] = nil
	end
end

function CircleBuffer:push(val)
	self[self.NextWrite] = val
	self.NextWrite = incriment(self, self.NextWrite)
	self.Written += 1
end

function CircleBuffer:writeFromFront(pos, val)
	self[self:toidx(pos)] = val
end

function CircleBuffer:getElementFromFront(pos)
	return self[self:toidx(pos)]
end

--Don't use this if your buffer isn't filled with tables
function CircleBuffer:appendFromFront(pos, val, key)
	local element = self[self:toidx(pos)]
	element[key or #element + 1] = val
end

function CircleBuffer:writeAtSequence(seq, val)
	if seq > self.Written or seq < self.Written - (self.Length - 1) then
		return false
	end

	local newPos = seq % self.Length
	if newPos == 0 then
		newPos = self.Length
	end
	self[newPos] = val

	return true
end

function CircleBuffer:getSize()
	return math.min(self.Written, self.Length)
end

function CircleBuffer:__rawRead(idx: number)
	return self[idx]
end

--N-1 elements behind the newest one
function CircleBuffer:readFromFront(n)
	local ret = self[self:toidx(n)]
	return ret
end

function module.__tests(G, T)
	local a,s,d,f,g = 1,2,3,4,5
	local cbuf = module.new(5)

	T:Test( "Handle typical modifications", function()
		cbuf:push(a)
		cbuf:push(s)
		cbuf:push(d)

		T:WhileSituation( "pushing",
			T.Equal, cbuf:__rawRead(1), a,
			T.Equal, cbuf:__rawRead(2), s,
			T.Equal, cbuf:__rawRead(3), d,
			T.Equal, cbuf:__rawRead(4), nil,
			T.Equal, cbuf:__rawRead(5), nil
		)

		T:ForContext( "over-reading before wrap-around",
			T.Equal, cbuf:readFromFront(0), d,
			T.Equal, cbuf:readFromFront(-1), s,
			T.Equal, cbuf:readFromFront(-2), a,
			T.Equal, cbuf:readFromFront(-3), nil,
			T.Equal, cbuf:readFromFront(-4), nil
		)

		cbuf:writeFromFront(2, g)
		--push should be unaffected by the previous call
		cbuf:push(a)

		T:WhileSituation( "writing from the front",
			T.Equal, cbuf:__rawRead(1), a,
			T.Equal, cbuf:__rawRead(2), s,
			T.Equal, cbuf:__rawRead(3), d,
			T.Equal, cbuf:__rawRead(4), a,
			T.Equal, cbuf:__rawRead(5), g
		)

		cbuf:push(s)
		cbuf:push(d)
		cbuf:push(f)
		cbuf:push(g)

		T:WhileSituation( "pushing causes wrap-around",
			T.Equal, cbuf:__rawRead(1), d,
			T.Equal, cbuf:__rawRead(2), f,
			T.Equal, cbuf:__rawRead(3), g,
			T.Equal, cbuf:__rawRead(4), a,
			T.Equal, cbuf:__rawRead(5), s
		)

		cbuf:writeFromFront(1, d)

		T:WhileSituation( "write-from-front after wrap-around",
			T.Equal, cbuf:__rawRead(1), d,
			T.Equal, cbuf:__rawRead(2), f,
			T.Equal, cbuf:__rawRead(3), g,
			T.Equal, cbuf:__rawRead(4), d,
			T.Equal, cbuf:__rawRead(5), s
		)

		cbuf:writeFromFront(4, d)
		cbuf:writeFromFront(5, d)

		T:WhileSituation( "write-from-front causes wrap-around",
			T.Equal, cbuf:__rawRead(1), d,
			T.Equal, cbuf:__rawRead(2), d,
			T.Equal, cbuf:__rawRead(3), d,
			T.Equal, cbuf:__rawRead(4), d,
			T.Equal, cbuf:__rawRead(5), s
		)

		cbuf:clear()

		T:WhileSituation( "clearing",
			T.Equal, cbuf:__rawRead(1), nil,
			T.Equal, cbuf:__rawRead(2), nil,
			T.Equal, cbuf:__rawRead(3), nil,
			T.Equal, cbuf:__rawRead(4), nil,
			T.Equal, cbuf:__rawRead(5), nil
		)
	end)

	--To not rely on the previous tests
	cbuf:clear()

	T:Test("Understand its size", function()
		T:WhileSituation( "empty",
			T.Equal, cbuf:getSize(), 0
		)

		cbuf:push(a)

		T:WhileSituation( "pushing",
			T.Equal, cbuf:getSize(), 1
		)

		cbuf:writeFromFront(1, a)

		T:WhileSituation( "writing-from-front",
			T.Equal, cbuf:getSize(), 1
		)

		cbuf:push(s)
		cbuf:push(d)
		cbuf:push(f)
		cbuf:push(g)
		cbuf:push(f)
		cbuf:push(d)

		T:WhileSituation( "overflowing",
			T.Equal, cbuf:getSize(), 5
		)
	end)

	cbuf:clear()

	T:Test("Read", function()
		cbuf:push(a)
		cbuf:push(s)
		cbuf:push(d)
		cbuf:push(f)
		cbuf:push(g)

		T:WhileSituation( "from-front",
			T.Equal, cbuf:readFromFront(1), a,
			T.Equal, cbuf:readFromFront(2), s,
			T.Equal, cbuf:readFromFront(3), d,
			T.Equal, cbuf:readFromFront(4), f,
			T.Equal, cbuf:readFromFront(5), g
		)
		
		cbuf:push(a)
		cbuf:push(s)
		cbuf:push(d)
		cbuf:push(f)

		T:WhileSituation( "from-front, after overflow",
			T.Equal, cbuf:readFromFront(1), g,
			T.Equal, cbuf:readFromFront(2), a,
			T.Equal, cbuf:readFromFront(3), s,
			T.Equal, cbuf:readFromFront(4), d,
			T.Equal, cbuf:readFromFront(5), f
		)
	end)
end

return module
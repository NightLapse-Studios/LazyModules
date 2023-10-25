local mod = { }

local List = { }
List.__index = List

function List:Itterate(fn)
	for _x, x_row in self.Contents do
		for _y, y_row in x_row do
			for _z, cell in y_row do
				fn(cell)
			end
		end
	end
end

function List:Init(fn)
	for x = 1, self.Size.X do
		self.Contents[x] = { }
		for y = 1, self.Size.Y do
			self.Contents[x][y] = { }
			for z = 1, self.Size.Z do
				self.Contents[x][y][z] = fn(x, y, z)
			end
		end
	end
end


function mod.new(dims: Vector3, init_fn)
	local l = {
		Size = dims,
		Contents = { }
	}

	setmetatable(l, List)

	return l
end

function mod:__init(G)
end

return mod
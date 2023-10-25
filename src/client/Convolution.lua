
local dir_vecs = {
	None = Vector3.new(),
	Left = Vector3.new(-1, 0, 0),
	Right = Vector3.new(1, 0, 0),
	Up = Vector3.new(0, 1, 0),
	Down = Vector3.new(0, -1, 0),
	Forward = Vector3.new(0, 0, 1),
	Backward = Vector3.new(0, 0, -1)
}

dir_vecs.LF = dir_vecs.Left + dir_vecs.Forward
dir_vecs.RF = dir_vecs.Right + dir_vecs.Forward
dir_vecs.LB = dir_vecs.Left + dir_vecs.Backward
dir_vecs.RB = dir_vecs.Right + dir_vecs.Backward
dir_vecs.LU = dir_vecs.Left + dir_vecs.Up
dir_vecs.RU = dir_vecs.Right + dir_vecs.Up
dir_vecs.FU = dir_vecs.Forward + dir_vecs.Up
dir_vecs.BU = dir_vecs.Backward + dir_vecs.Up
dir_vecs.LD = dir_vecs.Left + dir_vecs.Down
dir_vecs.RD = dir_vecs.Right + dir_vecs.Down
dir_vecs.FD = dir_vecs.Forward + dir_vecs.Down
dir_vecs.BD = dir_vecs.Backward + dir_vecs.Down
dir_vecs.LFU = dir_vecs.Left + dir_vecs.Forward + dir_vecs.Up
dir_vecs.RFU = dir_vecs.Right + dir_vecs.Forward + dir_vecs.Up
dir_vecs.LBU = dir_vecs.Left + dir_vecs.Backward + dir_vecs.Up
dir_vecs.RBU = dir_vecs.Right + dir_vecs.Backward + dir_vecs.Up
dir_vecs.LFD = dir_vecs.Left + dir_vecs.Forward + dir_vecs.Down
dir_vecs.RFD = dir_vecs.Right + dir_vecs.Forward + dir_vecs.Down
dir_vecs.LBD = dir_vecs.Left + dir_vecs.Backward + dir_vecs.Down
dir_vecs.RBD = dir_vecs.Right + dir_vecs.Backward + dir_vecs.Down


local mod = { }

local DList
local Cell

local Grids = { }

local Grid = { }
Grid.__index = Grid

function Grid:Run()
	table.insert(Grids, self)
	return self
end

function Grid:Stop()
	local i = table.find(Grids, self)
	if not i then return self end
	
	table.remove(i)

	return self
end

function Grid:PositionParts()
	self.DList:Itterate(function(cell)
		local pos = self.Origin
		pos += self.CellSize * cell.Position
		cell.Part.Position = pos
		cell.Part.Parent = workspace
	end)
end

function mod.new(pos: Vector3, size: Vector2, cell_size: Vector3)
	local t = {
		Origin = pos,
		CellSize = cell_size,
		DList = DList.new(size, cell_size),
		Weights = { },
	}

	for i: string, v: Vector3 in dir_vecs do
		t.Weights[v] = 1 / 26
	end

	t.Weights[dir_vecs.Left] = 1/10
	t.Weights[dir_vecs.Right] = -1/10

	t.DList:Init(function(x, y, z)
		local cell = Cell.new(Vector3.new(x, y, z), cell_size)
		cell.Part.Transparency = cell.Current
		
		return cell
	end)

	setmetatable(t, Grid)

	return t
end

local CanProcess = true
function mod:__init(G)
	DList = G.Load("DList")
	Cell = G.Load("Cell")
	G.Load("UserInput"):Handler(Enum.KeyCode.F, function()
		CanProcess = true
	end)
end

local function update_grids(dt)
	if CanProcess then
		CanProcess = false
	else
		return
	end

	for i,v in Grids do
		local Cells = v.DList.Contents
		v.DList:Itterate(function(cell)
			cell.Previous = cell.Current
		end)

		v.DList:Itterate(function(cell)
			local next_value = 0
			local pos = cell.Position

			for i,v in v.Weights do
				local neighbor_pos = pos + i
				local success, neighbor = pcall(function() return Cells[neighbor_pos.X][neighbor_pos.Y][neighbor_pos.Z] end)
				if not success or not neighbor then continue end

				next_value += v * neighbor.Previous
			end

			cell.Current = math.clamp(next_value, 0, 1)
			cell.Part.Transparency = 1 - cell.Current
		end)
	end
end

function mod:__build_signals(G, B)
	game:GetService("RunService").PreRender:Connect(update_grids)
end

return mod
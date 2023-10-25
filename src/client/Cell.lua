local mod = { }

local Cell = { }
Cell.__index = Cell


local VisPart = Instance.new("Part")
VisPart.Anchored = true
VisPart.Transparency = 0
VisPart.Size = Vector3.new(1, 1, 1)
VisPart.Material = Enum.Material.Plastic
VisPart.CastShadow = false
VisPart.CanCollide = false

function mod.new(pos: Vector3, size: Vector3)
	local part = VisPart:Clone()
	part.Size = size
	part.Color = Color3.new(math.random(), math.random(), math.random())

	local c = {
		Current = math.random(),
		Previous = 0,
		Position = pos,
		Part = part
	}

	setmetatable(c, Cell)

	return c
end

function mod:__init(G)

end

return mod
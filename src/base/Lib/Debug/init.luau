--!strict

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local debugFolder = Instance.new("Folder", workspace)
debugFolder.Name = RunService:IsClient() and "ClientDebug" or "ServerDebug"

local mod = { }

local spots = {}
local spotID = 0

function mod.MarkSpot(pos: Vector3, color: Color3, size: Vector3, extra_data: string?, singular_name: string?, __t: number?)
	local p = Instance.new("Part")
	p.Color = color or Color3.new(1,1,1)
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = 0
	
	p.Size = size or Vector3.new(1,10,1)
	
	if typeof(pos) == "CFrame" then
		p.CFrame = pos
	elseif pos then
		p.Position = pos
	end
	
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	
	p.Parent = debugFolder
	
	spotID += 1
	singular_name = singular_name or spotID
	
	if spots[singular_name] then
		spots[singular_name]:Destroy()
	end
	
	spots[singular_name] = p
	
	if extra_data then
		mod.DebugHighlight(p, color, extra_data, __t)
	end
	
	return p
end

function mod.TempMarkSpot(pos, t, size, color, extra_data, singular_name)
	local p = mod.MarkSpot(pos, color, size, extra_data, singular_name, t)

	Debris:AddItem(p, t)

	return p
end

function mod.DebugCFAxis(cf, wait, dist)
	-- RightVector (+X), UpVector (+Y), LookVector (-Z)
	
	local x, y, z = Vector3.new(dist, 0, 0), Vector3.new(0, dist, 0), Vector3.new(0, 0, -dist)
	x = mod.TempMarkSpot(cf * CFrame.new(x), wait, Color3.new(1, 0, 0), Vector3.new(0.5, 0.5, 0.5))
	y = mod.TempMarkSpot(cf * CFrame.new(y), wait, Color3.new(0, 1, 0), Vector3.new(0.5, 0.5, 0.5))
	z = mod.TempMarkSpot(cf * CFrame.new(z), wait, Color3.new(0, 0, 1), Vector3.new(0.5, 0.5, 0.5))
end

function mod.DebugModelAxis(model: Model|BasePart, wait, dist)
	local cf = model:GetPivot()
	mod.DebugCFAxis(cf, wait, dist)
end

function mod.DebugGlobalAxis(model: Model|BasePart, wait, dist)
	local cf = model:GetPivot()

	-- Erase the angles
	cf = CFrame.new(cf.Position)

	mod.DebugCFAxis(cf, wait, dist)
end

function mod.VisualizeLine(pos1, pos2, color, thickness, extra_data, singular_name)	
	local vector = pos1 - pos2
	local length = vector.Magnitude
	local midPoint = (pos1 + pos2) * 0.5
	local cf = CFrame.lookAt(midPoint, midPoint + vector)
	local size = Vector3.new(thickness, thickness, length)
	
	return mod.MarkSpot(cf, color, size, extra_data, singular_name)
end

function mod.VisualizePlane(p1, p2, p3, opt_p)
	-- Constructs a plane from 3 points and optionaly visualizes opt_p distance to the plane
	
	local v1 = p2 - p1
    local v2 = p3 - p1
    local normal = v1:Cross(v2).Unit
    
	local folder = Instance.new("Folder")
	
	local function part()
		local p = Instance.new("Part")
		p.Material = Enum.Material.Neon
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		
		p.Parent = folder
		return p
	end
	
	local p = part()
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Color = Color3.new(1,0,0)
	p.Position = p1
	
	p = part()
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Color = Color3.new(1,0.2,0)
	p.Position = p2
	
	p = part()
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Color = Color3.new(1,0.4,0)
	p.Position = p3
	
	p = part()
	p.Size = Vector3.new(2048, 2048, 0.01)
	p.Color = Color3.new(0, 0,1)
	p.Transparency = 0.8
	p.CFrame = CFrame.new(p1, p1 + normal)
	
	if opt_p then
		local v = opt_p - p1
		local dot = v:Dot(normal)
		local dist = math.abs(dot)
		
		p = part()
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.Color = Color3.new(0,1,0)
		p.Position = opt_p
		
		local nearest = opt_p - normal * dot
		
		p = part()
		p.Size = Vector3.new(0.1, 0.1, (nearest - opt_p).Magnitude)
		p.Color = Color3.new(0,1,0)
		p.Transparency = 0.8
		p.CFrame = CFrame.new((nearest + opt_p) / 2, opt_p)
	end
	
	folder.Parent = debugFolder
    return folder
end

function mod.DebugHighlight(model: Model|BasePart, color, extra_data, t)
	color = color or Color3.new(1,1,1)
	
	local hl = model:FindFirstChild("DebugHighlight") or Instance.new("Highlight", model)
	
	hl.Adornee = model
	hl.OutlineColor = color
	hl.FillColor = color
	hl.OutlineTransparency = 0.5
	hl.FillTransparency = 0.6
	hl.Name = "DebugHighlight"
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	
	if t then
		Debris:AddItem(hl, t)
	end
	
	if extra_data then
		mod.DebugLabel(model, color, extra_data, t)
	end
	
	return hl
end

function mod.DebugLabel(model: Model|BasePart, color, extra_data, t)
	local ref = model:FindFirstChild("DebugLabel") or Instance.new("ObjectValue", model)
	
	local parent = RunService:IsServer() and model or Players.LocalPlayer.PlayerGui
	
	local bgui: BillboardGui = ref.Value or Instance.new("BillboardGui", parent)
	ref.Value = bgui
	
	bgui.Adornee = model
	bgui.Name = "DebugLabel"
	bgui.AlwaysOnTop = true
	bgui.SizeOffset = Vector2.new(0, 1)
	bgui.ExtentsOffsetWorldSpace = Vector3.new(0, 1, 0)
	bgui.Size = UDim2.new(0, 200, 0, 100)
	bgui.ResetOnSpawn = false
	
	bgui:ClearAllChildren()

	local uIPadding = Instance.new("UIPadding")
	uIPadding.PaddingBottom = UDim.new(0, 4)
	uIPadding.PaddingLeft = UDim.new(0, 4)
	uIPadding.PaddingRight = UDim.new(0, 4)
	uIPadding.PaddingTop = UDim.new(0, 4)
	uIPadding.Parent = bgui

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
	frame.BorderSizePixel = 0
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.Size = UDim2.new(1, -4, 1, -4)

	local uIStroke = Instance.new("UIStroke")
	uIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	uIStroke.Color = color or Color3.fromRGB(255, 225, 0)
	uIStroke.LineJoinMode = Enum.LineJoinMode.Miter
	uIStroke.Thickness = 2
	uIStroke.Parent = frame

	local scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.XY
	scrollingFrame.BottomImage = ""
	scrollingFrame.TopImage = ""
	scrollingFrame.CanvasSize = UDim2.new()
	scrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 0, 0)
	scrollingFrame.ScrollBarThickness = 3
	scrollingFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	scrollingFrame.BackgroundTransparency = 1
	scrollingFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	scrollingFrame.Size = UDim2.new(1, 0, 1, 0)

	local textLabel = Instance.new("TextLabel")
	textLabel.Font = Enum.Font.RobotoMono
	textLabel.RichText = true
	textLabel.Text = tostring(extra_data)
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextSize = 13
	textLabel.TextWrapped = true
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.AutomaticSize = Enum.AutomaticSize.Y
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.new(1, -4, 0, 0)
	textLabel.Parent = scrollingFrame

	scrollingFrame.Parent = frame

	local uIPadding1 = Instance.new("UIPadding")
	uIPadding1.PaddingBottom = UDim.new(0, 5)
	uIPadding1.PaddingLeft = UDim.new(0, 5)
	uIPadding1.PaddingRight = UDim.new(0, 5)
	uIPadding1.PaddingTop = UDim.new(0, 5)
	uIPadding1.Parent = frame

	frame.Parent = bgui
	
	if t then
		Debris:AddItem(bgui, t)
	end
	
	if RunService:IsClient() then
		ref.Destroying:Once(function()
			if bgui.Parent then
				bgui:Destroy()
			end
		end)
	end
	
	return bgui
end

local function cycle(self, dur, funcs)
	local len = #funcs
	local i = 0
	while true do
		i = (i % len) + 1

		local f = funcs[i]
		self.cur_func = f
		
		print("Cycled to " .. tostring(i))
		task.wait(dur)
	end
end


local Meta = require(game.ReplicatedFirst.Lib.Meta)
local Cycler = Meta.FUNCTIONAL_METATABLE()
	:METHOD("Get", function(self, ...)
		return self.cur_func(...)
	end)
	:FINISH()

function mod.FunctionCycler(dur: number, ...)
	local cycler = {
		cur_func = false
	}
	setmetatable(cycler, Cycler)

	local co = coroutine.create(cycle)
	local funcs = { ... }

	-- The coroutine will yield after initializing cur_func for the cycler
	coroutine.resume(co, cycler, dur, funcs)

	return cycler
end

-- Make listed functions available for export
local APIUtils = require(game.ReplicatedFirst.Lib.APIUtils)
local Exports = APIUtils.ExportList({
	MarkSpot = mod.MarkSpot,
	TempMarkSpot = mod.TempMarkSpot,
	DebugCFAxis = mod.DebugCFAxis,
	DebugModelAxis = mod.DebugModelAxis,
	DebugGlobalAxis = mod.DebugGlobalAxis,
	VisualizeLine = mod.VisualizeLine,
	VisualizePlane = mod.VisualizePlane,
	DebugHighlight = mod.DebugHighlight,
	DebugLabel = mod.DebugLabel,
	FunctionCycler = mod.FunctionCycler,
})
mod = Exports:ExposeTo(mod)

return mod
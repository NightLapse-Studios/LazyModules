local CollectionService = game:GetService("CollectionService")
local mod = { }

local safe_require = require(game.ReplicatedFirst.Util.SafeRequire).require
for i,v in script:GetChildren() do
	mod[v.Name] = safe_require(v)
end

mod.LogBuf = mod.DebugBuf.Log

function mod.MarkSpotDbg(pos)
	local p = Instance.new("Part")
	p.Color = Color3.new(1,1,1)
	p.Material = Enum.Material.Neon
	p.Size = Vector3.new(1,10,1)
	p.Position = pos
	p.Name = "DDDDDDD"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Parent = workspace

	return p
end
local function __TempMarkSpotDbg(pos, wait, size, color, part)
	task.wait(wait)
	part:Destroy()
end
function mod.TempMarkSpotDbg(pos, wait, color, size, opt_part)
	color = color or Color3.new(1, 0, 0)

	local p = opt_part or Instance.new("Part")
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Name = "DDDDDDD"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Parent = workspace

	if size then
		p.Size = size
	end

	if typeof(pos) == "CFrame" then
		p.CFrame = pos
	elseif pos then
		p.Position = pos
	end

	coroutine.resume(coroutine.create(__TempMarkSpotDbg), pos, wait, size, color, p)

	return p
end

function mod.DebugModelAxis(model: Model|BasePart, wait, dist)
	local cf: CFrame
	if model:IsA("Model") then
		cf = model.PrimaryPart:GetPivot()
	elseif model:IsA("BasePart") then
		cf = model.CFrame
	end

	local x, y, z = Vector3.new(dist, 0, 0), Vector3.new(0, dist, 0), Vector3.new(0, 0, dist)
	x = mod.TempMarkSpotDbg(cf * CFrame.new(x), wait, Color3.new(1, 0, 0), Vector3.new(0.5, 0.5, 0.5))
	y = mod.TempMarkSpotDbg(cf * CFrame.new(y), wait, Color3.new(0, 1, 0), Vector3.new(0.5, 0.5, 0.5))
	z = mod.TempMarkSpotDbg(cf * CFrame.new(z), wait, Color3.new(0, 0, 1), Vector3.new(0.5, 0.5, 0.5))

	mod.DebugHighlight(x, Color3.new(1, 0, 0))
	mod.DebugHighlight(y, Color3.new(0, 1, 0))
	mod.DebugHighlight(z, Color3.new(0, 0, 1))
end

function mod.DebugGlobalAxis(model: Model, wait, dist)
	local cf: CFrame
	if model:IsA("Model") then
		cf = model.PrimaryPart:GetPivot()
	elseif model:IsA("BasePart") then
		cf = model.CFrame
	end

	-- Erase the angles
	cf = CFrame.new(cf.Position)

	local x, y, z = Vector3.new(dist, 0, 0), Vector3.new(0, dist, 0), Vector3.new(0, 0, dist)
	mod.TempMarkSpotDbg(cf * CFrame.new(x), wait, Color3.new(1, 0, 0), Vector3.new(0.5, 0.5, 0.5))
	mod.TempMarkSpotDbg(cf * CFrame.new(y), wait, Color3.new(0, 1, 0), Vector3.new(0.5, 0.5, 0.5))
	mod.TempMarkSpotDbg(cf * CFrame.new(z), wait, Color3.new(0, 0, 1), Vector3.new(0.5, 0.5, 0.5))
end

local ArrowModel = game.ReplicatedStorage.RectangularArrow
function mod.VisualizeCFrame(cf: CFrame, dur, opt_mag, opt_color, opt_planar_size: Vector2?)
	opt_color = opt_color or Color3.new(0.560784, 0.066666, 0.066666)
	opt_planar_size = opt_planar_size or Vector2.new(1, 1)
	local mag = opt_mag or ArrowModel.PrimaryPart.Size.Z
	local size = Vector3.new(opt_planar_size.X, opt_planar_size.Y, mag)

	local origin = cf.Position
	local dest = origin + (cf.LookVector * mag)
	local vis_spot = (origin + dest) / 2

	local m = ArrowModel:Clone()
	m.Parent = workspace
	m:PivotTo(CFrame.new(vis_spot, dest))
	m.PrimaryPart.Size = size
	mod.TempMarkSpotDbg(nil, dur, opt_color, nil, m.PrimaryPart)
	return m
end

function mod.VisualizePlane(p1, p2, p3, opt_p)
	local v1 = p2 - p1
    local v2 = p3 - p1
    local normal = v1:Cross(v2).Unit
    
	local folder = Instance.new("Folder")
	
	local function part()
		local p = Instance.new("Part")
		p.Material = Enum.Material.Neon
		p.Anchored = true
		p.CanCollide = false
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
	
	CollectionService:AddTag(folder, "Invisibles")
	folder.Parent = workspace
    return folder
end

function mod.DebugHighlight(model, color, t, occlude)
	color = color or Color3.new(1, 0, 0)
	local hl = Instance.new("Highlight", model)

	hl.Adornee = model
	hl.OutlineColor = color
	hl.FillColor = color
	hl.OutlineTransparency = 0.5
	if occlude then
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
	else
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	end
	
	if t then
		game:GetService("Debris"):AddItem(hl, t)
	end
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


local Meta = require(game.ReplicatedFirst.Util.Meta)
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


-- Quick and dirty way to send a message to our discord bot
local DebugDiscordMsgRemote

local Secrets
function mod.DebugDiscordMsg(msg: string)
	assert(msg)

	if _G.Game.CONTEXT == "CLIENT" then
		DebugDiscordMsgRemote:FireServer(msg)
	elseif _G.Game.CONTEXT == "SERVER" then
		Secrets.SendDiscordMsg(msg)
	end
end

if game:GetService("RunService"):IsServer() then
	-- TODO: again, secrets thing
	-- Secrets = require(game.ServerScriptService.Secrets)
	DebugDiscordMsgRemote = Instance.new("RemoteEvent", game.ReplicatedStorage)
	DebugDiscordMsgRemote.Name = "DebugDiscordMsgRemote"
	DebugDiscordMsgRemote.OnServerEvent:Connect(function(plr, msg) mod.DebugDiscordMsg(msg) end)
elseif game:GetService("RunService"):IsClient() then
	DebugDiscordMsgRemote = game.ReplicatedStorage:WaitForChild("DebugDiscordMsgRemote")
end

-- Make listed functions available for export
local APIUtils = require(game.ReplicatedFirst.Util.APIUtils)
APIUtils.EXPORT_LIST(mod)
	:ADD("MarkSpotDbg")
	:ADD("TempMarkSpotDbg")
	:ADD("DebugModelAxis")
	:ADD("DebugGlobalAxis")
	:ADD("VisualizeCFrame")
	:ADD("DebugHighlight")
	:ADD("FunctionCycler")
	:ADD("DebugDiscordMsg")
	:ADD("VisualizePlane")

return mod
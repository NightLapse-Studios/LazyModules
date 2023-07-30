--[[
	Visualizer.lua

	Author: Gavin Oppegard
	Date: 6/23/2022

	Visualizes forces.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local THICKNESS = 0.2

local debugFolder = Instance.new("Folder", workspace)
debugFolder.Name = "debugFolder"

local Mouse

local visualizing = {}

local faceEnums = Enum.NormalId:GetEnumItems()

local ScreenGui = Instance.new("ScreenGui")

local frame = Instance.new("Frame")
frame.BackgroundTransparency = 1
frame.Size = UDim2.new(0,450,0,350)
frame.Position = UDim2.new(0,0,1,0)
frame.AnchorPoint = Vector2.new(0,1)
frame.Parent = ScreenGui

local Visualizer = {}


function Visualizer:SetColor(name, color)
	local arrow = visualizing[name]
	if arrow then
		arrow.Color = color
		for i,v in pairs(arrow:GetChildren()) do
			v.Frame.BackgroundColor3 = color
		end
	end
end

function Visualizer:SetTransparency(name, transparency)
	local arrow = visualizing[name]
	if arrow then
		for i,v in pairs(arrow:GetChildren()) do
			v.Frame.BackgroundTransparency = transparency
		end
	end
end

function Visualizer:ShowForce(position, force, name, color)
	local arrow = visualizing[name]
	if not arrow then
		arrow = Instance.new("Part")
		arrow.Anchored = true
		arrow.Transparency = 1
		arrow.CanCollide = false
		arrow.Material = Enum.Material.SmoothPlastic
		arrow.CanQuery = false
		arrow.Name = name

		for i = 1, 6 do
			local sgui = Instance.new("SurfaceGui")
			sgui.AlwaysOnTop = true
			sgui.Face = faceEnums[i]

			local frame = Instance.new("Frame")
			frame.BorderSizePixel = 0
			frame.Size = UDim2.new(1, 0, 1, 0)
			frame.BackgroundColor3 = color
			frame.BackgroundTransparency = 0.5

			frame.Parent = sgui

			sgui.Parent = arrow
		end

		visualizing[name] = arrow
	end

	local mag = force.Magnitude
	if mag > 2048 then
		force = force.Unit * 2048
	end

	Visualizer:SetColor(name, color)
	arrow.CFrame = CFrame.new(position, position + force) * CFrame.new(0, 0, -math.abs(force.Magnitude / 2))
	arrow.Size = Vector3.new(THICKNESS, THICKNESS, force.Magnitude)

	arrow.Parent = debugFolder
end

function Visualizer:deleteForce(name)
	if visualizing[name] then
		visualizing[name]:Destroy()
		visualizing[name] = nil
	end
end


local Frame = Instance.new("TextLabel")
Frame.BackgroundTransparency = 1
Frame.Text = ""
Frame.TextSize = 14
Frame.TextColor3 = Color3.new(1,1,1)
Frame.Size = UDim2.new(0, 100, 0, 50)
Frame.Visible = false

function Visualizer:__init(G)
	if G.CONTEXT == "SERVER" then return end

	local gui = Instance.new("ScreenGui", Players.LocalPlayer.PlayerGui)
	Frame.Parent = gui

	local lastHit = nil
	RunService.RenderStepped:Connect(function(deltaTime)
		
		local ray = workspace.CurrentCamera:ScreenPointToRay(Mouse.X, Mouse.Y)
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {debugFolder}
		params.FilterType = Enum.RaycastFilterType.Whitelist
		local rr = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
		if rr then
			Frame.Position = UDim2.new(0, Mouse.X, 0, Mouse.Y + 20)
			Frame.Text = rr.Instance.Name
			Frame.TextColor3 = rr.Instance.Color
			Frame.Visible = true
	
			Visualizer:SetTransparency(rr.Instance.Name, 0)
			if lastHit and lastHit ~= rr.Instance then
				Visualizer:SetTransparency(lastHit.Name, 0.5)
			end
			lastHit = rr.Instance
		else
			Frame.Visible = false
	
			if lastHit then
				Visualizer:SetTransparency(lastHit.Name, 0.5)
			end
			lastHit = nil
		end
	
	
	end)

	Mouse = Players.LocalPlayer:GetMouse()
	ScreenGui.Parent = Players.LocalPlayer.PlayerGui
end


return Visualizer
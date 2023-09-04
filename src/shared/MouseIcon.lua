--!strict
--[[
	Short example usage:

	local ref = MouseIcons.SetIcon( "rbxassetid://6043765917" )
	-- < some time passes >
	MouseIcons.UnSetIcon( ref )
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

if RunService:IsServer() then
	return { }
end

local Assets = require(ReplicatedFirst.Modules.Assets)
local Enums = _G.Game.Enums

--UserInputService.MouseIconEnabled = false
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local PlayerGUI = LocalPlayer.PlayerGui

local MouseIcons = {
	Queue = { },
	Adornees = { }
}

local lastRef = nil

local MouseFrame = Instance.new("ImageLabel", ReplicatedFirst.Mouse)
MouseFrame.Parent.Parent = PlayerGUI

local color = Color3.new(1,1,1)

function MouseIcons.SetColor(c)
	color = c
end




local function adornee_frame()
	local frame = Instance.new("ImageLabel", MouseFrame)
	frame.Size = UDim2.new(0,5,0,5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.BackgroundTransparency = 1.0
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Active = false
	frame.Selectable = false
	frame.Image = ""
	
	return frame
end

local function resetToBaseMouseFrame()
	MouseFrame.Size = UDim2.new(0,5,0,5)
	MouseFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	MouseFrame.BackgroundTransparency = 1.0
	MouseFrame.BackgroundColor3 = color
	MouseFrame.BorderSizePixel = 0
	MouseFrame.Active = false
	MouseFrame.Selectable = false
	MouseFrame.Image = ""
	MouseFrame:ClearAllChildren()
end

function MouseIcons.FlashHitMarker()
	local frame = adornee_frame()
	frame.Size = UDim2.new(0,23,0,23)
	frame.Image = Assets.Images.HitMarker
	
	task.delay(0.1, function()
		frame:Destroy()
	end)
end

function MouseIcons.GetMouse()
	return MouseFrame
end

function MouseIcons.ToggleMouseVisiblity(state)
	MouseFrame.Visible = state
end

function MouseIcons.ToggleUISMouse(state)
	UserInputService.MouseIconEnabled = state
end


function MouseIcons.SetIcon( asset_str, isPriority: boolean?, rotation: number?, size: UDim2? )
	assert(asset_str)
	isPriority = isPriority or false
	rotation = rotation or 0
	size = size or UDim2.new(0,5,0,5)
	-- an example of isPriority is windows resize icons.
	
	--Hack to give a persistent reference to the object so that the correct index is removed by `UnSetIcon`
	--Simply removing the first or last occurance of the asset can cause incorrect queues
	--However this means that any usage of the queue will need to index the entry at [1]. Ew
	local reference = { asset_str, isPriority, rotation, size }
	table.insert(MouseIcons.Queue, reference)

	return reference
end

function MouseIcons.Adorne( asset_str, rotation: number?, size: UDim2? )
	assert(asset_str)
	rotation = (rotation or 0) % 360
	size = size or UDim2.new(0,5,0,5)
	
	local frame: ImageLabel = adornee_frame()
	frame.Image = asset_str
	
	local angle = math.rad(rotation + 180)
	local sin_x = math.sin(angle)
    local cos_x = math.cos(angle)

    frame.AnchorPoint = Vector2.new(0.5 * cos_x + 0.5, 0.5 * sin_x + 0.5)
	
	frame.Rotation = rotation
	frame.Size = size

	local reference = { frame, rotation, size }
	MouseIcons.Adornees[reference] = reference

	return reference
end

function MouseIcons.Unadorne(adornee: table)
	adornee[1]:Destroy()
	MouseIcons.Adornees[adornee] = nil
end

function MouseIcons.UnSetIcon( reference )
	if not reference then
		--We allow nil so that the caller has almost no responsibilities
		return
	end

	for i, _reference in pairs( MouseIcons.Queue ) do
		if _reference == reference then
			table.remove(MouseIcons.Queue, i)
		end
	end
end

resetToBaseMouseFrame()

local function update(_)
	local queue = MouseIcons.Queue
	local activeRef = queue[#queue]
	
	-- itterate throught the queue to see if there are any priorities.
	-- this should not be done in reverse because setting an icon with priority should not overwrite the current priority
	for i = 1, #queue do
		local ref = queue[i]
		if ref[2] then
			activeRef = ref
			break
		end
	end
	
	local active_icon = activeRef[1]
	local rotation = activeRef[3]
	local size = activeRef[4]
	
	if activeRef and activeRef ~= lastRef then
		resetToBaseMouseFrame()
		lastRef = activeRef
		if type(active_icon) == "string" then
			MouseFrame.Image = active_icon
		elseif active_icon == Enums.MouseIconTypes.Projectile then
			MouseFrame.BackgroundTransparency = 0
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = MouseFrame
			local border = Instance.new("UIStroke")
			border.Thickness = 1
			border.Parent = MouseFrame
		end

		MouseFrame.Rotation = rotation
		MouseFrame.Size = size
	end

	MouseFrame.BackgroundColor3 = color
	MouseFrame.Position = UDim2.new(0, Mouse.X, 0, Mouse.Y)
end
RunService.RenderStepped:Connect(update)

local BaseIcon = MouseIcons.SetIcon("")

function MouseIcons.SetBaseIcon(asset)
	BaseIcon[1] = asset
end
local Globals
function MouseIcons:__init(G)
	Globals = G
end

return MouseIcons
--[[ 
    Readme: Flight script written by cryphowns
    Script gets copied into the client that executes :fly

]]
--[ Services ]
local Players = game:GetService("Players")
local InputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

--[ Directories ]
--[ Imports ]
--[ Constants ]
local FLIGHT_SPEED = 55

--[ Variables ]
local Player = Players.LocalPlayer
local Character = script.Parent
local Camera = workspace.CurrentCamera
local RenderId = Player.Name..script.Name
local BodyVelocity = Instance.new("BodyVelocity")
local BodyGyro = Instance.new("BodyGyro")
local cf = CFrame.new
local vec3 = Vector3.new

--[ Functions ]
local function setHumanoid(condition)
    local Humanoid = Character.Humanoid
    Humanoid.AutoRotate = condition
    Humanoid.PlatformStand = not condition
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, condition)
end

local function getStrafeVelocity()
    if InputService:IsKeyDown(Enum.KeyCode.D) then
        return Camera.CFrame.RightVector
    elseif InputService:IsKeyDown(Enum.KeyCode.A) then
        return -Camera.CFrame.RightVector
    else     
        return vec3()
    end
end

local function getLinearVelocity()
    if InputService:IsKeyDown(Enum.KeyCode.W) then
        return Camera.CFrame.LookVector
    elseif InputService:IsKeyDown(Enum.KeyCode.S) then
        return -Camera.CFrame.LookVector
    else
        return vec3()
    end
end

local function update(dt)
    local HumanoidRootPart = Character.HumanoidRootPart

    if BodyVelocity.Parent ~= HumanoidRootPart then
        BodyVelocity.Parent = HumanoidRootPart
    end

    if BodyGyro.Parent ~= HumanoidRootPart then
        BodyGyro.Parent = HumanoidRootPart
    end

    local calculatedVelocity = ((getLinearVelocity()*FLIGHT_SPEED) + getStrafeVelocity()*(FLIGHT_SPEED/2))
    
    setHumanoid(false)
    BodyGyro.CFrame = cf(HumanoidRootPart.Position, HumanoidRootPart.Position + Camera.CFrame.LookVector)
    BodyGyro.MaxTorque = vec3(1,1,1)*math.huge
    BodyGyro.P = 5000
    BodyVelocity.Velocity = calculatedVelocity
end

local function clean()
    RunService:UnbindFromRenderStep(RenderId)
    BodyVelocity:Destroy()
    BodyGyro:Destroy()
    setHumanoid(true)
end

local function init()
    RunService:BindToRenderStep(RenderId, Enum.RenderPriority.Character.Value, update)
end
--[ Listeners ]
script.Destroying:Connect(function()
    clean()
end)

--[ Calls ]
init()


local Controllers

local ACCELERATION = 80

local MAX_FORW_VELOCITY = 18
local MAX_HORZ_VELOCITY = 27

local Y_CANCEL = Vector3.new(1, 0, 1)

local ProjectileController = {}
ProjectileController.__index = ProjectileController

function ProjectileController:__init(G)
	Controllers = G.Load("Controllers")
	Config = G.Load("BUILDCONFIG")

	setmetatable(ProjectileController, Controllers.ControllerObject)

	Controllers.register("Projectile")
		:Create(function(self)
			self.VelocityAdjust = Vector3.zero
			self.LastVelocityAdjust = Vector3.zero

			setmetatable(self, ProjectileController)
		end)
		:SetMovementUpdate(function(self, direction, dt)
			local cameraAdjustedUnit
			if direction.Magnitude > 0 then
				local cam_look = workspace.CurrentCamera.CFrame.LookVector
				local cam_ang = math.atan2(-cam_look.X, -cam_look.Z)
				local originalUnit = Vector3.new(direction.X, 0, direction.Z).Unit
				cameraAdjustedUnit = (CFrame.lookAt(Vector3.zero, originalUnit, Vector3.yAxis) * CFrame.Angles(0, cam_ang, 0)).LookVector
			else
				cameraAdjustedUnit = Vector3.zero
			end

			local targetVelocityAdjust = self.VelocityAdjust + cameraAdjustedUnit * dt * ACCELERATION

			local forwVector = self.Model.Origin.LookVector * Y_CANCEL
			local horzVector = forwVector:Cross(Vector3.yAxis)

			local forwVelocity = targetVelocityAdjust:Dot(forwVector)
			forwVelocity = math.clamp(forwVelocity, -MAX_FORW_VELOCITY, MAX_FORW_VELOCITY)

			local horzVelocity = targetVelocityAdjust:Dot(horzVector)
			horzVelocity = math.clamp(horzVelocity, -MAX_HORZ_VELOCITY, MAX_HORZ_VELOCITY)

			self.VelocityAdjust = forwVector * forwVelocity + horzVector * horzVelocity
		end)
end

function ProjectileController:VelocityUpdate(dt)
	local proj = self.Model

	proj.Velocity += Config.Gravity * dt
	proj.Velocity += self.VelocityAdjust
	proj.Velocity -= self.LastVelocityAdjust

	self.LastVelocityAdjust = self.VelocityAdjust
end

return ProjectileController
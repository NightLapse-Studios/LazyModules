local Cooldowns = {}

local RunService = game:GetService("RunService")

local Tables = require(game.ReplicatedFirst.Util.Tables)

-- if you start a cooldown and dont check if its finished after it is, we need to clean that up ourselves.
local WIPE_INTERVAL = 1

local cooldowns = {}

local function getCooldownIdx(n1, n2, n3)
	local c1 = cooldowns[n1]
	if c1 then
		if n2 then
			local c2 = c1[n2]
			if c2 then
				if n3 then
					return c2[n3]
				else
					return c2
				end
			end
			return nil
		else
			return c1
		end
	else
		return nil
	end
end

local function setCooldownIdx(n1, n2, n3, v)
	if n3 then
		cooldowns[n1] = cooldowns[n1] or {}
		cooldowns[n1][n2] = cooldowns[n1][n2] or {}
		cooldowns[n1][n2][n3] = v
	elseif n2 then
		cooldowns[n1] = cooldowns[n1] or {}
		cooldowns[n1][n2] = v
	else
		cooldowns[n1] = v
	end
end

function Cooldowns.CancelCooldown(n1, n2, n3)
	if n3 then
		if cooldowns[n1] then
			if cooldowns[n1][n2] then
				cooldowns[n1][n2][n3] = nil
			end
		end
	elseif n2 then
		if cooldowns[n1] then
			cooldowns[n1][n2] = nil
		end
	else
		cooldowns[n1] = nil
	end
end

function Cooldowns.IsPastCooldown(n1, n2, n3)
	local start = getCooldownIdx(n1, n2, n3)
	if start then
		local pass = tick() > start
		if pass then
			Cooldowns.CancelCooldown(n1, n2, n3)
		end
		return pass
	end
	return true
end

function Cooldowns.GetCooldownTimeLeft(n1, n2, n3)
	local start = getCooldownIdx(n1, n2, n3)
	if start then
		return start - tick()
	end
	return nil
end

function Cooldowns.StartCooldown(t, n1, n2, n3)
	if t and t > 0 then
		setCooldownIdx(n1, n2, n3, tick() + t)
	end
end

function Cooldowns.__run()
	local lastScan = tick()

	RunService.Stepped:Connect(function()
		if tick() - lastScan > WIPE_INTERVAL then
			lastScan = tick()

			for n1, c1 in pairs(cooldowns) do
				if type(c1) == "table" then
					for n2, c2 in pairs(c1) do
						if type(c2) == "table" then
							for n3, v in pairs(c2) do
								Cooldowns.IsPastCooldown(n1, n2, n3)
							end

							if Tables.IsTableEmpty(c2) then
								c1[n2] = nil
							end
						else
							Cooldowns.IsPastCooldown(n1, n2)
						end
					end

					if Tables.IsTableEmpty(c1) then
						cooldowns[n1] = nil
					end
				else
					Cooldowns.IsPastCooldown(n1)
				end
			end
		end
	end)
end

return Cooldowns
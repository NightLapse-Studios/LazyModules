--!strict
--[[
]]
local mod = {
}

local mt = { __index = mod }

--local INIT_CONTEXT = if game:GetService("RunService"):IsServer()  then "SERVER" else "CLIENT"

local Globals
local unwrap_or_warn
local unwrap_or_error
local safe_require

function mod.new()
	local obj = {
		Events = table.create(16),
	}

	setmetatable(obj, mt)

	return obj
end

function mod:__init(G)
	Globals = G

	--The one true require tree
	safe_require = require(script.Parent.SafeRequire)
	safe_require:__init(G)
	safe_require = safe_require.require

	local err = require(script.Parent.Error)
	unwrap_or_warn = err.unwrap_or_warn
	unwrap_or_error = err.unwrap_or_error
end

return mod
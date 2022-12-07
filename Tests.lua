--!strict
--[[
	Search for `__tests(G, T)` for an example
]]
local mod = {
	Nouns = { },
}

local Globals
local PSA
local Err
local unwrap_or_warn
local unwrap_or_error
local safe_require

local ReplicatedFirst = game:GetService("ReplicatedFirst")

local mt_PreTest
local mt_DuringTest

local TestName, Situation, HasFailures
local Outputs = { }

local function NewTest(self, name, test_func)
	TestName = name

	--switch to testing behavior
	setmetatable(mod, mt_DuringTest)

	test_func(mod)
	if HasFailures then
		print("\t❌" .. TestName)
		for i, v in Outputs do
			print(Outputs[i])
		end
	else
		print("\t✅" .. TestName)
	end

	--revert state
	setmetatable(mod, mt_PreTest)

	table.clear(Outputs)
	Situation = ""
	HasFailures = false
end

local function NewSituation(self, description: string?, ...)
	Situation = description or ""
	local conditions = { ... }

	assert(#conditions % 2 == 0,
		"Conditions must be a value, expectation pair. All values must have a corresponding expectation, even if `nil`"
	)

	local num_conditions = #conditions / 2

	local failures, failed = "", 0
	local fail_reasons = ""

	for i = 1, #conditions, 2 do
		local actual, expected = conditions[i], conditions[i + 1]

		if actual ~= expected then
			local sep = if failed == 0 then "" else ", "			

			local cond = tostring((i + 1) / 2)
			failures = failures .. sep .. cond
			fail_reasons = fail_reasons .. "\n\t\t\tCond. " .. cond .. " expects " .. tostring(expected) .. " got " .. tostring(actual)

			HasFailures = true
			failed += 1
		end
	end

	if failed > 0 then
		table.insert(Outputs,  "\t\t✖ While " .. Situation)
		table.insert(Outputs, "\t\t\tDue to " .. failed .. " of " .. num_conditions .. " condition(s): " .. failures .. fail_reasons)
	else
		table.insert(Outputs,  "\t\t✔ While " .. Situation)
	end
end


mt_PreTest = { __call = NewTest }
mt_DuringTest = { __call = NewSituation }

setmetatable(mod, mt_PreTest)

function mod:Builder( module_name: string )
	assert(module_name)
	assert(typeof(module_name) == "string")

	mod.CurrentModule = module_name
	print("📃  " .. module_name .. " should:")

	return mod
end

function mod:__init(G)
	Globals = G

	--The one true require tree
	safe_require = require(ReplicatedFirst.Util.SafeRequire)
	safe_require:__init(G)
	safe_require = safe_require.require

	Err = require(ReplicatedFirst.Util.Error)
	unwrap_or_warn = Err.unwrap_or_warn
	unwrap_or_error = Err.unwrap_or_error
end

-- TODO: Many safety checks require some meta-communication with the server. eeeeghhh
function mod:__finalize(G)

end

return mod
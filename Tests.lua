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


local Tester = { }
local mt_Tester = { __index = Tester }


function mod:Builder( module_name: string )
	assert(module_name)
	assert(typeof(module_name) == "string")

	local t = {
		CurrentTestName = false,
		ModuleName = module_name,
		TestOutputs = { }
	}

	return setmetatable(t, mt_Tester)
end

function Tester:Finished()
	print("📃 " .. self.ModuleName .. " should:")

	for test_name, outputs in self.TestOutputs do
		if outputs.HasFailures then
			print("\t❌" .. test_name)
		else
			print("\t✅" .. test_name)
		end

		for i, output in outputs do
			if typeof(output) ~= "string" then
				continue
			end

			print(output)
		end
	end
end

function Tester:__try_new_output_buf(name)
	if self.TestOutputs[name] then
		error("Reused test name: " .. name .. "in " .. self.ModuleName)
	end

	-- This will be filled with strings stating success/fail conditions of tests
	local output_buf = {
		HasFailures = false
	}
	self.TestOutputs[name] = output_buf

	return output_buf
end

function Tester:Test(name, test_func)
	self:__try_new_output_buf(name)
	self.CurrentTestName = name

	-- test_func uses the `self` object to pass the results of tests into `self`s internal state
	test_func(self)
	self.CurrentTestName = false
end

function Tester:Situation(description: string, ...)
	local conditions = { ... }
	local output_buf = self.TestOutputs[self.CurrentTestName]

	if not output_buf then
		error("Tester::Situation must be called from within the body of a test function")
	end

	assert(#conditions % 2 == 0,
		"Conditions must be a value, expectation pair. All values must have a corresponding expectation, even if `nil`"
	)

	local num_conditions = #conditions / 2

	local failures, failed = "", 0
	local fail_reasons = ""

	for i = 1, #conditions, 2 do
		local actual, expected = conditions[i], conditions[i + 1]

		if actual ~= expected then
			local separator = if failed == 0 then "" else ", "			

			local cond = tostring((i + 1) / 2)
			failures = failures .. separator .. cond
			fail_reasons = fail_reasons .. "\n\t\t\tCond. " .. cond .. " expects " .. tostring(expected) .. " got " .. tostring(actual)

			failed += 1
		end
	end

	if failed > 0 then
		output_buf.HasFailures = true
		table.insert(output_buf,  "\t\t✖ While " .. description)
		table.insert(output_buf, "\t\t\tDue to " .. failed .. " of " .. num_conditions .. " condition(s): " .. failures .. fail_reasons)
	else
		table.insert(output_buf,  "\t\t✔ While " .. description)
	end
end

-- This function will insert its output into the "Expect errors" test name, regardless of when it is used in the __tests function
function Tester:ExpectError(description: string, f, ...)
	assert(typeof(description) == "string")
	assert(typeof(f) == "function")

	local success, ret = pcall(f, ...)
	local output_buf = self:__try_new_output_buf("Expect errors")

	if success then
		output_buf.HasFailures = true
		table.insert(output_buf,  "\t\t✖ While " .. description)
	else
		table.insert(output_buf,  "\t\t✔ While " .. description)
	end
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
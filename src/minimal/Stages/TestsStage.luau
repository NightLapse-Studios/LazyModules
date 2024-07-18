--!strict
local Config = require(game.ReplicatedFirst.Config)

local STAGE_NAME = "__tests"
local STAGE_PRIORITY = 10000

local mod = {
	Nouns = {},
}

local USAGE_EXAMPLE = [[
	function mod.__tests(G, T)
		T:Test("Do this thing", function()
			local val = mod.ReturnsTrue()
			T:WhileSituation("the world is on fire",
				T.Equal, val, true,
				T.NotEqual, val, false
			)
		end)
	end
]]

local FUZZY_EQ_EXAMPLE = [[
	T:WhileSituation("the world is on fire",
		-- Note we call FuzzyEqual
		-- whereas other tests can simply reference their test func
		T.FuzzyEqual(0.1), 0.9, 1, 		-- Valid, OK
		T.FuzzyEqual(0.1), 0.8999, 1, 	-- Valid, Fail
		T.FuzzyEqual, 0.9, 1, 			-- Invalid, Err
		T.Equal, 0.9, 1					-- Valid, Fail
	)
]]

local CUSTOM_TEST_FUNC_EXAMPLE = [[
	local function custom_test_func(a1, a2)
		return typeof(a1) == typeof(a2)
	end
	T:WhileSituation("the world is on fire",
		custom_test_func, 0.9, 1, 		-- Valid, OK
		custom_test_func, "0.9", 1, 	-- Valid, Fail
		custom_test_func, "0.9", "1", 	-- Valid, OK
	)
]]

local Tester = {}
local mt_Tester = { __index = Tester }

local function NewTester(module_name: string)
	assert(typeof(module_name) == "string")

	local t = {
		CurrentTestName = false,
		ModuleName = module_name,
		TestOutputs = {},
	}

	return setmetatable(t, mt_Tester)
end

local function Finished(self: Tester, callback_scope_error: string?)
	if Config.FocusTestOn and Config.FocusTestOn ~= self.ModuleName then
		return
	end

	local print_successes = Config.LogSuccessfulSubTests

	if callback_scope_error then
		print("📃 " .. self.ModuleName .. " FAILED!")
		print("\t❌ Callback-scope error (tests skipped):")
		print("\t" .. callback_scope_error)
		return
	else
		print("📃 " .. self.ModuleName .. ":")
	end

	for test_name, outputs in self.TestOutputs do
		if outputs.HasFailures then
			print("\t❌ " .. test_name)
		else
			print("\t✅ " .. test_name)

			if not print_successes then
				continue
			end
		end

		for i, output in outputs do
			if typeof(output) ~= "string" then
				continue
			end

			print(output)
		end
	end
end

local function run_module_stage(game, fn, mod_name: string)
	task.spawn(function()
		local tester = NewTester(mod_name)
		local success, err = pcall(fn, game, tester)
		if not success then
			Finished(tester, err)
		else
			Finished(tester)
		end
	end)
end

local function should_run_stage()
	return Config.TESTING == true
end

function mod.GiveLM(lm)
	lm.RegisterModuleStage(STAGE_NAME, STAGE_PRIORITY, run_module_stage, nil, should_run_stage)
end

export type Tester = typeof(mod.Tester(""))

local function try_new_output_buf(self: Tester, name: string)
	if self.TestOutputs[name] then
		error("Reused test name: " .. name .. "in " .. self.ModuleName)
	end

	-- This will be filled with strings stating success/fail conditions of tests
	local output_buf = {
		HasFailures = false,
	}
	self.TestOutputs[name] = output_buf

	return output_buf
end

function Tester:Test(name, test_func)
	local output_buf = try_new_output_buf(self, name)
	self.CurrentTestName = name

	-- test_func uses the `self` object to pass the results of tests into `self`s internal state
	local success, err = pcall(test_func, self)
	if not success then
		output_buf.HasFailures = true
		table.insert(output_buf, "\t\t❌ " .. name .. " has unexpected error:\n" .. err)
	end

	self.CurrentTestName = false
end

function Tester:Fuzz(name, count, generator, test_runner)
	local output_buf = try_new_output_buf(self, name)
	self.CurrentTestName = name

	local cycle_start_time = os.clock()
	print("📃 " .. self.ModuleName .. ": Running fuzz test " .. name)
	for i = 1, count, 1 do
		local success, ret = pcall(generator)
		if not success then
			output_buf.HasFailures = true
			table.insert(
				output_buf,
				"\t\t❌ Unexpected error in generator\n\t\ton iteration " .. tostring(i) .. "\n" .. ret
			)
			self.CurrentTestName = false
			return
		end

		local success, err = pcall(test_runner, ret)
		if not success then
			output_buf.HasFailures = true
			print("\t\t❌ " .. err .. "\n\t\tWith input:", ret)
		end

		if os.clock() - cycle_start_time > 1 then
			print(tostring(i) .. " out of " .. tostring(count) .. " iterations")
			task.wait()
			cycle_start_time = os.clock()
		end
	end
end

local ARGS_PER_CONDITION = 3
local function check_conditions(conditions, output_buf, description: string, predicate: string?)
	local num_conditions = math.ceil(#conditions / ARGS_PER_CONDITION)

	if predicate then
		description = predicate .. description
	end

	local failures, failed = "", 0
	local fail_reasons = ""

	for i = 1, #conditions, ARGS_PER_CONDITION do
		local test, actual, expected = conditions[i], conditions[i + 1], conditions[i + 2]
		assert(typeof(test) == "function", "Format for test args is <test func>, <computed value>, <expected value>")

		local is_ok = test(actual, expected)

		if is_ok == false then
			local separator = if failed == 0 then "" else ", "

			local cond = tostring((i + ARGS_PER_CONDITION - 1) / ARGS_PER_CONDITION)
			failures = failures .. separator .. cond
			fail_reasons = fail_reasons
				.. "\n\t\t\tCond. "
				.. cond
				.. " expects "
				.. tostring(expected)
				.. " got "
				.. tostring(actual)

			failed += 1
		end
	end

	if failed > 0 then
		output_buf.HasFailures = true
		table.insert(output_buf, "\t\t❌ " .. description)
		table.insert(
			output_buf,
			"\t\t\tDue to " .. failed .. " of " .. num_conditions .. " condition(s): " .. failures .. fail_reasons
		)
	else
		table.insert(output_buf, "\t\t✅ " .. description)
	end
end

local function check_situation_call(conditions, output_buf)
	if not output_buf then
		error("Tester situations must be called from within the body of a test function:\n" .. USAGE_EXAMPLE)
	end

	-- Can't do this check because lua sucks (trailing nil won't be an argument)
	--[[ 	assert(#conditions % ARGS_PER_CONDITION == 0,
		"Conditions must be a value, expectation pair. All values must have a corresponding expectation, even if `nil`"
	) ]]
end

function Tester:WhileSituation(description: string, ...)
	local conditions = { ... }
	local output_buf = self.TestOutputs[self.CurrentTestName]

	check_situation_call(conditions, output_buf)
	check_conditions(conditions, output_buf, description, "While ")
end

function Tester:UnlessSituation(description: string, ...)
	local conditions = { ... }
	local output_buf = self.TestOutputs[self.CurrentTestName]

	check_situation_call(conditions, output_buf)
	check_conditions(conditions, output_buf, description, "Unless ")
end

-- This function will insert its output into the "Expect errors" test name, regardless of when it is used in the __tests function
function Tester:ExpectError(description: string, f, ...)
	assert(typeof(description) == "string")
	assert(typeof(f) == "function")

	local success, ret = pcall(f, ...)
	local output_buf = try_new_output_buf(self, "Expect errors")

	if success then
		output_buf.HasFailures = true
		table.insert(output_buf, "\t\t❌ While " .. description)
	else
		table.insert(output_buf, "\t\t✅ While " .. description)
	end
end

function Tester:ForContext(description: string, ...)
	local conditions = { ... }
	local output_buf = self.TestOutputs[self.CurrentTestName]

	check_situation_call(conditions, output_buf)
	check_conditions(conditions, output_buf, description)
end

-- Declare default test funcs
do
	function Tester.Equal(a1: any, a2: any)
		return a1 == a2
	end

	function Tester.NotEqual(a1: any, a2: any)
		return a1 ~= a2
	end

	function Tester.LessThan(a1: number, a2: number)
		return a1 < a2
	end

	function Tester.GreaterThan(a1: number, a2: number)
		return a1 > a2
	end

	function Tester.FuzzyEqual(r, should_be_nil: any?)
		if should_be_nil ~= nil then
			error("FuzzyEqual should be used like so:" .. FUZZY_EQ_EXAMPLE)
		end

		return function(a1: number, a2: number)
			local o = a2 * r
			local low, high = a2 - o, a2 + o
			return a1 < high and a1 >= low
		end
	end
end

return mod

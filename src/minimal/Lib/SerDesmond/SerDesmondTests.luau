local NORMAL_TESTS = true

local mod = {}

local SerDesmond = require(script.Parent)

local function dump_bits(buf: buffer)
	local t = ""

	local len = buffer.len(buf)
	for i = 0, len - 1, 1 do
		local byte = buffer.readu8(buf, i)
		for j = 0, 7, 1 do
			local b = bit32.extract(byte, j, 1)
			t ..= tostring(b)
		end

		if i < len - 1 then
			t ..= " "
		end
	end

	return t
end

local LMT = require(game.ReplicatedFirst.Lib.LMTypes)
function mod.__tests(G: LMT.LMGame, T: LMT.Tester)
	if NORMAL_TESTS == true then
		local array_str = [[
			array(i8, i8)
		]]
		local periodic_array_str = [[
			periodic_array(i8, i8)
		]]
		local map_str = [[
			map(string: i8)
		]]
		local struct_str = [[
			struct(
				"a": i8,
				"b": f64,
				"c": i8,
				1: array(i8, f32)
			)
		]]
		local comments_in_weird_spots_str = [[
			struct(
				#test
				"a": #yep
				i8,
				#test 2
				# This is still illegal:
				# "b" #yep
				# : i16
			),
			vector3(
				#test
				i8
				#test
				,
				u8,
				i16
			)
		]]
		local enum_str = [[
			enum("asd", "asdf", "asdfg")
		]]
		local array_contains_host_nodes_str = [[
			array(
				struct("asdf": i8),
				vector3(i8, i8, i8),
				string,
				array(i8, i8),
				periodic_array(i8),
				enum("one", "two", "three"),
				map(i8: string)
			)
		]]
		local cframe_test_string = [[
			cframe(i8, u32, i8)
		]]

		local attribute_test_string = [[
			struct(
				"Thing1": i8,
				@optional
				"Thing2": i8,
				"Thing3": i8
			)
		]]

		local _, struct_with_optionals = pcall(function()
			return SerDesmond.PrettyCompile(attribute_test_string, true)
		end)

		T:Test("Optional attribute", function()
			T:ForContext("Compile",
				T.Equal, typeof(struct_with_optionals.Serialize), "function",
				T.Equal, typeof(struct_with_optionals.Deserialize), "function"
			)
			local t = struct_with_optionals.Deserialize(struct_with_optionals.Serialize({
					Thing1 = 99,
					Thing3 = 2
			}))

			T:ForContext("SerDes",
				T.Equal, typeof(t), "table",
				T.Equal, t.Thing1, 99,
				T.Equal, t.Thing2, nil,
				T.Equal, t.Thing3, 2
			)
		end)

		local _, struct = pcall(function()
			return SerDesmond.PrettyCompile(struct_str)
		end)
		local _, map = pcall(function()
			return SerDesmond.PrettyCompile(map_str)
		end)
		local _, array = pcall(function()
			return SerDesmond.PrettyCompile(array_str)
		end)
		local _, p_array = pcall(function()
			return SerDesmond.PrettyCompile(periodic_array_str)
		end)
		local _, enum = pcall(function()
			return SerDesmond.PrettyCompile(enum_str)
		end)
		local _, comments_in_weird_spots = pcall(function()
			return SerDesmond.PrettyCompile(comments_in_weird_spots_str, true)
		end)
		local _, array_contains_host_nodes = pcall(function()
			return SerDesmond.PrettyCompile(array_contains_host_nodes_str)
		end)
		local _, cframe_test = pcall(function()
			return SerDesmond.PrettyCompile(cframe_test_string)
		end)

		T:Test("Size specifier", function()
			local min_size, max_size = 1, 2 ^ 30 - 1
			local buf1 = buffer.create(4)
			local buf2 = buffer.create(4)
			SerDesmond.write_size_specifier(min_size, buf1, 0)
			SerDesmond.write_size_specifier(63, buf1, 1)
			SerDesmond.write_size_specifier(64, buf1, 2)
			SerDesmond.write_size_specifier(max_size, buf2, 0)

			-- stylua: ignore
			T:ForContext(
				"writing",
				--						  [s=1 v=1][s=1 v=63][   s=2 v=64    ]
				--						   ssvvvvvv ssvvvvvv ssvvvvvv vvvvvvvv
				T.Equal, dump_bits(buf1), "00100000 00111111 10000000 10000000",
				--						  [           s=3 v=2^30-1           ]
				--						   ssvvvvvv vvvvvvvv vvvvvvvv vvvvvvvv
				T.Equal, dump_bits(buf2), "11111111 11111111 11111111 11111111"
			)

			local full_buf = buffer.create(4)
			-- Fill with 1s
			SerDesmond.write_size_specifier(2 ^ 30 - 1, full_buf, 0)
			-- overwrite 2nd byte
			SerDesmond.write_size_specifier(1, full_buf, 1)

			T:ForContext("written size",
				T.Equal, dump_bits(full_buf), "11111111 00100000 11111111 11111111"
			)

			T:ForContext(
				"reading",
				T.Equal, SerDesmond.read_size_specifier(buf1, 0), 1,
				T.Equal, SerDesmond.read_size_specifier(buf1, 1), 63,
				T.Equal, SerDesmond.read_size_specifier(buf1, 2), 64,
				T.Equal, SerDesmond.read_size_specifier(buf2, 0), 2 ^ 30 - 1
			)
		end)
		T:Test("Compile junk", function()
			-- TODO: These will fail with the reported error
			T:ForContext(
				"comments in construct",
				T.Equal,
				typeof(comments_in_weird_spots.Serialize),
				"function",
				T.Equal,
				typeof(comments_in_weird_spots.Deserialize),
				"function"
			)
			T:ForContext(
				"all host nodes in array",
				T.Equal,
				typeof(array_contains_host_nodes.Serialize),
				"function",
				T.Equal,
				typeof(array_contains_host_nodes.Deserialize),
				"function"
			)
		end)

		T:Test("Enum", function()
			T:ForContext(
				"Compile",
				T.Equal,
				typeof(enum.Serialize),
				"function",
				T.Equal,
				typeof(enum.Deserialize),
				"function"
			)
			local t = enum.Deserialize(enum.Serialize({ "asd", "asd", "asdfg" }))
			T:ForContext("SerDes", T.Equal, t[1], "asd", T.Equal, t[2], "asd", T.Equal, t[3], "asdfg")
		end)
		T:Test("Array", function()
			T:ForContext(
				"Compile",
				T.Equal,
				typeof(array.Serialize),
				"function",
				T.Equal,
				typeof(array.Deserialize),
				"function"
			)
			local t = array.Deserialize(array.Serialize({ 1, 2 }))
			T:ForContext("SerDes", T.Equal, t[1], 1, T.Equal, t[2], 2)
			local stuff = array_contains_host_nodes.Deserialize(array_contains_host_nodes.Serialize({
				{ asdf = 1 },
				Vector3.new(2, 3, 4),
				"yooo",
				{ 5, 6 },
				{ 7, 8, 9 },
				{ "one", "two", "three" },
				{ [4] = "10", [5] = "11", [6] = "12" },
			}))
			T:ForContext(
				"Contains all host nodes: types",
				T.Equal,
				typeof(stuff[1]),
				"table",
				T.Equal,
				typeof(stuff[2]),
				"Vector3",
				T.Equal,
				typeof(stuff[3]),
				"string",
				T.Equal,
				typeof(stuff[4]),
				"table",
				T.Equal,
				typeof(stuff[5]),
				"table",
				T.Equal,
				typeof(stuff[6]),
				"table",
				T.Equal,
				typeof(stuff[7]),
				"table"
			)
			T:ForContext(
				"Contains all hose nodes: values",
				T.Equal,
				stuff[1].asdf,
				1,
				T.Equal,
				stuff[2].X,
				2,
				T.Equal,
				stuff[2].Y,
				3,
				T.Equal,
				stuff[2].Z,
				4,
				T.Equal,
				stuff[3],
				"yooo",
				T.Equal,
				stuff[4][1],
				5,
				T.Equal,
				stuff[4][2],
				6,
				T.Equal,
				stuff[5][1],
				7,
				T.Equal,
				stuff[5][2],
				8,
				T.Equal,
				stuff[5][3],
				9,
				T.Equal,
				stuff[6][1],
				"one",
				T.Equal,
				stuff[6][2],
				"two",
				T.Equal,
				stuff[6][3],
				"three",
				T.Equal,
				stuff[7][1],
				nil,
				T.Equal,
				stuff[7][2],
				nil,
				T.Equal,
				stuff[7][3],
				nil,
				T.Equal,
				stuff[7][4],
				"10",
				T.Equal,
				stuff[7][5],
				"11",
				T.Equal,
				stuff[7][6],
				"12"
			)
		end)
		T:Test("Periodic Array", function()
			T:ForContext(
				"Compile",
				T.Equal,
				typeof(p_array.Serialize),
				"function",
				T.Equal,
				typeof(p_array.Deserialize),
				"function"
			)
			local t = p_array.Deserialize(p_array.Serialize({ 2, 3, 4, 5 }))
			T:ForContext("SerDes", T.Equal, t[1], 2, T.Equal, t[2], 3, T.Equal, t[3], 4, T.Equal, t[4], 5)
		end)
		T:Test("Map", function()
			T:ForContext(
				"Compile",
				T.Equal,
				typeof(map.Serialize),
				"function",
				T.Equal,
				typeof(map.Deserialize),
				"function"
			)
			local t = map.Deserialize(map.Serialize({ one = 1, two = 2 }))
			T:ForContext("SerDes", T.Equal, t.one, 1, T.Equal, t.two, 2)
		end)
		T:Test("Struct", function()
			T:ForContext(
				"Compile",
				T.Equal,
				typeof(struct.Serialize),
				"function",
				T.Equal,
				typeof(struct.Deserialize),
				"function"
			)
			local t = struct.Deserialize(struct.Serialize({ a = 1, b = 2, c = 3, [1] = { 1, 3.14 } }))
			T:ForContext(
				"SerDes",
				T.Equal,
				t.a,
				1,
				T.Equal,
				t.b,
				2,
				T.Equal,
				t.c,
				3,
				T.Equal,
				typeof(t[1]),
				"table",
				T.Equal,
				t[1][1],
				1,
				T.Equal,
				t[1][2],
				3.140000104904175
			)
		end)
		T:Test("CFrame", function()
			T:ForContext("Compile",
				T.Equal, typeof(cframe_test.Serialize), "function",
				T.Equal, typeof(cframe_test.Deserialize), "function"
			)

			t = cframe_test.Deserialize(cframe_test.Serialize(CFrame.new(Vector3.new(), Vector3.new(1, 1, 1))))
			local look = t.LookVector
			T:ForContext("SerDes",
				T.FuzzyEqual(1/100), look.X, 0.5773,
				T.FuzzyEqual(1/100), look.Y, 0.5773,
				T.FuzzyEqual(1/100), look.Z, 0.5773
			)
		end)
		T:Test("Comments", function()
			local t, t2 =
				comments_in_weird_spots.Deserialize(comments_in_weird_spots.Serialize({ a = 1 }, Vector3.new(2, 3, 4)))
			T:ForContext("In weird places", T.Equal, t.a, 1, T.Equal, t2, Vector3.new(2, 3, 4))
		end)
	end
end

return mod

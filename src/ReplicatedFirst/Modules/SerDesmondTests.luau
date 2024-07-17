local FUZZ = true
local NORMAL_TESTS = true

local mod = {}

local SerDesmond = require(script.Parent.SerDesmond)

local function dump_bits(buf: buffer)
	local t = ""

	local len = buffer.len(buf)
	for i = 0, len - 1, 1 do
		local byte = buffer.readu8(buf, i)
		for j = 7, 0, -1 do
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
				"a": i8,
				#test 2
			),
			vector3(
				#test
				i8
				#test
				,
				i8,
				i8
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
			return SerDesmond.PrettyCompile(comments_in_weird_spots_str)
		end)
		local _, array_contains_host_nodes = pcall(function()
			return SerDesmond.PrettyCompile(array_contains_host_nodes_str)
		end)

		T:Test("Size specifier", function()
			local min_size, max_size = 1, 2 ^ 30 - 1
			local buf1 = buffer.create(4)
			local buf2 = buffer.create(4)
			local buf3 = buffer.create(4)
			SerDesmond.write_size_specifier(min_size, buf1, 0)
			SerDesmond.write_size_specifier(63, buf1, 1)
			SerDesmond.write_size_specifier(64, buf1, 2)
			SerDesmond.write_size_specifier(max_size, buf2, 0)

			-- stylua: ignore
			T:ForContext(
				"writing",
				--						  [s=1 v=1][s=1 v=63][   s=2 v=64    ]
				--						   ssvvvvvv ssvvvvvv ssvvvvvv vvvvvvvv
				T.Equal, dump_bits(buf1), "00000001 00111111 01000000 01000000",
				--						  [           s=3 v=2^30-1           ]
				--						   ssvvvvvv vvvvvvvv vvvvvvvv vvvvvvvv
				T.Equal, dump_bits(buf2), "11111111 11111111 11111111 11111111"
			)

			local full_buf = buffer.create(4)
			-- Fill with 1s
			SerDesmond.write_size_specifier(2 ^ 30 - 1, full_buf, 0)
			-- overwrite 2nd byte
			SerDesmond.write_size_specifier(1, full_buf, 1)

			T:ForContext("written size", T.Equal, dump_bits(full_buf), "11111111 00000001 11111111 11111111")

			T:ForContext(
				"reading",
				T.Equal,
				SerDesmond.read_size_specifier(buf1, 0),
				1,
				T.Equal,
				SerDesmond.read_size_specifier(buf1, 1),
				63,
				T.Equal,
				SerDesmond.read_size_specifier(buf1, 2),
				64,
				T.Equal,
				SerDesmond.read_size_specifier(buf2, 0),
				2 ^ 30 - 1
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
		T:Test("Comments", function()
			local t, t2 =
				comments_in_weird_spots.Deserialize(comments_in_weird_spots.Serialize({ a = 1 }, Vector3.new(2, 3, 4)))
			T:ForContext("In weird places", T.Equal, t.a, 1, T.Equal, t2, Vector3.new(2, 3, 4))
		end)
	end

	local is_separator = require(script.Parent.SerDesmond.is_separator)
	if G.CONTEXT == "SERVER" and FUZZ then
		T:Fuzz("Random string", 100_000, function()
			local s = ""
			for i = 1, math.random(10, 100), 1 do
				s ..= string.char(math.random(0, 255))
			end
			return s
		end, function(str: string)
			local s, d, _ = SerDesmond.Compile(str, false)
		end)

		--[[
			Parsing tests
		]]
		local Tokens = {
			"i8",
			"i16",
			"i32",
			"u8",
			"u16",
			"u32",
			"f8",
			"f16",
			"f32",
			"f64",
			"string",
			"enum",
			"array",
			"periodic_array",
			"map",
			"struct",
			"vector3",
			",",
			":",
			"(",
			")",
			",",
			":",
			"(",
			")",
		}

		T:Fuzz("Random tokens fuzz", 100_000, function()
			local out = ""
			for i = 1, 30, 1 do
				out ..= Tokens[math.random(1, #Tokens)] .. " "
			end

			return out
		end, function(str: string)
			local s, d, _ = SerDesmond.Compile(str)
		end)

		--[[ 
			Functional serdes testing
			Semi complete
		]]

		local Generators, GeneratorsRandom

		local function RandomGenerator()
			return GeneratorsRandom[math.random(1, #GeneratorsRandom)]
		end

		local function RandomGeneratorExcept(strs: { string })
			local except = {}
			for i, v in strs do
				table.insert(except, Generators[v])
			end

			local generator
			repeat
				generator = RandomGenerator()
			until not table.find(except, generator)

			return generator
		end

		local max_depth = 3
		local binding_blacklist = { "binding" }
		local max_depth_blacklist = { "array", "binding", "map", "enum", "struct", "periodic_array" }
		local literals_blacklist = {
			"array",
			"binding",
			"map",
			"enum",
			"struct",
			"periodic_array",
			"i8",
			"i16",
			"i32",
			"u8",
			"u16",
			"u32",
			"string",
			"vector3",
		}

		-- Construct a SerDes string and an object that can be passed to it once compiled
		Generators = {
			array = function(depth)
				local children_ct = math.random(1, 3)
				local children_ex = {}

				local blacklist = if depth >= max_depth then max_depth_blacklist else binding_blacklist

				local out = "array("
				for i = 1, children_ct, 1 do
					local child_str, child_ex = RandomGeneratorExcept(blacklist)(depth + 1)
					table.insert(children_ex, child_ex)
					out ..= child_str
					if i ~= children_ct then
						out ..= ", "
					end
				end

				out ..= ")"
				return out, children_ex
			end,
			periodic_array = function(depth)
				local children_ct = math.random(1, 3)
				local children_ex = {}

				local blacklist = if depth >= max_depth then max_depth_blacklist else binding_blacklist

				local out = "periodic_array("
				for i = 1, children_ct, 1 do
					local child_str, child_ex = RandomGeneratorExcept(blacklist)(depth + 1)
					table.insert(children_ex, child_ex)
					out ..= child_str
					if i ~= children_ct then
						out ..= ", "
					end
				end

				out ..= ")"
				return out, children_ex
			end,
			map = function(depth)
				local binding, binding_ex = Generators.binding(depth + 1)

				local out = "map(" .. binding .. ")"

				return out, binding_ex
			end,
			binding = function(depth, only_use_lhs_literals)
				local blacklist = if depth >= max_depth then max_depth_blacklist else binding_blacklist
				local lhs_blacklist = if only_use_lhs_literals then literals_blacklist else blacklist
				local lhs, lhs_ex = RandomGeneratorExcept(lhs_blacklist)(depth + 1)
				local rhs, rhs_ex = RandomGeneratorExcept(blacklist)(depth + 1)
				local ex = {}
				ex[lhs_ex] = rhs_ex

				return lhs .. ": " .. rhs, ex
			end,
			enum = function(depth)
				local children_ct = math.random(3, 5)
				local children_ex = {}

				local out = "enum("
				for i = 1, children_ct, 1 do
					local child_str, child_ex = Generators.string_literal()
					table.insert(children_ex, child_ex)
					out ..= child_str
					if i ~= children_ct then
						out ..= ", "
					end
				end

				out ..= ")"
				return out, children_ex
			end,
			struct = function(depth)
				local children_ct = math.random(3, 5)
				local children_ex = {}

				local out = "struct("
				for i = 1, children_ct, 1 do
					local binding, binding_ex = Generators.binding(depth + 1, true)
					if table.find(children_ex, binding_ex) then
						continue
					end

					for i, v in binding_ex do
						children_ex[i] = v
					end
					out ..= binding
					if i ~= children_ct then
						out ..= ", "
					end
				end

				out ..= ")"
				return out, children_ex
			end,
			i8 = function()
				return "i8", -1
			end,
			i16 = function()
				return "i16", -2
			end,
			i32 = function()
				return "i32", -3
			end,
			u8 = function()
				return "u8", 1
			end,
			u16 = function()
				return "u16", 2
			end,
			u32 = function()
				return "u32", 3
			end,
			vector3 = function()
				return "vector3(i8, i8, i8)", Vector3.new(9, 10, 11)
			end,
			string_literal = function()
				local ex = "str" .. tostring(math.random(1, 99))
				return '"' .. ex .. '"', ex
			end,
			string = function()
				return "string", "str" .. tostring(math.random(1, 99))
			end,
			number_literal = function()
				local ex = math.random(-99, 99)
				return tostring(ex), ex
			end,
		}

		GeneratorsRandom = {}
		for i, v in Generators do
			table.insert(GeneratorsRandom, v)
		end

		-- Dumps a table with simple values as a string with consistent ordering
		-- The output should be valid lua but may need to remove some trailing commas
		local function DumpValueRecursive(t)
			local b = ""
			if typeof(t) == "table" then
				b ..= "{"
				local entries = {}
				for i, v in t do
					local idx, value
					if typeof(i) == "string" then
						idx = '"' .. i .. '"'
					elseif typeof(i) == "table" then
						idx = DumpValueRecursive(i)
					else
						idx = tostring(i)
					end

					if typeof(v) == "table" then
						value = DumpValueRecursive(v)
					else
						value = tostring(v)
					end

					table.insert(entries, { Index = idx, Value = value })
				end

				table.sort(entries, function(a, b)
					local i = 0
					while true do
						i += 1
						local an = string.byte(a.Index, i, i) or 0
						local bn = string.byte(b.Index, i, i) or 0
						if an == bn and an ~= 0 then
							continue
						end

						return an < bn
					end
				end)

				for i, v in entries do
					b ..= "[" .. v.Index .. "]=" .. v.Value .. ","
				end
				b ..= "}"
			else
				b ..= tostring(t)
			end

			return b
		end

		-- print(DumpRecusriveTable({[{1, 2, 3}] = {{a = 99}, 4, 5}}))

		T:Fuzz("SerDes fuzz", 100_000, function()
			-- local str, ex = RandomGeneratorExcept({"binding"})(1)
			local str, ex = Generators.periodic_array(1)
			return { str, ex }
		end, function(p)
			local str, ex = p[1], p[2]
			local s, d, _ = SerDesmond.Compile(str)
			if not (s and d) then
				error("Compile failed")
			end

			local res = d(s(ex))
			local before = DumpValueRecursive(ex)
			local after = DumpValueRecursive(res)

			if before ~= after then
				error("SerDes not equivalent:\n" .. before .. "\n" .. after)
			end
		end)
	end
end

return mod

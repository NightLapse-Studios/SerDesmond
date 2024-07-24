local FUZZ_RANDOM_STRINGS = false
local FUZZ_RANDOM_TOKENS = false
local FUZZ_SERDES_FUNCTIONS = false

local SerDesmond = require(script.Parent.SerDesmond)

local mod = { }

function mod.__tests(G, T)
	if G.CONTEXT == "SERVER" then
		if FUZZ_RANDOM_STRINGS then
			T:Fuzz("Random string", 100_000, function()
				local s = ""
				for i = 1, math.random(10, 100), 1 do
					s ..= string.char(math.random(0, 255))
				end
				return s
			end, function(str: string)
				local s, d, _ = SerDesmond.Compile(str, false)
			end)
		end

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

		if FUZZ_RANDOM_TOKENS then
			T:Fuzz("Random tokens fuzz", 100_000, function()
				local out = ""
				for i = 1, 30, 1 do
					out ..= Tokens[math.random(1, #Tokens)] .. " "
				end

				return out
			end, function(str: string)
				local s, d, _ = SerDesmond.Compile(str)
			end)
		end

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
		local max_depth_blacklist = { "array", "binding", "map", "enum", "struct", "periodic_array", "cframe" }
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
			"cframe",
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
			-- CFrame can't be fuzzed because it outputs floats no matter what
--[[ 			cframe = function()
				local ex = CFrame.new(Vector3.new(math.random(1, 2^8-1), math.random(1, 2^8-1), math.random(1, 2^8-1)), Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5))
				return "cframe(u8,u8,u8)", ex
			end ]]
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

		if FUZZ_SERDES_FUNCTIONS then
			T:Fuzz("SerDes fuzz", 100_000, function()
				local str, ex = RandomGeneratorExcept({ "binding" })(1)
				-- local str, ex = Generators.periodic_array(1)
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
end

return mod
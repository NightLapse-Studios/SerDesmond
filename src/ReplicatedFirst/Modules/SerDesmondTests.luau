local mod = { }

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
    local array_str = [[
        array(i8, i8)
    ]]
    local periodic_array_str = [[
        periodic_array(i8, i8)
    ]]
	local nested_array_str = [[
		array(array(i8, i8), i8)
	]]
	local map_str = [[
		map(string: i8)
	]]
    local struct_str = [[
        struct(
			# test
            "a": i8,
			# test 2
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
	local general_types_str = [[
		
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
	local _, nested_array = pcall(function()
		return SerDesmond.PrettyCompile(nested_array_str)
	end)
    local _, enum = pcall(function()
        return SerDesmond.PrettyCompile(enum_str)
    end)
    local _, comments_in_weird_spots = pcall(function()
        return SerDesmond.PrettyCompile(comments_in_weird_spots_str)
    end)

	T:Test("Size specifier", function()
		local min_size, max_size = 1, 2^30 - 1
		local buf1 = buffer.create(4)
		local buf2 = buffer.create(4)
		local buf3 = buffer.create(4)
		SerDesmond.write_size_specifier(min_size, buf1, 0)
		SerDesmond.write_size_specifier(63, buf1, 1)
		SerDesmond.write_size_specifier(64, buf1, 2)
		SerDesmond.write_size_specifier(max_size, buf2, 0)

		T:ForContext("writing",
			--						  [s=1 v=1][s=1 v=63][   s=2 v=64    ]
			--						   ssvvvvvv ssvvvvvv ssvvvvvv vvvvvvvv
			T.Equal, dump_bits(buf1), "00000001 00111111 01000000 01000000",
			--						  [           s=3 v=2^30-1           ]
			--						   ssvvvvvv vvvvvvvv vvvvvvvv vvvvvvvv
			T.Equal, dump_bits(buf2), "11111111 11111111 11111111 11111111"
		)

		local full_buf = buffer.create(4)
		-- Fill with 1s
		SerDesmond.write_size_specifier(2^30-1, full_buf, 0)
		-- overwrite 2nd byte
		SerDesmond.write_size_specifier(1, full_buf, 1)

		T:ForContext("written size",
			T.Equal, dump_bits(full_buf), "11111111 00000001 11111111 11111111"
		)

		T:ForContext("reading",
			T.Equal, SerDesmond.read_size_specifier(buf1, 0), 1,
			T.Equal, SerDesmond.read_size_specifier(buf1, 1), 63,
			T.Equal, SerDesmond.read_size_specifier(buf1, 2), 64,
			T.Equal, SerDesmond.read_size_specifier(buf2, 0), 2^30 - 1
		)
	end)
    T:Test("Compile junk", function()
        -- TODO: These will fail with the reported error
        T:ForContext("array",
			T.Equal, typeof(array.Serialize), "function",
			T.Equal, typeof(array.Deserialize), "function"
		)
        T:ForContext("periodic_array",
			T.Equal, typeof(p_array.Serialize), "function",
			T.Equal, typeof(p_array.Deserialize), "function"
		)
        T:ForContext("map",
			T.Equal, typeof(map.Serialize), "function",
			T.Equal, typeof(map.Deserialize), "function"
		)
		T:ForContext("struct",
			T.Equal, typeof(struct.Serialize), "function",
			T.Equal, typeof(struct.Deserialize), "function"
		)
		T:ForContext("enum",
			T.Equal, typeof(enum.Serialize), "function",
			T.Equal, typeof(enum.Deserialize), "function"
		)
		T:ForContext("comments in construct",
			T.Equal, typeof(comments_in_weird_spots.Serialize), "function",
			T.Equal, typeof(comments_in_weird_spots.Deserialize), "function"
		)
    end)

    T:Test("Do the serdes junk", function()
		local t, t2 = comments_in_weird_spots.Deserialize(comments_in_weird_spots.Serialize({a = 1}, Vector3.new(2, 3, 4)))
        T:ForContext("comments in construct",
            T.Equal, t.a, 1,
			T.Equal, t2, Vector3.new(2, 3, 4) 
        )

		local t = enum.Deserialize(enum.Serialize({"asd", "asd", "asdfg"}))
        T:ForContext("enum",
            T.Equal, t[1], "asd",
            T.Equal, t[2], "asd",
            T.Equal, t[3], "asdfg"
        )

		local t = struct.Deserialize(struct.Serialize({a = 1, b = 2, c = 3, [1] = {1, 3.14}}))
		T:ForContext("struct",
			T.Equal, t.a, 1,
			T.Equal, t.b, 2,
			T.Equal, t.c, 3,
			T.Equal, typeof(t[1]), "table",
			T.Equal, t[1][1], 1,
			T.Equal, t[1][2], 3.140000104904175
		)
        local t = array.Deserialize(array.Serialize({1, 2}))
        T:ForContext("array",
            T.Equal, t[1], 1,
            T.Equal, t[2], 2
        )

        t = p_array.Deserialize(p_array.Serialize({1, 2, 3, 4}))
        T:ForContext("periodic array",
            T.Equal, t[1], 1,
            T.Equal, t[2], 2,
            T.Equal, t[3], 3,
            T.Equal, t[4], 4
        )

		local t = nested_array.Deserialize(nested_array.Serialize({{1, 2}, 3}))
		T:ForContext("nested array",
			T.Equal, typeof(t[1]), "table",
			T.Equal, t[1][1], 1,
			T.Equal, t[1][2], 2,
			T.Equal, t[2], 3
		)

		local t = map.Deserialize(map.Serialize({one = 1, two = 2}))
		T:ForContext("map",
			T.Equal, t.one, 1,
			T.Equal, t.two, 2
		)
	end)
end

return mod
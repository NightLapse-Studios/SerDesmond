--!strict

--[[
	Benchmarking against Squash for reference on how we perform

	Squash is more complete in general but also in adhering to attempt to minimize
	the final buffer size. For things like booleans which squash bitpacks and we merely write,
	there is no point benchmarking as squash will be slower but ultimately for a good reason
]]

if game:GetService("RunService"):IsClient() then
	return {}
end

local Config = require(game.ReplicatedFirst.Config)

if Config.RunBench ~= true then
	return {}
end

local SerDesmond = require(script.Parent.SerDesmond)
local Squash = require(script.Parent.Squash)
local T = Squash.T

type Benches = {
	[string]: {
		Arg: any,
		SerDesmond: () -> ((any) -> buffer, (buffer) -> any),
		Squash: () -> (Squash.Cursor, Squash.SerDes<unknown>),
	},
}
local Benches: Benches = {
	Array = {
		Arg = { -1, -2, -3, 1, 2, 3, -1, -2, -3, 1, 2, 3, -1, -2, -3, 1, 2, 3 },
		SerDesmond = function()
			local s, d, _ =
				SerDesmond.Compile([[array(i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8)]])

			return s, d
		end,
		Squash = function()
			local cursor = Squash.cursor()
			return cursor, Squash.array(Squash.int(1), 18)
		end,
	},
	Struct = {
		Arg = { F1 = 1, F2 = 2, F9000 = 3 },
		SerDesmond = function()
			local s, d, _ = SerDesmond.Compile([[struct("F1": i8, "F2": i8, "F9000": i8)]])

			return s, d
		end,
		Squash = function()
			local cursor = Squash.cursor()
			return cursor, Squash.record({ F1 = T(Squash.int(1)), F2 = T(Squash.int(1)), F9000 = T(Squash.int(1)) })
		end,
	},
}

print("Running benchmarks...")
for name, bench in Benches do
	local arg = bench.Arg
	local ser1, des1 = bench.SerDesmond()
	local cursor, squash = bench.Squash()
	local ser2, des2 = squash.ser, squash.des

	local serdesmond_size = buffer.len(ser1(arg))
	ser2(cursor, arg)
	local squash_size = cursor.Pos

	local desmond_times: { number } = {}
	local squash_times: { number } = {}

	for i = 1, 5, 1 do
		local start = os.clock()
		for i = 1, 1000, 1 do
			local a = des1(ser1(arg))
			local a = des1(ser1(arg))
			local a = des1(ser1(arg))
			local a = des1(ser1(arg))
		end
		local serdesmond_time = os.clock() - start

		start = os.clock()
		for i = 1, 1000, 1 do
			ser2(cursor, arg)
			local b = des2(cursor)
			ser2(cursor, arg)
			local b = des2(cursor)
			ser2(cursor, arg)
			local b = des2(cursor)
			ser2(cursor, arg)
			local b = des2(cursor)
		end
		local squash_time = os.clock() - start

		table.insert(desmond_times, serdesmond_time)
		table.insert(squash_times, squash_time)
	end

	local desmond_average = 0
	for i, v in desmond_times do
		desmond_average += v
	end
	desmond_average /= #desmond_times

	local squash_average = 0
	for i, v in squash_times do
		squash_average += v
	end
	squash_average /= #desmond_times

	print(
		`{name}\nSerDesmond:\n\tSize: {serdesmond_size}\n\tTime: {desmond_average}\nSquash:\n\tSize: {squash_size}\n\tTime: {squash_average}`
	)
end

return {}

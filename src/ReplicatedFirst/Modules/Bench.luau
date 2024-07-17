--!strict

--[[
	Benchmarking against Squash for reference on how we perform

	Squash is more complete in general but also in adhering to attempt to minimize
	the final buffer size. For things like booleans which squash bitpacks and we merely write,
	there is no point benchmarking as squash will be slower but ultimately for a good reason
]]

local BENCH_COMPILATION_COMPARISON = false
local BENCH_SERDES_COMPARISON = false
local BENCH_DESMOND_COMPILATION = true

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
		IsComparison: boolean,
		Arg: any,
		SerDesmond: () -> ((any) -> buffer, (buffer) -> any, string),
		Squash: () -> (Squash.Cursor, Squash.SerDes<any>),
	},
}
local Benches: Benches = {
	Array = {
		IsComparison = true,
		Arg = { -1, -2, -3, 1, 2, 3, -1, -2, -3, 1, 2, 3, -1, -2, -3, 1, 2, 3 },
		SerDesmond = function()
			local str = [[array(i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8)]]
			local s, d, _ = SerDesmond.Compile(str)
			return s, d, str
		end,
		Squash = function()
			local cursor = Squash.cursor()
			return cursor, Squash.array(Squash.int(1), 18)
		end,
	},
	Struct = {
		IsComparison = true,
		Arg = { F1 = 1, F2 = 2, F9000 = 3 },
		SerDesmond = function()
			local str = [[struct("F1": i8, "F2": i8, "F9000": i8)]]
			local s, d, _ = SerDesmond.Compile(str)
			return s, d, str
		end,
		Squash = function()
			local cursor = Squash.cursor()
			return cursor, Squash.record({ F1 = T(Squash.int(1)), F2 = T(Squash.int(1)), F9000 = T(Squash.int(1)) })
		end,
	},
	Map = {
		IsComparison = true,
		Arg = { [Vector3.new(1, 1, 1)] = 1, [Vector3.new(1, 1, 2)] = 1, [Vector3.new(1, 2, 2)] = 1 },
		SerDesmond = function()
			local str = [[map(vector3(f64, f64, f64): i8)]]
			local s, d, _ = SerDesmond.Compile(str)
			return s, d, str
		end,
		Squash = function()
			local cursor = Squash.cursor()
			return cursor, Squash.map(Squash.Vector3(Squash.number(8)), Squash.int(1))
		end,
	},
	ManyFieldsCompTest = {
		IsComparison = false,
		Arg = false,
		SerDesmond = function()
			local str = [[
			array(
				struct("asdf": i8),
				vector3(i8, i8, i8),
				string,
				periodic_array(i8, f64),
				enum("one", "two", "threeee"),
				map(i8: string)
			)]]
			local s, d, _ = SerDesmond.Compile(str)
			return s, d, str
		end,
		Squash = function() end,
	},
}

local function run_bench(iterations, fn, arg)
	local times = table.create(iterations)
	local abs_start = os.clock()
	for i = 1, iterations, 1 do
		local start = os.clock()
		fn(arg)
		table.insert(times, os.clock() - start)
		if os.clock() - abs_start > 1 then
			task.wait()
			abs_start = os.clock()
		end
	end

	local average = 0
	local total = 0
	for i, v in times do
		average += v
		total += v
	end
	average /= #times

	table.sort(times)

	return times, average, total
end

print("Running benchmarks...")
task.spawn(function()
	for name, bench in Benches do
		if not bench.IsComparison then
			continue
		end

		local arg = bench.Arg
		local ser1, des1 = bench.SerDesmond()
		local cursor, squash = bench.Squash()
		local ser2, des2 = squash.ser, squash.des

		local serdesmond_size = buffer.len(ser1(arg))
		ser2(cursor, arg)
		local squash_size = cursor.Pos

		print(name .. ":")

		if BENCH_SERDES_COMPARISON then
			local desmond_times, desmond_average = run_bench(1000, function(arg)
				local a
				for i = 1, 100, 1 do
					a = des1(ser1(arg))
					a = des1(ser1(arg))
					a = des1(ser1(arg))
					a = des1(ser1(arg))
				end
				return a
			end, arg)

			local squash_times, squash_average = run_bench(1000, function(arg)
				local b
				for i = 1, 100, 1 do
					ser2(cursor, arg)
					b = des2(cursor)
					ser2(cursor, arg)
					b = des2(cursor)
					ser2(cursor, arg)
					b = des2(cursor)
					ser2(cursor, arg)
					b = des2(cursor)
				end
				return b
			end, arg)

			print(
				`SerDesmond:\n\tSize: {serdesmond_size}\n\tTime: {desmond_average}\nSquash:\n\tSize: {squash_size}\n\tTime: {squash_average}`
			)
			print(`Ratio: (Desmond / Squash) = {desmond_average / squash_average}`)
		end

		if BENCH_COMPILATION_COMPARISON then
			local desmond_comp_times, desmond_comp_average = run_bench(200, function(arg)
				local a
				for i = 1, 150, 1 do
					a = bench.SerDesmond()
				end
				return a
			end, arg)
			local squash_comp_times, squash_comp_average = run_bench(200, function(arg)
				local a
				for i = 1, 150, 1 do
					a = bench.Squash()
				end
				return a
			end, arg)

			print(
				`SerDesmond comp time: {desmond_comp_average}\nSquash comp time: {squash_comp_average}\nRatio: {desmond_comp_average / squash_comp_average}`
			)
		end

		task.wait()
	end
end)

if BENCH_DESMOND_COMPILATION then
	task.spawn(function()
		for name, bench in Benches do
			for i = 1, 3, 1 do
				local external_iters = 128
				local internal_iters = 50
				local _, _, comp_string = bench.SerDesmond()
				local desmond_comp_times, desmond_comp_average, desmond_comp_total = run_bench(
					external_iters,
					function(arg)
						local bench = arg[1]
						local internal_itters = internal_iters
						local a
						for i = 1, internal_itters, 1 do
							a = bench.SerDesmond()
							a = bench.SerDesmond()
							a = bench.SerDesmond()
							a = bench.SerDesmond()
						end
						return a
					end,
					{ bench }
				)

				local compilations_total = external_iters * internal_iters * 4

				local comps_per_second = 1 / (desmond_comp_total / compilations_total)
				print(
					`{name}: {desmond_comp_average} per {internal_iters * 4} compilations ({desmond_comp_total} total time)`
				)
				print(`\troughly {comps_per_second} compilations per second`)
				print(`\troughly {comps_per_second * string.len(comp_string) / 1024} kB per second`)
			end
		end
	end)
end

return {}

---
sidebar_position: 3
---

# Performance

In the repository, a rudimentary benchmark script can be toggled with [Config.RunBench](https://github.com/NightLapse-Studios/SerDesmond/blob/main/src/ReplicatedFirst/Config.luau#L90). Individual benchmarks can be toggled from within the [Bench](https://github.com/NightLapse-Studios/SerDesmond/blob/main/src/ReplicatedFirst/Modules/Bench.luau) script. The first time you run benchmarks after starting studio will tend to produce slower results than future runs even though each benchmark is run multiple times.

The below figures are from a machine using a desktop Ryzen 5 1600x (one of the earliest ryzen processors) with modules in native mode. We use Squash as a reference since it is the most equivalent project.

## Compilation
Obviously SerDesmond is much slower to construct than Squash due to having a compilation from string stage. It will never be as fast as other libraries in this regard, it will always be orders of magnitude slower (currently ~1.5 to 2.5 orders of magnitude slower). However, it can compile about 1.2-2.1mB/s depending on the structure. Larger structures tend to have higher throughput. I can compile a simple map 41k times per second with 1.2 mB/s throughput while the ManyFieldsCompTest compiles 14k times per second with a throughput of ~2.1 mB/s on my machine. Whitespace can inflate perceived throughput values since they do not entail any work in the compilation stage.

It seems that it's already the case that only truly massive structures need to worry about compilation time, which should generally be done only once on application startup to begin with.

## SerDes

SerDes performance is about the same as any other buffer SerDes library since we still compile down to the same constructs as them. We don't do buffer reallocations though, so in principle we will tend to be faster. Faster SerDes is a goal of this project.

Due to lack of time in the oven, desmond may be slower in some scenarios or may be missing byte-saving strategies. E.G. writing an 18 element array is marginally faster than Squash, meanwhile writing to a struct with 3 fields is marginally slower. Large structures should expect overall better performance due to lack of buffer reallocations.
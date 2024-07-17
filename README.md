# SerDesmond

A runtime SerDes IDL for luau buffers.

It is WIP.

Since it uses strings as input it is inherently unable to return functions with the proper type. We may expose a way to construct the SerDes functions more directly to work around this in the future.

```luau
local SerDesmond = require("../SerDesmond")

local ser, des, _ = SerDesmond.Compile([[
	array(
		struct("asdf": i8),
		vector3(i8, i8, i8),
		string,
		periodic_array(i8, f64),
		enum("one", "two", "three"),
		map(i8: string)
	)
]])

local buf: buffer = ser({
	{ asdf = 1 },
	Vector3.new(2, 3, 4),
	"yooo",
	{ 7, 8.2, 9, 3.14 },
	{ "one", "two", "three" },
	{ [4] = "10", [5] = "11", [6] = "12" },
})

local original = des(buf)
```

## Performance

**Performance is highly WIP and will get much better**

These figures are from a machine using a desktop Ryzen 5 1600x (one of the earliest ryzen processors) with modules in native mode.

### Compilation
Obviously SerDesmond is much slower to start up due to having a compilation from string stage. It will never be as fast as Squash in this regard, it will always be orders of magnitude slower (currently ~1.5 to 2.5 orders of magnitude slower). However, it can currently compile about 1.3-2.1mB/s depending on the structure. Larger structures tend to have higher throughput. I can compile a simple map 45k times per second with 1.35 mB/s throughput while the ManyFieldsCompTest compiles 14k times per second with a throughput of ~2.1 mB/s on my machine. Only truly massive structures need to worry about compilation time, which should generally be done only once on application startup to begin with.

### SerDes

SerDes performance is about the same as any other buffer SerDes library since we still compile down to the same constructs as them. There is a lot of work let to do to get everything up to par, but also additional opportunity in this aspect since we can analyze the AST and form some higher-performing functions (we currently don't do this almost at all).

Due to lack of time in the oven, desmond may be slower in some scenarios or may be missing byte-saving strategies, but it is already faster sometimes since it does not try to reallocate buffers on every write like Zap and Squash. E.G. writing an 18 element array is marginally faster than Squash, meanwhile writing to a struct with 3 fields is marginally slower. Large structures should expect overall better performance due to lack of buffer reallocations.
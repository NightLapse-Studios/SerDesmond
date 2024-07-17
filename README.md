# SerDesmond

A runtime SerDes IDL for luau buffers.

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

## Use cases

Since it uses strings as a compilation source, you can do some things you usually can't, like concatenate two SerDes routines together, or use one as a node in another. You can also store the string alongside its output, essentially serializing the routine that serialized that data.
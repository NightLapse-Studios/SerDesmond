# SerDesmond

A WIP runtime SerDes IDL for luau buffers.

This project makes the silly choice to compile a string to SerDes functions. 

```lua
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

local buf = ser({
	{ asdf = 1 },
	Vector3.new(2, 3, 4),
	"yooo",
	{ 7, 8.2, 9, 3.14 },
	{ "one", "two", "three" },
	{ [4] = "10", [5] = "11", [6] = "12" },
})

local original = des(buf)
```

# Why tho??

Just an experimental project!

The only concrete advantage at the moment is that your SerDes source is itself a serialized SerDes source, which could come in handy. Composition of SerDes strings could also be interesting.

Since it uses strings as input it is inherently unable to return functions with the proper type. We may expose a way to construct the SerDes functions more directly to work around this in the future. In the meantime if that is a deal breaker, then [Squash](https://github.com/Data-Oriented-House/Squash) is a good non-experimental choice that also supports instances directly.

Advantages that could be leveraged from an AST, in practice, are not really advantages because they could be applied to other libraries as well (though they currently are not) without having to parse a string input. Plus, we still have the fact that the most primitive "instruction" we can compile down to is a pre-written luau function.


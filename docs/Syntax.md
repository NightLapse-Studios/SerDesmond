---
sidebar_position: 2
---

# Usage

## General

SerDesmond generally takes in a list of type literals and then their parameters if there are any. Each entry in the top-level of the string corresponds to an argument in the serialize function, and a result from the deserialize function. Comma separators are optional but preferred.

Keywords are all lowercase, even for Vector3 which should be declared as `vector3(...)`. Aliases *may* be added in the future.

```lua
local ser, _ = SerDesmond.Compile("i8, f64")

local buf = ser(1, 3.14)
```

Some constructs associate one type with another using a "binding", like so (the colon separator is not optional!):

```lua
SerDesmond.Compile([[ struct("field_1": i8) ]])
```

Nested types are allowed where appropriate:

```lua
SerDesmond.Compile([[
	array(
		struct("field_1": i8),
		struct("field_1": i8),
	)
]])
```

## Types / Constructs

### Type literals

Type literals correspond to the associated buffer primitives:

```lua
SerDesmond.Compile([[
	i8,
	i16,
	i32,
	u8,
	u16,
	u32,
	f32,
	f64
]])
```

### Number literals

Number literals function like a type literals except their stored size is base on the number supplied. You still need to supply the value as an argument for performance reasons, and the supplied number can override the literal (also for performance reasons); there is NO benefit to using number literals like that intentionally, use a type literal instead.

```lua
local ser, des = SerDesmond.Compile([[
	array(1, 2)
]])

local result = des(ser(1, 2))
-- result == { [1] = 1, [2] = 2}
```

### String literals

String literals function like number literals, however, the value passed in is ignored and the compiled value is used. The treatment of arguments may be made consistent between number/string literals in the future.

The behavior of ignoring the argument is not intended to be leveraged.

```lua
local ser, des = SerDesmond.Compile([[ "test" ]])

local result = des(ser(1))
-- result == "test"
```

### Strings

Strings are just like string literals except any string can take its value.

```lua
local ser, des = SerDesmond.Compile([[ array(string, string) ]])

local result = des(ser({"one", "three"}))
-- result == {"one", "three"}
```

### Arrays

Arrays are a fixed-length ordered list of constructs. You cannot use less or more than the list of supplied constructs.

```lua
local ser, des = SerDesmond.Compile([[
	array(
		array("Yep", i8),
		array(f32, f32)
	)
]])

local result = des(ser({
	{ "Yep", 1 },
	{ 3.14, -3.14 }
}))
```

### Periodic arrays

Sometimes you just have a list of things that you want to chuck in a single array... over and over. You can describe that with periodic arrays, who's contents will be just like an array but it can repeat any number of times.

```lua
local ser, des = SerDesmond.Compile([[
	periodic_array(
		string, i8
	)
]])

local result = des(ser({
	"thing1", 1
	"thing2", 2
}))
-- result == {
--   [1] = "thing1",
--	 [2] = 1,
--	 [3] = "thing2,
--	 [4] = 2,
-- }
```

### Enums

An enum is a list of strings that will be stored as numbers instead. You can use each string any number of times. The deserialized order is not equivalent to the order they are passed in.

```lua
local ser, des = SerDesmond.Compile([[
	enum(
		"test1", "test2, "test3
	)
]])

local buf = ser({"test1", "test1", "test3"})
-- buf len == 3, contains 0x1, 0x1, 0x3 in any order
local result = des(buf)
-- result == {"test1", "test1", "test3"}
-- but in any order!
```

### Maps

Describes a table with an indexer of one type and a value of another type

```lua
local ser, des = SerDesmond.Compile([[
	map(
		string: i8
	)
]])

local result = des(ser( {thing1 = 1, thing2 = 2} ))
-- result == {thing1 = 1, thing2 = 2}
```

### Structs

Maps indexers that are type literals to a construct. Can use both string and number literals as indexers.

```lua
local ser, des = SerDesmond.Compile([[
	struct(
		"thing1": i8,
		"thing2": f64
	)
]])

local result = des(ser( {thing1 = 1, thing2 = 3.14} ))
```

Fields in a struct can be marked as optional

```lua
[[ struct(@optional "thing1": i8) ]]
```

### Vector3

A simple Vector3 :~) Unlike most libraries each axis can be restricted to its own primitive.

```lua
local ser, des = SerDesmond.Compile([[ vector3(i8, i32, i8)]])
```

### Players

Communicates a Player instance using the UserId and `PlayerService::GetPlayerByUserId`. Serialized players only make sense in the context of a server which has the player connected actively.

```lua
local ser, des = SerDesmond.Compile([[ player ]])
```

## Comments

We support comments with the `#` symbol.

```lua
local ser, des = SerDesmond.Compile([[
	# This is my fancy thing
	struct # It is so cool
	(
		"thing1": # I just love it
		f64
	)
]])
```

## Attributes

A construct can be prefixed with `@<attribute>` to add metadata to it. If the attribute is not supported by the construct, then an error will be generated.

### @optional

A binding in a struct can be marked as optional to signify that they may or may not exist in the supplied object. Currently only struct supports this attribute.

Note that using any optional fields in a struct adds overhead such as needing to count inputs to its SerDes which may be considerable in extreme scenarios.

```lua
SerDesmond.Compile([[
	struct(
		@optional
		"thing1": i8
	)
]])
```

### @precise32, @precise64

Overrides the default precision used to encode angles in cframes. Rarely necessary, but may be used to increase the precision of orientation. Default precision should be similar to roblox, which also encodes its angles into 6 bytes.

```lua
SerDesmond.Compile([[
	# Uses f64s to encode Euler angles
	@precise64 cframe(u8, u8, u8),
	# Uses f32s to encode Euler angles
	@precise32 cframe(u8, u8, u8),
	# Compresses Euler angles into proportion of 2pi, using u16s
	cframe(u8, u8, u8)
]])
```


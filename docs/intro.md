---
sidebar_position: 1
---

# Getting started

Getting started is as easy as calling `SerDesmond.Compile` on a string:

```lua
local SerDesmond = require("../SerDesmond")

local ser, des = SerDesmond.Compile([[array(i8, f64)]])

local buf = ser({-1, 3.14})
local original = des(buf)
```

Constructs listed on the top-level of the compiled string will each correspond to an argument in the resulting serializer, as well as causing the deserializer to output a tuple

```lua
local ser, des = SerDesmond.Compile([[i8, array(i8)]])

local buf = ser(1, {2})
local a1, a2 = des(buf)
-- a1 == 1, a2 == {[1] = 2}
```

Errors in the input can be annotated by passing `true` as the 2nd argument to `Compile`

```lua
SerDesmond.Compile("cframe(@optional array(i8), i8, i8)", true)
--Ln 1:18
--  cframe(@optional array(i8), i8, i8)
--                   ^^^^^
--  cframe expects only type literals for its vector components
--  array does not support attribute "optional"
```


```EBNF
    serdes = construct {"," construct}

    type_literal = "i8"
    | "i16"
    | "i32"
    | "u8"
    | "u16"
    | "u32"
    | "f32"
    | "f64"

    string_literal = '"' STRING '"'
    number_literal = NUMBER

    prim_construct = type_literal | string_literal | number_literal
    construct = [attribute] prim_construct
    | enum
    | array
    | periodic_array
    | vector3
    | map
    | cframe
    | player
    | bool

    enum = "enum" "(" string_literal {"," string_literal } ")"
    array = "array" "(" construct {"," construct } ")"
    periodic_array = "periodic_array" "(" construct {"," construct } ")"
    vector3 = "vector3" "(" type_literal, type_literal, type_literal ")"
    cframe = "cframe" "(" type_literal, type_literal, type_literal ")"
    map = "map" "(" binding ")"
    struct = "struct" "(" binding_list ")"
    player = "player"
    bool = "boolean" | "bool"

    binding = construct ":" construct
    binding_list = binding { [","] binding }

    comment = "#" STRING ;
    attribute = "@" STRING
```
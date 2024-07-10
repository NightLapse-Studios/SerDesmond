--!strict

local is_separator = require(script.Parent.is_separator)
local Tokenizer = require(script.Parent.Tokenizer)

local mod = { }

type i8_literal = "i8"
type i16_literal = "i16"
type i32_literal = "i32"
type u8_literal = "u8"
type u16_literal = "u16"
type u32_literal = "u32"
type f32_literal = "f32"
type f64_literal = "f64"
type TypeLiteral =  i8_literal | i16_literal | i32_literal |
                    u8_literal | u16_literal | u32_literal |
                    f32_literal | f64_literal

type ASTCommon = {
    TokenIndex: number,
    TokenSize: number
}
type ASTRoot = {
    Type: "root",
    Value: ASTChildren,
    Extra: false
} & ASTCommon
type ASTError = {
    Type: "error",
    Value: string,
    Extra: string
} & ASTCommon
type ASTErrorWChildren = {
    Type: "error",
    Value: ASTChildren,
    Extra: string
} & ASTCommon
type ASTComment = {
    Type: "comment",
    Value: string,
    Extra: false
} & ASTCommon
type ASTTypeLiteral = {
    Type: "type_literal",
    Value: TypeLiteral,
    Extra: false
} & ASTCommon
type ASTStringLiteral = {
    Type: "string_literal",
    Value: string,
    Extra: false
} & ASTCommon
type ASTNumberLiteral = {
	Type: "number_literal",
	Value: number,
	Extra: TypeLiteral
} & ASTCommon
type ASTIdList = {
    Type: "enum",
    Value: ASTChildren,
    Extra: false
} & ASTCommon
type ASTArray = {
    Type: "array",
    Value: ASTChildren,
    Extra: false
} & ASTCommon
type ASTPeriodicArray = {
    Type: "periodic_array",
    Value: ASTChildren,
    Extra: false
} & ASTCommon
type ASTVector3 = {
    Type: "vector3",
    Value: ASTChildren,
    Extra: false
} & ASTCommon
type ASTSizeSpecifier = {
    Type: "size_specifier",
    Value: number,
    Extra: false
} & ASTCommon
type ASTBinding = {
    Type: "binding",
    Value: ASTChildren,
    Extra: false
} & ASTCommon
type ASTMap = {
	Type: "map",
	Value: ASTChildren,
	Extra: false
} & ASTCommon
type ASTString = {
	Type: "string",
	Value: unknown,
	Extra: false
} & ASTCommon
type ASTStruct = {
	Type: "struct",
	Value: { ASTBinding },
	Extra: false
} & ASTCommon

type ASTChildren = { ASTNode } | { ASTChildren }
type ASTNode =
    ASTCommon
    | ASTRoot
    | ASTError
    | ASTErrorWChildren
    | ASTComment
    | ASTTypeLiteral
    | ASTStringLiteral
	| ASTNumberLiteral
    | ASTIdList
    | ASTArray
    | ASTPeriodicArray
    | ASTVector3
    | ASTSizeSpecifier
    | ASTBinding
	| ASTMap
	| ASTString
	| ASTStruct


--[[
    Setup and helper funcitons
]]

local type_literal_sizes = {
    i8 = 1,
    i16 = 2,
    i32 = 4,
    u8 = 1,
    u16 = 2,
    u32 = 4,
    f32 = 4,
    f64 = 8,
}

local terminal_to_idx = {
    i8 = 1,
    i16 = 2,
    i32 = 3,
    u8 = 4,
    u16 = 5,
    u32 = 6,
    f32 = 7,
    f64 = 8,
}

local writers, readers
local function w_i8(v: number, b: buffer, idx: number)
    buffer.writei8(b, idx, v)
    return 1
end
local function w_i16(v: number, b: buffer, idx: number)
    buffer.writei16(b, idx, v)
    return 2
end
local function w_i32(v: number, b: buffer, idx: number)
    buffer.writei32(b, idx, v)
    return 4
end
local function w_u8(v: number, b: buffer, idx: number)
    buffer.writeu8(b, idx, v)
    return 1
end
local function w_u16(v: number, b: buffer, idx: number)
    buffer.writeu16(b, idx, v)
    return 2
end
local function w_u32(v: number, b: buffer, idx: number)
    buffer.writeu32(b, idx, v)
    return 4
end
local function w_f32(v: number, b: buffer, idx: number)
    buffer.writef32(b, idx, v)
    return 4
end
local function w_f64(v: number, b: buffer, idx: number)
    buffer.writef64(b, idx, v)
    return 8
end


local function r_i8(b: buffer, idx: number)
    return buffer.readi8(b, idx), 1
end
local function r_i16(b: buffer, idx: number)
    return buffer.readi16(b, idx), 2
end
local function r_i32(b: buffer, idx: number)
    return buffer.readi32(b, idx), 4
end
local function r_u8(b: buffer, idx: number)
    return buffer.readu8(b, idx), 1
end
local function r_u16(b: buffer, idx: number)
    return buffer.readu16(b, idx), 2
end
local function r_u32(b: buffer, idx: number)
    return buffer.readu32(b, idx), 4
end
local function r_f32(b: buffer, idx: number)
    return buffer.readf32(b, idx), 4
end
local function r_f64(b: buffer, idx: number)
    return buffer.readf64(b, idx), 8
end


-- Non-terminal writers rely on upvalues and are generated in the serialize/deserialize visitors
writers = {
    w_i8, w_i16, w_i32, w_u8, w_u16, w_u32, w_f32, w_f64,
}

readers = {
    r_i8, r_i16, r_i32, r_u8, r_u16, r_u32, r_f32, r_f64,
}

-- Fortunately we only use these functions to store byte lengths, so u32 is enough
local raw_byte_writers: {(v: number, b: buffer, idx: number) -> number} = {
    [1] = w_u8,
    [2] = w_u16,
    [3] = w_u32,
    [4] = w_u32
}
local raw_byte_readers: {(buffer, idx: number) -> number} = {
    [1] = r_u8,
    [2] = r_u16,
    [3] = r_u32,
    [4] = r_u32,
}

local function sum(t: { number })
    local s = 0
    for i,v in t do
        s += v
    end

    return s
end

local function bits(n: number)
    -- 1 is added to value because max we can store in a byte is 255, not 256
    return math.log(n + 1, 2)
end

local function bytes_to_store_value(n: number): number
    -- number of bytes needed to store the node's value as a binary number
    return math.ceil((bits(n) + 2) / 8)
end

local function bytes_to_store_dynamic_size(n: number): number
    local bytes = bytes_to_store_value(n)

    -- Handle the fact that buffer.writeu24 doesn't exist
    -- Maybe use sub-writes in the future to squeeze out another byte in this case?
    if bytes == 3 then bytes = 4 end

    return bytes
end

local function write_size_specifier(v: number, b: buffer, idx: number)
    assert(v < 2^30)
    local bytes = bytes_to_store_dynamic_size(v)

    -- subtract 1 so we can store 1-4 in 2 bits
	local encoded_size = bytes - 1
    -- pack the length into the number, using its 2 most significant bits
    v = bit32.replace(v, encoded_size, bytes * 8 - 2, 2)

    return raw_byte_writers[bytes](v, b, idx)
end

local function read_size_specifier(b: buffer, idx: number)
	-- To allowe a size specifier to terminate a buffer, we can't assume its size
	local first = buffer.readu8(b, idx)
    local bytes = bit32.extract(first, 6, 2) + 1
    local dat = raw_byte_readers[bytes](b, idx)
    local bits = bytes * 8

    return bit32.extract(dat, 0, bits - 2), bytes
end

local function bits_to_store_size_specifier(n: number)
    return 2 + math.log(n, 2)
end
local function bytes_to_store_size_specifier(n: number)
    return math.max(math.ceil(bits_to_store_size_specifier(n) / 8))
end

local function bytes_to_store_type(t: string)
    return type_literal_sizes[t]
end

local function count_table_keys(t: { })
	local i = 0
	for _, _ in t do
		i += 1
	end

	return i
end




--[[
    AST from token stream
]]

type Tokens = { string }

local NodeConstructors

local function node_from_token(tokens: Tokens, idx: number): (ASTNode | ASTChildren, number)
    local token = tokens[idx]

    if string.sub(token, 1, 1) == "#" then
        return NodeConstructors.comment(tokens, idx)
    end

    if token == "\"" then
        return NodeConstructors.string_literal(tokens, idx)
    end

	if tonumber(token) ~= nil then
		return NodeConstructors.number_literal(tokens, idx)
	end

    local node_ctor = NodeConstructors[token]

    if not node_ctor then
        if tokens[idx + 1] == "(" then
            return NodeConstructors.error_with_unparsed_children(tokens, idx, `Unrecognized type identifier {token}`)
        else
            return NodeConstructors.error(tokens, idx, `Unrecognized type identifier {token}`, 1)
        end
    end

    return node_ctor(tokens, idx)
end

local function parse_binding(tokens: Tokens, idx: number): (ASTBinding | ASTError, number)
    local lhs, rhs, consumed
    local consumed_total = 0
    lhs, consumed = node_from_token(tokens, idx)
    consumed_total += consumed
    idx += consumed

    if tokens[idx] == ":" then
        idx += 1
        rhs, consumed = node_from_token(tokens, idx)
        consumed_total += (consumed + 1)
        idx += consumed

        return NodeConstructors.binding(tokens, idx, {lhs, rhs}, consumed_total)
    else
        rhs, consumed = node_from_token(tokens, idx)
        consumed_total += consumed
        idx += consumed

        return NodeConstructors.error_with_children(tokens, idx, `Type binding missing assignment separator`, consumed_total, {lhs, rhs})
    end
end

local function parse_binding_list(tokens: Tokens, idx: number): ({ASTBinding} | ASTError, number)
    if tokens[idx] ~= "(" then
        return NodeConstructors.error(tokens, idx, `Unexpected token {tokens[idx]}: missing ( to open binding list`, 0)
    end

    local children, consumed_total = { }, 1
    idx += 1

    while true do
        if tokens[idx] == ")" then
            break            
        end

        local child, consumed = parse_binding(tokens, idx)
        table.insert(children, child)
        idx += consumed

        if tokens[idx] == "," then
            consumed += 1
            idx += 1
        end

        consumed_total += consumed
    end

    consumed_total += 1

    return children, consumed_total
end

-- Parses a list of type literals or parent type nodes such as vector3/list
local function parse_chunk(tokens: Tokens, idx: number): (ASTChildren, number)
    local token_ct = #tokens
    local consumed = 0
    local nodes: ASTChildren = { }
    while idx <= token_ct do
        local token = tokens[idx]

        -- Not all chunks start with a `(`, for example the top level one
        if idx == 1 and token == "(" then
            consumed += 1
            idx += 1
            continue
        elseif token == ")" then
            consumed += 1
            break
        elseif is_separator(token) then
            consumed += 1
            idx += 1
            continue
        end

        local root_node, children_consumed = node_from_token(tokens, idx)
        
        consumed += children_consumed
        idx += root_node.TokenSize

        table.insert(nodes, root_node)
    end

    return nodes, consumed
end

local function parse_token_stream(tokens: { string })
    return NodeConstructors.root(tokens)
end

local ASTNode = { }
ASTNode.__index = ASTNode

local function new_node(type: string, value: unknown, index: number, tokens_consumed: number, extra: string?): ASTNode
    local node = {
        Type = type,
        Value = value,
        Index = index,
        TokenSize = tokens_consumed,
        Extra = extra or false,
    }

    setmetatable(node, ASTNode)

    return node
end


function ASTNode:Accept(visitor)
    return visitor:Visit(self)
end

local RootConstructs = {
	type_literal = true,
	string_literal = true,
	array = true,
	periodic_array = true,
	vector3 = true,
}

function ASTNode:IsRootConstruct()
	return RootConstructs[self.Type] == true
end

-- Each function return the node and then the number of tokens it consumed
-- The parse function handles closing parenthesis but not opening ones since each of these
-- will be consuming tokens after the opening parenthesis

local function root(tokens: { string }, idx)
	local children, consumed = parse_chunk(tokens, 1)
	local node = new_node("root", children, 1, consumed) :: ASTRoot
	return node, consumed
end
local function error(tokens: { string }, idx: number, err: string, size: number)
	local node = new_node("error", tokens[idx], idx, size, err) :: ASTError
	return node, size
end
local function error_with_children(tokens: { string }, idx: number, err: string, token_size: number, children: { ASTNode })
	local node = new_node("error", children, idx, token_size, err)
	return node, token_size
end
local function error_with_unparsed_children(tokens: { string }, idx: number, err: string)
	local children, consumed = parse_chunk(tokens, idx + 1)
	local consumed_total = consumed + 1
	local node, _ = error_with_children(tokens, idx, err, consumed_total, children)
	return node, consumed_total
end
local function comment(tokens: { string }, idx: number)
	-- The entire comment is a single token
	-- local node = new_node("comment", tokens[idx], idx, 1)
	return nil, 1
end
local function type_literal(tokens: { string }, idx: number)
	local node = new_node("type_literal", tokens[idx], idx, 1)
	return node, 1
end
local function string_literal(tokens: { string }, idx: number)
	return new_node("string_literal", tokens[idx + 1], idx, 3), 3
end
local function number_literal(tokens: { string }, idx: number)
	local n = tonumber(tokens[idx])
	if typeof(n) == "number" then
		local primitive
		if n % 1 == 0 then
			primitive = "f64"
		else
			primitive = "i32"
		end
		return new_node("number_literal", n, idx, 1, primitive), 1
	else
		return error(tokens, idx, "Internal error: passed non-number to number_literal", 1)
	end
end
local function _string(tokens: { string }, idx: number)
	return new_node("string", false, idx, 1), 1
end
local function enum(tokens: { string }, idx: number)
	local children, consumed = parse_chunk(tokens, idx + 1)
	local consumed_total = consumed + 1

	for i,v in children do
		if v.Type ~= "string_literal" then
			local err, _ = error(tokens, v.Index, `Unexpected {v.Value}, enum can only contain string literals`, v.TokenSize)
			children[i] = err
		end
	end

	-- Specifies the size of the numbers stored in the buffer, not the length
	-- table.insert(children, new_node("size_specifier", #children, -1, 0))

	return new_node("enum", children, idx, consumed_total), consumed_total
end
local function array(tokens: { string }, idx: number)
	local children, consumed = parse_chunk(tokens, idx + 1)
	local consumed_total = consumed + 1

	for i,v in children do
		if not v:IsRootConstruct() then
			if v.Type ~= "error" then
				local err, _ = error(tokens, v.Index, `Unexpected {v.Value}, array can only contain read/write constructs`, v.TokenSize)
				children[i] = err
			end
		end
	end

	return new_node("array", children, idx, consumed_total), consumed_total
end
local function periodic_array(tokens: { string }, idx: number)
	local children, consumed = parse_chunk(tokens, idx + 1)
	local consumed_total = consumed + 1

	for i,v in children do
		if not v:IsRootConstruct() then
			if v.Type ~= "error" then
				local err, _ = error(tokens, v.Index, `Unexpected {v.Value}, array can only contain read/write constructs`, v.TokenSize)
				children[i] = err
			end
		end
	end

	return new_node("periodic_array", children, idx, consumed_total), consumed_total
end
local function map(tokens: { string }, idx: number)
	local children, consumed = parse_binding_list(tokens, idx + 1)
	local consumed_total = consumed + 1

	if #children > 1 then
		for i,v in children do
			local err, _ = error(tokens, v.Index, "map can only have one binding", v.TokenSize)
			children[i] = err
		end
	end

	if children[1].Type ~= "binding" then
		return error(tokens, idx, "map must contain a type binding", consumed_total)
	end

	return new_node("map", children, idx, consumed_total), consumed_total
end
local function struct(tokens: { string }, idx: number)
	local children, consumed = parse_binding_list(tokens, idx + 1)
	local consumed_total = consumed + 1

	for i,v in children do
		if v.Type ~= "binding" then
			local err, _ = error(tokens, v.Index, "dictionaries can only contain bindings", v.TokenSize)
			children[i] = err
		end
	end

	return new_node("struct", children, idx, consumed_total), consumed_total
end
local function vector3(tokens: { string }, idx: number)
	local children, consumed = parse_chunk(tokens, idx + 1)
	local consumed_total = consumed + 1

	local is_ok = #children == 3
	for i,v in children do
		if v.Type ~= "type_literal" then
			is_ok = false
			break
		end
	end

	if not is_ok then
		return error(tokens, idx, "vector3 expects 3 type literals", consumed_total)
	end
	
	return new_node("vector3", children, idx, consumed_total), consumed_total
end
local function size_specifier(tokens: { string }, idx: number)
	local seperator = tokens[idx + 1]
	local size = tonumber(tokens[idx + 2])

	if not is_separator(seperator) then
		return error(tokens, idx, "Missing seperator for size specifier", 2)
	end

	if not size then
		return error(tokens, idx, "Expected number for size specifier", 3)
	end
	
	return new_node("size_specifier", size, idx, 3), 3
end
local function max_size(tokens: { string }, idx: number)
	return size_specifier(tokens, idx)
end
local function binding(tokens: { string }, idx: number, children: { ASTNode }, token_size: number)
	return new_node("binding", children, idx, token_size), token_size
end
local function i8(tokens: { string }, idx: number)
	return type_literal(tokens, idx)
end
local function i16(tokens: { string }, idx: number)
	return type_literal(tokens, idx)
end
local function i32(tokens: { string }, idx: number)
	return type_literal(tokens, idx)
end
local function u8(tokens: { string }, idx: number)
	return type_literal(tokens, idx)
end
local function u16(tokens: { string }, idx: number)
	return type_literal(tokens, idx)
end
local function u32(tokens: { string }, idx: number)
	return type_literal(tokens, idx)
end
local function f8(tokens: { string }, idx: number)
	return type_literal(tokens, idx)
end
local function f16(tokens: { string }, idx: number)
	return type_literal(tokens, idx)
end
local function f32(tokens: { string }, idx: number)
	return type_literal(tokens, idx)
end
local function f64(tokens: { string }, idx: number)
	return type_literal(tokens, idx)
end

NodeConstructors = {
	root = root,
	error = error,
	error_with_unparsed_children = error_with_unparsed_children,
	error_with_children = error_with_children,
	comment = comment,
	type_literal = type_literal,
	string_literal = string_literal,
	number_literal = number_literal,
	string = _string,
	enum = enum,
	array = array,
	periodic_array = periodic_array,
	map = map,
	struct = struct,
	vector3 = vector3,
	size_specifier = size_specifier,
	max_size = max_size,
	binding = binding,
	i8 = i8,
	i16 = i16,
	i32 = i32,
	u8 = u8,
	u16 = u16,
	u32 = u32,
	f8 = f8,
	f16 = f16,
	f32 = f32,
	f64 = f64,
}



--[[
    Visitors
]]

local Visitor = { }
Visitor.__index = Visitor

local function Visit(self: Visitor, node: ASTNode)
    local ty = node.Type
    local visit_fn = self[ty]
    if not visit_fn then
        error(`Visitor missing impl for {node.Type}`)
    end

    return visit_fn(self, node)
end

local function TraverseChildren(self: Visitor, node: ASTNode)
    local children = node.Value
    local len = #children

    for i = 1, len, 1 do
        children[i]:Accept(self)
    end

    return true
end

local function CollectChildren(self: Visitor, node: ASTNode)
    local children = node.Value :: { ASTNode }
    local len = #children
    local vals = table.create(len)

    for i = 1, len, 1 do
        -- Some weird incantation that lets a visitor be able to return any number of values without using tables
		-- This behavior is desirable to let CollectChildren output a linear list of return values even if some
		-- nodes return multiple values
        -- E.G. the NodeSizeVisitor wants a linear list of node sizes
        local val = { children[i]:Accept(self) }
        for _, v in val do
            table.insert(vals, v)
        end
    end

    return vals
end

type Visitor = {
    root:                (Visitor, ASTRoot) -> any?,
    comment:             (Visitor, ASTComment) -> any?,
    error:               (Visitor, ASTError) -> any?,
    error_with_children: (Visitor, ASTErrorWChildren) -> any?,
    type_literal:        (Visitor, ASTTypeLiteral) -> any?,
    string_literal:      (Visitor, ASTStringLiteral) -> any?,
	number_literal:      (Visitor, ASTNumberLiteral) -> any?,
    enum:                (Visitor, ASTIdList) -> any?,
    array:               (Visitor, ASTArray) -> any?,
    periodic_array:      (Visitor, ASTPeriodicArray) -> any?,
    vector3:             (Visitor, ASTVector3) -> any?,
    size_specifier:      (Visitor, ASTSizeSpecifier) -> any?,
    binding:             (Visitor, ASTBinding) -> any?,
	map:                 (Visitor, ASTMap) -> any?,
	string:              (Visitor, ASTString) -> any?,
	struct:              (Visitor, ASTStruct) -> any?,

    TraverseChildren:    (Visitor, ASTNode) -> nil,
    Visit:               (Visitor, ASTNode) -> any?,
    CollectChildren:     (Visitor, ASTNode) -> any?,
}

local function print_desc(self: Visitor, desc)
    local out = ""
    for i = 1, self.indent, 1 do
        out ..= "\t"
    end

    print(out .. desc)
end

local PrintVisitor: Visitor = {
    indent = 0,
    root = function(self, node)
        print_desc(self, "root")
        self.indent += 1
        self:TraverseChildren(node)
        self.indent -= 1
    end,
    comment = function(self, node)
        print_desc(self, "comment: " .. node.Value)
    end,
    error = function(self, node)
        print_desc(self, "error: " .. node.Extra)
    end,
    error_with_children = function(self, node)
        print_desc(self, "error: " .. node.Extra)
        self.indent += 1
        self:TraverseChildren(node)
        self.indent -= 1
    end,
    type_literal = function(self, node)
        print_desc(self, "type: " .. node.Value)
    end,
    string_literal = function(self, node)
        print_desc(self, "string literal: " .. node.Value)
    end,
	number_literal = function(self, node)
		print_desc(self, "number literal: " .. node.Value .. " (" .. node.Extra .. ")")
	end,
	string = function(self, node)
		print_desc(self, "string")
	end,
    enum = function(self, node)
        local byte_size = bytes_to_store_value(#node.Value)
        print_desc(self, `enum: {#node.Value} ids -> {byte_size} bytes per id`)
        self.indent += 1
        self:TraverseChildren(node)
        self.indent -= 1
    end,
    array = function(self, node)
        print_desc(self, "array:")
        self.indent += 1
        self:TraverseChildren(node)
        self.indent -= 1
    end,
    periodic_array = function(self, node)
		print_desc(self, "periodic_array:")
        self.indent += 1
        self:TraverseChildren(node)
        self.indent -= 1
    end,
	map = function(self, node)
		print_desc(self, "map:")
        self.indent += 1
        self:TraverseChildren(node)
        self.indent -= 1
	end,
	struct = function(self, node)
		print_desc(self, "struct:")
		self.indent += 1
		self:TraverseChildren(node)
		self.indent -= 1
	end,
    vector3 = function(self, node)
        print_desc(self, "vector3:")
        self.indent += 1
        self:TraverseChildren(node)
        self.indent -= 1
    end,
    size_specifier = function(self, node)
        -- handled by parent
    end,
    binding = function(self, node)
        print_desc(self, "binding")
        self.indent += 1
        self:TraverseChildren(node)
        self.indent -= 1
    end,

    TraverseChildren = TraverseChildren,
    CollectChildren = CollectChildren,
    Visit = Visit
}


local ContainsErrors: Visitor = {
    root = function(self, node)
        return self:CollectChildren(node)
    end,
    comment = function(self, node)
        return nil
    end,
    error = function(self, node)
        return math.huge
    end,
    error_with_children = function(self, node)
        return math.huge
    end,
    type_literal = function(self, node)
        return nil
    end,
    string_literal = function(self, node)
        return nil
    end,
	number_literal = function(self, node)
		return nil
	end,
	string = function(self, node)
		return nil
	end,
    enum = function(self, node)
        return sum(self:CollectChildren(node))
    end,
    array = function(self, node)
        return sum(self:CollectChildren(node))
    end,
	map = function(self, node)
		return sum(self:CollectChildren(node))
	end,
	struct = function(self, node)
		return sum(self:CollectChildren(node))
	end,
    periodic_array = function(self, node)
        return sum(self:CollectChildren(node))
    end,
    vector3 = function(self, node)
        return sum(self:CollectChildren(node))
    end,
    size_specifier = function(self, node)
        return nil
    end,
    binding = function(self, node)
        return sum(self:CollectChildren(node))
    end,

    TraverseChildren = TraverseChildren,
    CollectChildren = CollectChildren,
    Visit = Visit
}

-- Calculates the byte size each argument to the serializer will take up
-- For variable size nodes, it will calculate the max size
local SizeCalcVisitor: Visitor = {
    root = function(self, node: ASTRoot)
        return self:CollectChildren(node)
    end,
    error = function(self, node: ASTError)
        return math.huge
    end,
    error_with_children = function(self, node: ASTErrorWChildren)
        -- for debugging we'll call children even though a math.huge would be fine
        return sum(self:CollectChildren(node))
    end,
    comment = function(self, node: ASTComment)
        return nil
    end,
    type_literal = function(self, node: ASTTypeLiteral)
        return type_literal_sizes[node.Value]
    end,
    size_specifier = function(self, node: ASTSizeSpecifier)
        return bytes_to_store_dynamic_size(node.Value)
    end,
    enum = function(self, node: ASTIdList)
        local children = self:CollectChildren(node)

        return function(t: { string })
			local encoded_len = bytes_to_store_dynamic_size(#t)
			local encoded_number_size = bytes_to_store_dynamic_size(#children)
            return #t * encoded_number_size + encoded_len
        end
    end,
    binding = function(self, node: ASTBinding)
        local children = self:CollectChildren(node)
		local lhs, rhs = children[1], children[2]

		if typeof(lhs) ~= "function" then
			assert(typeof(lhs) == "number")
		end
		if typeof(rhs) ~= "function" then
			assert(typeof(rhs) == "number")
		end

		return function(l, r)
			local ls, rs
			if typeof(lhs) == "number" then
				ls = lhs
			else
				ls = lhs(l)
			end
			if typeof(rhs) == "number" then
				rs = rhs
			else
				rs = rhs(l)
			end

			return ls + rs
		end
    end,
    string_literal = function(self, node: ASTStringLiteral)
		local len = string.len(node.Value)
        return bytes_to_store_dynamic_size(len) + len
    end,
	number_literal = function(self, node: ASTNumberLiteral)
		return type_literal_sizes[node.Extra]
	end,
	string = function(self, node: ASTString)
		return function(s: string)
			local len = string.len(s)
			return bytes_to_store_dynamic_size(len) + len
		end
	end,
    array = function(self, node: ASTArray)
        return sum(self:CollectChildren(node))
    end,
    periodic_array = function(self, node: ASTPeriodicArray)
        local child_sizes = self:CollectChildren(node)
        -- local size_padding = table.remove(child_sizes)
        local len_per_period = #child_sizes
        local size_per_period = sum(child_sizes)

        return function(t: { })
            -- TODO: this breaks if a child is not a type literal
            local periods = #t / len_per_period
            assert(periods %1 == 0)
            return periods * size_per_period + bytes_to_store_dynamic_size(periods)
        end
    end,
	map = function(self, node: ASTMap)
		local children = self:CollectChildren(node)
		local binding_calc = children[1]

		local f
		local lhs_type = node.Value[1].Value[1].Type
		if lhs_type == "string" then
			f = function(t: { })
				local s = bytes_to_store_dynamic_size(count_table_keys(t))
				for i,v in t do
					s += binding_calc(i, v)
				end
	
				return s
			end
		else
			f = function(t: { })
				local s = bytes_to_store_dynamic_size(#t)
				for i,v in t do
					s += binding_calc(i, v)
				end
	
				return s
			end
		end

		return f
	end,
	struct = function(self, node: ASTStruct)
		local children = self:CollectChildren(node)
		local struct_len = bytes_to_store_dynamic_size(#children)
		local ast_children = node.Value
		local child_map = { }
		for i,v in ast_children do
			local lhs = v.Value[1].Value
			child_map[lhs] = children[i]
		end

		local f = function(t: { })
			local s = struct_len
			for i,v in t do
				s += child_map[i](i, v)
			end

			return s
		end

		return f
	end,
    vector3 = function(self, node: ASTVector3)
        return sum(self:CollectChildren(node))
    end,
    TraverseChildren = TraverseChildren,
    CollectChildren = CollectChildren,
    Visit = Visit
}

-- Serialize/deserialize visitors assume the AST has not been mutated between each-others visits
-- The order of for..in loops needs to be the same for these visitors
-- While the order is undefined, it is consistent as long as the table being iterated is not mutated
local SerializeVisitor: Visitor = {
    root = function(self, node: ASTRoot)
        local arg_sizes = node:Accept(ContainsErrors)
        if sum(arg_sizes) == math.huge then
            return false
        end

        local sizes = node:Accept(SizeCalcVisitor)
        
        local procedures = self:CollectChildren(node)

        local function serialize_args(...)
            local args = { ... }
            local cursor = 0

            local buffer_size = 0
            for i,v in args do
                local size = sizes[i]
                if typeof(size) == "number" then
                    buffer_size += size
                else
                    buffer_size += size(v)
                end
            end

            local b = buffer.create(buffer_size)

            for i = 1, #args, 1 do
                local val = args[i]
                local written = procedures[i](val, b, cursor)

                cursor += written
            end

            return b
        end
        
        return serialize_args
    end,
    error = function(self, node: ASTError)
        return nil
    end,
    error_with_children = function(self, node: ASTErrorWChildren)
        return nil
    end,
    comment = function(self, node: ASTComment)
        return nil
    end,
    type_literal = function(self, node: ASTTypeLiteral)
        return writers[terminal_to_idx[node.Value]]
    end,
    string_literal = function(self, node: ASTStringLiteral)
		local str = node.Value
		return function(_, b: buffer, idx: number)
			local len = string.len(str)
			local s = write_size_specifier(len, b, idx)

			buffer.writestring(b, idx + s, str, len)

			return len + s
		end
    end,
	number_literal = function(self, node: ASTNumberLiteral)
		return writers[terminal_to_idx[node.Extra]]
	end,
	string = function(self, node: ASTString)
		return function(t: string, b: buffer, idx: number)
			local len = string.len(t)
			local s = write_size_specifier(len, b, idx)

			buffer.writestring(b, idx + s, t, len)

			return len + s
		end
	end,
    size_specifier = function(self, node: ASTSizeSpecifier)
        return raw_byte_writers[bytes_to_store_value(node.Value)]
    end,
    binding = function(self, node: ASTBinding)
        local children = self:CollectChildren(node)
        local lhs, rhs = children[1], children[2]
        return function(k, v, b: buffer, idx: number)
            local s = 0
            s += lhs(k, b, idx)
            s += rhs(v, b, idx + s)

            return s
        end
    end,
    enum = function(self, node: ASTIdList)
        local ast_children = node.Value
        local byte_writer = raw_byte_writers[bytes_to_store_value(#ast_children)]

        local str_to_num = table.create(#ast_children)
        for i,v in ast_children do
            str_to_num[v.Value] = i
        end

        local function f(t: { string }, b: buffer, idx: number)
            -- record the actual amount being written to the buffer
            local s = write_size_specifier(#t, b, idx)
            for i,v in t do
                s += byte_writer(str_to_num[v], b, idx + i)
            end

            return s
        end

        return f
    end,
    array = function(self, node: ASTArray)
        local fns = self:CollectChildren(node)

        local function f(t: { }, b: buffer, idx: number)
            local s = 0

            for i = 1, #t, 1 do
                s += fns[i](t[i], b, idx + s)
            end

            return s
        end

        return f
    end,
    periodic_array = function(self, node: ASTPeriodicArray)
        local fns = self:CollectChildren(node)
        local period = #fns

        local function f(t: { }, b: buffer, idx: number)
            local len = #t
            local s = write_size_specifier(len / period, b, idx)

            for i = 0, len / period, period do
                for j = 1, period, 1 do
                    s += fns[j](t[i + j], b, idx + s)
                end
            end

            return s
        end
        return f
    end,
	map = function(self, node: ASTMap)
		local children = self:CollectChildren(node)
		local writer = children[1]

		local f
		local lhs_type = node.Value[1].Value[1].Type
		if lhs_type == "string" then
			f = function(t: { }, b: buffer, idx: number)
				local len = count_table_keys(t)
				local s = write_size_specifier(len, b, idx)

				for i,v in t do
					s += writer(i, v, b, idx + s)
				end

				return s
			end
		else
			f = function(t: { }, b: buffer, idx: number)
				local s = write_size_specifier(#t, b, idx)

				for i = 1, #t, 2 do
					s += writer(t[i], t[i + 1], b, idx + s)
				end

				return s
			end
		end

		return f
	end,
	struct = function(self, node: ASTStruct)
		local children = self:CollectChildren(node)

		local ast_children = node.Value
		local child_map = { }
		for i,v in ast_children do
			local lhs = v.Value[1].Value
			child_map[lhs] = children[i]
		end

		local f = function(t: { }, b: buffer, idx: number)
			local s = 0
			for i,writer in child_map do
				s += writer(i, t[i], b, idx + s)
			end

			return s
		end

		return f
	end, 
    vector3 = function(self, node: ASTVector3)
        local fns = self:CollectChildren(node)
        
        local function f(v: Vector3, b: buffer, idx: number)
            local s = 0
            s += fns[1](v.X, b, idx + s)
            s += fns[2](v.Y, b, idx + s)
            s += fns[3](v.Z, b, idx + s)

            return s
        end
        
        return f
    end,
    
    TraverseChildren = TraverseChildren,
    CollectChildren = CollectChildren,
    Visit = Visit
}

local DeserializeVisitor: Visitor = {
    root = function(self, node: ASTRoot)
        local arg_sizes = node:Accept(ContainsErrors)
        if sum(arg_sizes) == math.huge then
            return false
        end
        
        local procedures = self:CollectChildren(node)
        local arg_ct = #arg_sizes

        local function deserialize_buf(b: buffer)
            local ret = table.create(arg_ct)
            local cursor = 0

            for i = 1, arg_ct, 1 do
                local val, read = procedures[i](b, cursor)
                table.insert(ret, val)
                
                cursor += read
            end

            return table.unpack(ret)
        end
        
        return deserialize_buf
    end,
    error = function(self, node: ASTError)
         return nil
    end,
    error_with_children = function(self, node: ASTErrorWChildren)
        return nil
    end,
    comment = function(self, node: ASTComment)
        return nil
    end,
    type_literal = function(self, node: ASTTypeLiteral)
        return readers[terminal_to_idx[node.Value]]
    end,
    string_literal = function(self, node: ASTStringLiteral)
        return function(b: buffer, idx: number)
			local bsize, s = read_size_specifier(b, idx)

			return buffer.readstring(b, idx + s, bsize), bsize + s
		end
    end,
	number_literal = function(self, node: ASTNumberLiteral)
		return readers[terminal_to_idx[node.Extra]]
	end,
	string = function(self, node: ASTString)
		return function(b: buffer, idx: number)
			local bsize, s = read_size_specifier(b, idx)

			return buffer.readstring(b, idx + s, bsize), bsize + s
		end
	end,
    size_specifier = function(self, node: ASTSizeSpecifier)
        return raw_byte_readers[bytes_to_store_value(node.Value)]
    end,
    enum = function(self, node: ASTIdList)
        -- also has a size_specifier as the last child
        local ast_children = node.Value
		local byte_size = bytes_to_store_value(#ast_children)
        local byte_reader = raw_byte_readers[byte_size]

        local num_to_str = table.create(#ast_children)
        for i,v in ast_children do
            num_to_str[i] = v.Value
        end

        local function f(b: buffer, idx: number)
            local byte_size = byte_size
            local len, s = read_size_specifier(b, idx)
            local ret = table.create(len)

			idx += s

            for i = 0, len - 1, 1 do
                local v, read = byte_reader(b, idx + (i * byte_size))
                table.insert(ret, num_to_str[v])
                s += read
            end

            return ret, s
        end

        return f
    end,
    array = function(self, node: ASTArray)
        local fns = self:CollectChildren(node)
        local len = #fns

        local function f(b: buffer, idx: number)
            local s = 0
            local t = table.create(len)

            for i = 1, len, 1 do
                local v, read = fns[i](b, idx + s)
                table.insert(t, v)
                s += read
            end

            return t, s
        end

        return f
    end,
    periodic_array = function(self, node: ASTPeriodicArray)
        local fns = self:CollectChildren(node)
        local len = #fns

        local function f(b: buffer, idx: number)
            local bsize, s = read_size_specifier(b, idx)
            local t = table.create(bsize)

            for i = 1, bsize, 1 do
                for j = 1, len, 1 do
                    local v, read = fns[j](b, idx + s)
                    table.insert(t, v)
                    s += read
                end
            end

            return t, s
        end
        
        return f 
    end,
	map = function(self, node: ASTMap)
		local fns = self:CollectChildren(node)
		local reader = fns[1]

		local function f(b: buffer, idx: number)
			local map_len, s = read_size_specifier(b, idx)
			local t = table.create(map_len)

			for i = 1, map_len, 1 do
				local l, r, read = reader(b, idx + s)
				s += read
				t[l] = r
			end

			return t, s
		end

		return f
	end,
	struct = function(self, node: ASTStruct)
		local children = self:CollectChildren(node)
		local struct_len = #children
		local ast_children = node.Value
		local child_map = { }
		for i,v in ast_children do
			local lhs = v.Value[1].Value
			child_map[lhs] = children[i]
		end

		local f = function(b: buffer, idx: number)
			local s = 0
			local ret = table.create(struct_len)
			for i, reader in child_map do
				local l, r, read = reader(b, idx + s)
				s += read
				ret[l] = r
			end

			return ret, s
		end

		return f
	end,
    vector3 = function(self, node: ASTVector3)
        local fns = self:CollectChildren(node)

        local function f(b: buffer, idx: number)
            local s = 0
            local x, s1 = fns[1](b, idx)
            s += s1
            local y, s2 = fns[2](b, idx + s)
            s += s2
            local z, s3 = fns[3](b, idx + s)

            return Vector3.new(x, y, z), s + s3
        end

        return f
    end,
	binding = function(self, node: ASTBinding)
        local children = self:CollectChildren(node)
        local lhs, rhs = children[1], children[2]
        return function(b: buffer, idx: number)
			local l, s = lhs(b, idx)
            local r, s2 = rhs(b, idx + s)

            return l, r, s + s2
        end
	end,
    
    TraverseChildren = TraverseChildren,
    CollectChildren = CollectChildren,
    Visit = Visit
}

local function str_to_ast(str)
    local tokens = Tokenizer(str)
    local ast = parse_token_stream(tokens)
    return ast
end

local function compile_serdes_str(str)
    local ast = str_to_ast(str)
    local serializer = ast:Accept(SerializeVisitor)
    local deserializer = ast:Accept(DeserializeVisitor)

    return serializer, deserializer, ast
end

local function pretty_compile(str)
    local s, d, ast = compile_serdes_str(str)
    return {
        Serialize = s,
        Deserialize = d,
        Ast = ast
    }
end

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
            "a": i8,
            "b": f64,
            "c": i8,
			1: array(i8, f32)
        )
    ]]
    local enum_str = [[
        enum("asd", "asdf", "asdfg")
    ]]

    local _, struct = pcall(function()
        return pretty_compile(struct_str)
    end)
	local _, map = pcall(function()
		return pretty_compile(map_str)
	end)
    local _, array = pcall(function()
        return pretty_compile(array_str)
    end)
    local _, p_array = pcall(function()
        return pretty_compile(periodic_array_str)
    end)
	local _, nested_array = pcall(function()
		return pretty_compile(nested_array_str)
	end)
    local _, enum = pcall(function()
        return pretty_compile(enum_str)
    end)

	T:Test("Size specifier", function()
		local min_size, max_size = 1, 2^30 - 1
		local buf1 = buffer.create(4)
		local buf2 = buffer.create(4)
		local buf3 = buffer.create(4)
		write_size_specifier(min_size, buf1, 0)
		write_size_specifier(63, buf1, 1)
		write_size_specifier(64, buf1, 2)
		write_size_specifier(max_size, buf2, 0)

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
		write_size_specifier(2^30-1, full_buf, 0)
		-- overwrite 2nd byte
		write_size_specifier(1, full_buf, 1)

		T:ForContext("written size",
			T.Equal, dump_bits(full_buf), "11111111 00000001 11111111 11111111"
		)

		T:ForContext("reading",
			T.Equal, read_size_specifier(buf1, 0), 1,
			T.Equal, read_size_specifier(buf1, 1), 63,
			T.Equal, read_size_specifier(buf1, 2), 64,
			T.Equal, read_size_specifier(buf2, 0), 2^30 - 1
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
    end)

    T:Test("Do the serdes junk", function()
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
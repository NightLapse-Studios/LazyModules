--!strict

--[[
    An embedded DSL for generating a pair of SerDes functions targeting buffers.
    The functions are suitable as middlewere for networking data to save on bandwidth or storage

    `
        "i8, vector3(f32, f64, f64), array(u8, u8, u8)"
            ->
        serializer function(a1: number a2: Vector3, a3: { number }) -> buffer
        deserialier function(b: buffer) -> tupple<number, Vector3, { number }>
    `

    Type literals:
        Corresponds to all the data types that buffers support
        i8, i16, i32, u8, u16, u32, f32, f64

    Table types:
        array:
            Fixed-size list of types
            array(u8, f32, f32) -> 9 bytes of storage + 1 byte of padding to specify the size
        list:
            Periodic list of types
            list(u8, f32, f32, max_size: 511) -> 9 bytes per period + 2 bytes to store the size
                byte storage size is based on the max_size
        id_list:
            List of strings that correspond to their index in the list
            id_list("abc", "def") -> 1 byte per string * number of strings supplied + 1 byte to specify size
                byte storage is based on the maximum index of id_list. 255 ids = 1 bytes; 256 = 2, etc...

    Constructor types:
        Can be used in place of a type literal, but will contain type literals
        vector3:
            vector3(u8, f32, f32) -> 9 bytes
]]

local LMT = require(game.ReplicatedFirst.Util.LMTypes)
local Config = require(game.ReplicatedFirst.Util.Config.Config)
local is_separator = require(script.Parent.is_separator)

local mod = { }

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


local terminals = {
    "i8",
    "i16",
    "i32",
    "u8",
    "u16",
    "u32",
    "f32",
    "f64",
}

local nonterminals = {
    "vector3",
    "list",
    "array",
    "dict"
}

local terminal_to_idx = table.create(#terminals)

for i,v in terminals do
    terminal_to_idx[v] = i
end

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
local function w_str(v: string, b: buffer, idx: number)
    buffer.writestring(b, idx, v)
    return string.len(v)
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
local raw_byte_writers = {
    [1] = w_u8,
    [2] = w_u16,
    [3] = w_u32,
    [4] = w_u32
}
local raw_byte_readers = {
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

local function bytes_to_store_value(n: number)
    -- number of bytes needed to store the node's value as a binary number
    -- 1 is added to value because max we can store in a byte is 255, not 256
    return math.max(math.ceil(math.log(n + 1, 2) / 8))
end




--[[
    AST from token stream
]]

local NodeConstructors

local function node_from_token(tokens, idx)
    local token = tokens[idx]

    if string.sub(token, 1, 1) == "#" then
        return NodeConstructors.comment(tokens, idx)
    end

    if token == "\"" then
        return NodeConstructors.string_literal(tokens, idx)
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

local function parse_binding(tokens: { string }, idx)
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

local function parse_binding_list(tokens: { string }, idx)
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
local function parse_chunk(tokens: { string }, idx)
    local token_ct = #tokens
    local consumed = 0
    local nodes = { }
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

local function new_node(type: string, value: unknown, index: number, tokens_consumed: number, extra: string?)
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

type ASTNode = typeof(new_node("" :: string, "" :: unknown, 1 :: number, 1 :: number))

function ASTNode:IsLiteral()
    return typeof(self.Value) == "string"
end

function ASTNode:Accept(visitor)
    return visitor:Visit(self)
end

-- Each function return the node and then the number of tokens it consumed
-- The parse function handles closing parenthesis but not opening ones since each of these
-- will be consuming tokens after the opening parenthesis

local _NodeConstructors: { ({ string }, idx: number, ...any) -> (ASTNode, number)} = {
    root = function(tokens: { string }, idx)
        local children, consumed = parse_chunk(tokens, 1)
        local node = new_node("root", children, 1, consumed)
        return node, consumed
    end,
    error = function(tokens: { string }, idx: number, err: string, size: number)
        local node = new_node("error", tokens[idx], idx, size, err)
        return node, size
    end,
    error_with_unparsed_children = function(tokens: { string }, idx: number, err: string)
        local children, consumed = parse_chunk(tokens, idx + 1)
        local consumed_total = consumed + 1
        local node, _ = NodeConstructors.error_with_children(tokens, idx, err, consumed_total, children)
        return node, consumed_total
    end,
    error_with_children = function(tokens: { string }, idx: number, err: string, token_size: number, children: { ASTNode })
        local node = new_node("error", children, idx, token_size, err)
        return node, token_size
    end,
    comment = function(tokens: { string }, idx: number)
        -- The entire comment is a single token
        local node = new_node("comment", tokens[idx], idx, 1)
        return node, 1
    end,
    type_literal = function(tokens: { string }, idx: number)
        local node = new_node("type_literal", tokens[idx], idx, 1)
        return node, 1
    end,
    string_literal = function(tokens: { string }, idx: number)
        return new_node("string_literal", tokens[idx + 1], idx, 3), 3
    end,
    id_list = function(tokens: { string }, idx: number)
        local children, consumed = parse_chunk(tokens, idx + 1)
        local consumed_total = consumed + 1

        for i,v in children do
            if v.Type ~= "string_literal" then
                local err, _ = NodeConstructors.error(tokens, idx, `Unexpected {v.Value}, id_list can only contain string literals`, v.TokenSize)
                children[i] = err
            end
        end

        table.insert(children, new_node("size_specifier", #children, -1, 0))

        return new_node("id_list", children, idx, consumed_total), consumed_total
    end,
    id_map = function(tokens: { string }, idx: number)
        local children, consumed = parse_binding_list(tokens, idx + 1)
        local consumed_total = consumed + 1

        return new_node("id_map", children, idx, consumed_total), consumed_total
    end,
    array = function(tokens: { string }, idx: number)
        local children, consumed = parse_chunk(tokens, idx + 1)
        local consumed_total = consumed + 1

        for i,v in children do
            if v.Type ~= "type_literal" then
                if v.Type ~= "error" then
                    local err, _ = NodeConstructors.error(tokens, idx, `Unexpected {v.Value}, array can only contain type literals`, v.TokenSize)
                    children[i] = err
                end
            end
        end

        return new_node("array", children, idx, consumed_total), consumed_total
    end,
    list = function(tokens: { string }, idx: number)
        local children, consumed = parse_chunk(tokens, idx + 1)
        local consumed_total = consumed + 1

        local size_specifier, size_specifier_idx
        for i,v in children do
            if v.Type == "size_specifier" then
                if size_specifier then
                    local err = NodeConstructors.error(tokens, idx, "More than one size specifier in list", consumed_total)
                    table.insert(children, err)
                    break
                end

                size_specifier = v
                size_specifier_idx = i
            end
        end

        if not size_specifier then
            local err = NodeConstructors.error(tokens, idx, "Missing size specifier (max_size: #) in list", consumed_total, children)
            table.insert(children, err)
        end

        -- Move the size specifier to be the last child
        table.remove(children, size_specifier_idx)
        table.insert(children, size_specifier)
        
        return new_node("list", children, idx, consumed_total), consumed_total
    end,
    vector3 = function(tokens: { string }, idx: number)
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
            return NodeConstructors.error(tokens, idx, "vector3 expects 3 type literals", consumed_total)
        end
        
        return new_node("vector3", children, idx, consumed_total), consumed_total
    end,
    size_specifier = function(tokens: { string }, idx: number)
        local seperator = tokens[idx + 1]
        local size = tonumber(tokens[idx + 2])

        if not is_separator(seperator) then
            return NodeConstructors.error(tokens, idx, "Missing seperator for size specifier", 2)
        end

        if not size then
            return NodeConstructors.error(tokens, idx, "Expected number for size specifier", 3)
        end
        
        return new_node("size_specifier", size, idx, 3), 3
    end,
    max_size = function(tokens: { string }, idx: number)
        return NodeConstructors.size_specifier(tokens, idx)
    end,
    binding = function(tokens: { string }, idx: number, children: { ASTNode }, token_size: number)
        return new_node("binding", children, idx, token_size), token_size
    end,
    i8= function(tokens: { string }, idx: number)
        return NodeConstructors.type_literal(tokens, idx)
    end,
    i16= function(tokens: { string }, idx: number)
        return NodeConstructors.type_literal(tokens, idx)
    end,
    i32= function(tokens: { string }, idx: number)
        return NodeConstructors.type_literal(tokens, idx)
    end,
    i64= function(tokens: { string }, idx: number)
        return NodeConstructors.type_literal(tokens, idx)
    end,
    u8= function(tokens: { string }, idx: number)
        return NodeConstructors.type_literal(tokens, idx)
    end,
    u16= function(tokens: { string }, idx: number)
        return NodeConstructors.type_literal(tokens, idx)
    end,
    u32= function(tokens: { string }, idx: number)
        return NodeConstructors.type_literal(tokens, idx)
    end,
    u64= function(tokens: { string }, idx: number)
        return NodeConstructors.type_literal(tokens, idx)
    end,
    f8= function(tokens: { string }, idx: number)
        return NodeConstructors.type_literal(tokens, idx)
    end,
    f16= function(tokens: { string }, idx: number)
        return NodeConstructors.type_literal(tokens, idx)
    end,
    f32= function(tokens: { string }, idx: number)
        return NodeConstructors.type_literal(tokens, idx)
    end,
    f64= function(tokens: { string }, idx: number)
        return NodeConstructors.type_literal(tokens, idx)
    end,
}

NodeConstructors = _NodeConstructors



--[[
    Visitors
]]

local Visitor = { }
Visitor.__index = Visitor

local function new_visitor()
    local visitor: { [string]: ((any, ASTNode) -> (any)) | false | any} = {
        root = false,
        error = false,
        error_with_children = false,
        comment = false,
        type_literal = false,
        indexer = false,
        list = false,
        vector3 = false,
    }

    setmetatable(visitor, Visitor)

    return visitor
end

function Visitor:Visit(node: ASTNode)
    local ty = node.Type
    local visit_fn = self[ty]
    return visit_fn(self, node)
end

function Visitor:TraverseChildren(node: ASTNode)
    local children = node.Value :: { ASTNode }
    local len = #children

    for i = 1, len, 1 do
        children[i]:Accept(self)
    end

    return true
end

function Visitor:CollectChildren(node: ASTNode)
    local children = node.Value :: { ASTNode }
    local len = #children
    local vals = table.create(len)

    for i = 1, len, 1 do
        -- Some weird encantation that lets a visitor be able to return any number of values without using tables
        -- E.G. the NodeSizeVisitor wants a linear list of node sizes
        local val = { children[i]:Accept(self) }
        for _, v in val do
            table.insert(vals, v)
        end
    end

    return vals
end

-- Self explanatory
local PrintVisitor = new_visitor()
do
    PrintVisitor.indent = 0
    local function print_desc(self, desc: string)
        local out = ""
        for i = 1, self.indent, 1 do
            out ..= "\t"
        end

        print(out .. desc)
    end
    PrintVisitor.root = function(self, node: ASTNode)
        print_desc(self, "root")
        self.indent += 1
        self:TraverseChildren(node)
        self.indent -= 1
    end
    PrintVisitor.error = function(self, node: ASTNode)
        print_desc(self, "error: " .. node.Extra)
    end
    PrintVisitor.error_with_children = function(self, node: ASTNode)
        print_desc(self, "error: " .. node.Extra)
        self.indent += 1
        self:TraverseChildren(node)
        self.indent -= 1
    end
    PrintVisitor.comment = function(self, node: ASTNode)
        print_desc(self, "comment: " .. node.Value)
    end
    PrintVisitor.type_literal = function(self, node: ASTNode)
        print_desc(self, "type: " .. node.Value)
    end
    PrintVisitor.string_literal = function(self, node: ASTNode)
        print_desc(self, "string: " .. node.Value)
    end
    PrintVisitor.size_specifier = function()
        -- handled by parent
    end
    PrintVisitor.indexer = function(self, node: ASTNode)
        print_desc(self, "indexer literal: " .. node.Value)
    end
    PrintVisitor.binding = function(self, node: ASTNode)
        print_desc(self, `binding`)
        self.indent += 1
        self:TraverseChildren(node)
        self.indent -= 1
    end
    PrintVisitor.id_map = function(self, node: ASTNode)
        print_desc(self, `id_map`)
        self.indent += 1
        self:TraverseChildren(node)
        self.indent -= 1
    end
    PrintVisitor.id_list = function(self, node: ASTNode)
        local size = node.Value[#node.Value].Value
        local byte_size = bytes_to_store_value(size)
        print_desc(self, `id_list: {size} ids -> {byte_size} bytes per id + {byte_size} padding`)
        self.indent += 1
        self:TraverseChildren(node)
        self.indent -= 1
    end
    PrintVisitor.array = function(self, node: ASTNode)
        print_desc(self, "array: ")
        self.indent += 1
        self:TraverseChildren(node)
        self.indent -= 1
    end
    PrintVisitor.list = function(self, node: ASTNode)
        local size = node.Value[#node.Value].Value
        local padding = bytes_to_store_value(size)
        -- size could be an error message
        print_desc(self, `list: max_size( {size} ) -> {padding} byte padding`)
        self.indent += 1
        self:TraverseChildren(node)
        self.indent -= 1
    end
    PrintVisitor.vector3 = function(self, node: ASTNode)
        print_desc(self, "vector3: ")
        self.indent += 1
        self:TraverseChildren(node)
        self.indent -= 1
    end
end

-- Calculates the byte size each argument to the serializer will take up
-- For variable size nodes, it will calculate the max size
local ArgSizeVisitor = new_visitor()
do 
    ArgSizeVisitor.root = function(self, node: ASTNode)
        return self:CollectChildren(node)
    end
    ArgSizeVisitor.error = function(self, node: ASTNode)
        return math.huge
    end
    ArgSizeVisitor.error_with_children = function(self, node: ASTNode)
        return sum(self:CollectChildren(node))
    end
    ArgSizeVisitor.comment = function(self, node: ASTNode)
        return nil
    end
    ArgSizeVisitor.type_literal = function(self, node: ASTNode)
        return type_literal_sizes[node.Value]
    end
    ArgSizeVisitor.string_literal = function(self, node: ASTNode)
        return string.len(node.Value)
    end
    ArgSizeVisitor.size_specifier = function(self, node: ASTNode)
        return bytes_to_store_value(node.Value)
    end
    ArgSizeVisitor.indexer = function(self, node: ASTNode)
        return string.len(node.Value)
    end
    ArgSizeVisitor.id_list = function(self, node: ASTNode)
        local children = self:CollectChildren(node)
        local byte_size = children[#children]
        return #children * byte_size
    end
    ArgSizeVisitor.string_literal = function(self, node: ASTNode)
        return string.len(node.Value)
    end
    ArgSizeVisitor.list = function(self, node: ASTNode)
        return sum(self:CollectChildren(node))
    end
    ArgSizeVisitor.array = function(self, node: ASTNode)
        return sum(self:CollectChildren(node))
    end
    ArgSizeVisitor.list = function(self, node: ASTNode)
        local child_sizes = self:CollectChildren(node)
        local size_padding = child_sizes[#child_sizes]
        return size_padding + sum(self:CollectChildren(node))
    end
    ArgSizeVisitor.vector3 = function(self, node: ASTNode)
        return sum(self:CollectChildren(node))
    end
end

local SizeCalcVisitor = new_visitor()
do
    SizeCalcVisitor.root = function(self, node: ASTNode)
        return self:CollectChildren(node)
    end
    SizeCalcVisitor.error = function(self, node: ASTNode)
        return math.huge
    end
    SizeCalcVisitor.error_with_children = function(self, node: ASTNode)
        return sum(self:CollectChildren(node))
    end
    SizeCalcVisitor.comment = function(self, node: ASTNode)
        return nil
    end
    SizeCalcVisitor.type_literal = function(self, node: ASTNode)
        return type_literal_sizes[node.Value]
    end
    SizeCalcVisitor.string_literal = function(self, node: ASTNode)
        return string.len(node.Value)
    end
    SizeCalcVisitor.size_specifier = function(self, node: ASTNode)
        return bytes_to_store_value(node.Value)
    end
    SizeCalcVisitor.indexer = function(self, node: ASTNode)
        return string.len(node.Value)
    end
    SizeCalcVisitor.id_list = function(self, node: ASTNode)
        local children = self:CollectChildren(node)
        local byte_size = children[#children]
        return function(t: { string })
            return #t * byte_size + byte_size
        end
    end
    SizeCalcVisitor.string_literal = function(self, node: ASTNode)
        return string.len(node.Value)
    end
    SizeCalcVisitor.array = function(self, node: ASTNode)
        return sum(self:CollectChildren(node))
    end
    SizeCalcVisitor.list = function(self, node: ASTNode)
        local child_sizes = self:CollectChildren(node)
        local size_padding = table.remove(child_sizes)
        local len_per_period = #child_sizes
        local size_per_period = sum(child_sizes)
        return function(t: { })
            -- TODO: this breaks if a child is not a type literal
            local periods = #t / len_per_period
            assert(periods %1 == 0)
            return periods * size_per_period + size_padding
        end
    end
    SizeCalcVisitor.vector3 = function(self, node: ASTNode)
        return sum(self:CollectChildren(node))
    end
end

local SerializeVisitor = new_visitor()
do
    SerializeVisitor.root = function(self, node: ASTNode)
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
    end
    SerializeVisitor.error = function(self, node: ASTNode)
        return nil
    end
    SerializeVisitor.error_with_children = function(self, node: ASTNode)
        return nil
    end
    SerializeVisitor.comment = function(self, node: ASTNode)
        return nil
    end
    SerializeVisitor.type_literal = function(self, node: ASTNode)
        return writers[terminal_to_idx[node.Value]]
    end
    SerializeVisitor.string_literal = function(self, node: ASTNode)
        return node.Value
    end
    SerializeVisitor.size_specifier = function(self, node: ASTNode)
        return raw_byte_writers[bytes_to_store_value(node.Value)]
    end
    SerializeVisitor.indexer = function(self, node: ASTNode)
        return writers[terminal_to_idx.indexer]
    end
    SerializeVisitor.id_list = function(self, node: ASTNode)
        -- also has a size_specifier as the last child
        local str_array = self:CollectChildren(node)
        local byte_writer = table.remove(str_array)

        local strs = table.create(#str_array)
        for i,v in str_array do
            strs[v] = i
        end

        local function f(t: { string }, b: buffer, idx: number)
            -- record the actual amount being written to the buffer
            local s = byte_writer(#t, b, idx)
            for i,v in t do
                s += byte_writer(strs[v], b, idx + i)
            end

            return s
        end

        return f
    end
    SerializeVisitor.array = function(self, node: ASTNode)
        local fns = self:CollectChildren(node)
        local len = #fns

        local function f(t: { }, b: buffer, idx: number)
            local s = 0

            for i = 1, #t, 1 do
                s += fns[i](t[i], b, idx + s)
            end

            return s
        end

        return f
    end
    SerializeVisitor.list = function(self, node: ASTNode)
        local fns = self:CollectChildren(node)
        local write_size = table.remove(fns)
        local period = #fns

        local function f(t: { }, b: buffer, idx: number)
            local len = #t
            local s = write_size(len, b, idx)

            for i = 0, len / period, period do
                for j = 1, period, 1 do
                    s += fns[j](t[i + j], b, idx + s)
                end
            end

            return s
        end
        return f
    end
    SerializeVisitor.vector3 = function(self, node: ASTNode)
        local fns = self:CollectChildren(node)
        
        local function f(v: Vector3, b: buffer, idx: number)
            local s = 0
            s += fns[1](v.X, b, idx + s)
            s += fns[2](v.Y, b, idx + s)
            s += fns[3](v.Z, b, idx + s)

            return s
        end
        
        return f
    end
end

local DeserializeVisitor = new_visitor()
do
    DeserializeVisitor.root = function(self, node: ASTNode)
        local arg_sizes = node:Accept(ArgSizeVisitor)
        if sum(arg_sizes) == math.huge then
            warn("Serialization structure has errors")
            return
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
    end
    DeserializeVisitor.error = function(self, node: ASTNode)
         return nil
    end
    DeserializeVisitor.error_with_children = function(self, node: ASTNode)
        return nil
    end
    DeserializeVisitor.comment = function(self, node: ASTNode)
        return nil
    end
    DeserializeVisitor.type_literal = function(self, node: ASTNode)
        return readers[terminal_to_idx[node.Value]]
    end
    DeserializeVisitor.string_literal = function(self, node: ASTNode)
        return node.Value
    end
    DeserializeVisitor.size_specifier = function(self, node: ASTNode)
        return raw_byte_readers[bytes_to_store_value(node.Value)]
    end
    DeserializeVisitor.indexer = function(self, node: ASTNode)
        return readers[terminal_to_idx.indexer]
    end
    DeserializeVisitor.id_list = function(self, node: ASTNode)
        -- also has a size_specifier as the last child
        local str_array = self:CollectChildren(node)
        local byte_reader = table.remove(str_array)

        local function f(b: buffer, idx: number)
            local len, s = byte_reader(b, idx)
            local ret = table.create(len)
            local byte_size = s

            for i = 1, len, 1 do
                local v, read = byte_reader(b, idx + (i * byte_size))
                table.insert(ret, str_array[v])
                s += read
            end

            return ret, s
        end

        return f
    end
    DeserializeVisitor.array = function(self, node: ASTNode)
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
    end
    DeserializeVisitor.list = function(self, node: ASTNode)
        local fns = self:CollectChildren(node)
        local read_size = table.remove(fns)
        local len = #fns

        local function f(b: buffer, idx: number)
            local bsize, s = read_size(b, idx)
            local t = table.create(bsize)

            for i = 0, bsize - len, len do
                for j = 1, len, 1 do
                    local v, read = fns[j](b, idx + s)
                    table.insert(t, v)
                    s += read
                end
            end

            return t, s
        end
        
        return f 
    end
    DeserializeVisitor.vector3 = function(self, node: ASTNode)
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
    end
end

local function str_to_ast(str)
    local tokens = tokenize(str)
    local ast = parse_token_stream(tokens)
    return ast
end

local function compile_serdes_str(str)
    local ast = str_to_ast(str)
    ast:Accept(PrintVisitor)
    local serializer = ast:Accept(SerializeVisitor)
    local deserializer = ast:Accept(DeserializeVisitor)

    return serializer, deserializer, ast
end

local LMT = require(game.ReplicatedFirst.Util.LMTypes)
function mod.__init(G: LMT.LMGame, T: LMT.Tester)
    local test_1 = [[
    table(
        # test
        number: vector3(i8,f32,f16),
        string:i16,
        string: i32,
        vector99(i8, i8, i8)
    )

    ]]
    
    local test_2 = [[
        table(
            [1]: i8,
            number: vector3(i8,f32,f16),
            string: i8,
            [beans]: f16
        )
    ]]

    local test_3 = [[
        i8,i8,
        table(
            vector3(i8,i8,i8),
            vector3(i8,i8,i8)
        ),
        vector3(i8),
        table(
            i8,
            i16,
            i32,
            u8,
            u16,
            u32,
            f32,
            f64
        )
    ]]

    local trialing_comma_test = [[
        table(
            i8,
            i16,
        )
    ]]

    local table_ideas = [[
        array(
            i8
        ),
        table(
            [string]: i8
        ),
        table(
            [vector3(i8, i8, i8)]: i8
        )
    ]]

    local nesteds_test = [[
        f32,
        list(max_size: 256, i8, f64),
        # listt(max_size: 128, i8, f32),
        vector3(i8, i16, u32)
    ]]

    local nested_list_test = [[
        list(
            list(i8, i8, i8)
        )
    ]]

    local id_list = [[
        array(u8, u8, u8)
        id_list(
            "",
            "a a",
            "b",
            "c"
        )
    ]]

    local basic_test = [[
            vector3(i8, i16, u32),
            array(
                @periodic(max=32),
                i8, f32
            ),
            array(
                f32, i8
            ),
            id_list(
                # May c
                @sparse,
                "",
                "a a",
                "b",
                "c"
            ),
            id_map(
                # May not be missing fields
                @dense,
                "stat1": u8,
                "stat2": "asdf",
                "stat3": f32
            )
    ]]

    local serializer, deserializer, ast2 = compile_serdes_str(basic_test)
    local ser2 = serializer(
        Vector3.new(1, 2, 3),
        { 2, 2.35, 9, 9.2 },
        { 1, 1, 1 },
        { "a a", "b" }
    )
    print(deserializer(ser2))

    -- local s1, d1, ast1 = compile_serdes_str(nesteds_test)
    -- ast1:Accept(PrintVisitor)
    -- local serial = s1(1, {2, 3}, Vector3.new(4, 5, 6))
    -- print(d1(serial))


    -- local s3, d3, ast3 = compile_serdes_str(nested_list_test)
    -- local ser3 = s3({ {1, 3, 3}, {4, 5, 6}, {7, 8, 9}})
    -- print(d3(ser3))
end


return mod
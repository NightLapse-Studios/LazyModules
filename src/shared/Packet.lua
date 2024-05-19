--!strict


local LMT = require(game.ReplicatedFirst.Util.LMTypes)
local Config = require(game.ReplicatedFirst.Util.Config.Config)

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
local function w_str(v: string, b: buffer, idx: number, fn_idx: number, args: { any })
    buffer.writestring(b, idx, v)
    local len = args[fn_idx]
    return len
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
    Tokenizer
]]

local function is_separator(c: string)
    if c == "(" or c == ")" or c == "," or c == ":" or c == "[" or c == "]" then
        return true
    end

    return false
end

local function is_whitespace(c: string)
    if c == " " or c == "\t" or c == "\n" then
        return true
    end

    return false
end

local function get_token(str: string, idx: number)
    -- Find the first non-white-space character
    local start_idx = idx
    while true do
        local c = string.sub(str, start_idx, start_idx)
        if is_whitespace(c) then
            start_idx += 1
        elseif is_separator(c) then
            -- if it's a separator, the beginning is the end
            return c, start_idx
        else
            break
        end
    end

    local end_idx = start_idx

    if string.sub(str, end_idx, end_idx) == "#" then
        -- Handle comments
        repeat
            end_idx += 1
        until string.sub(str, end_idx, end_idx) == "\n"
    else
        -- if we get here, we have a word-ey thing
        while true do
            local c = string.sub(str, end_idx, end_idx)
            if c == "" then
                break
            elseif is_separator(c) or is_whitespace(c) then
                break
            end

            end_idx += 1
        end
    end

    end_idx -= 1

    local word = string.sub(str, start_idx, end_idx)
    return word, end_idx
end

local function tokenize(str: string)
    local tokens = { }
    local idx = 1
    while true do
        local token, end_idx = get_token(str, idx)
        idx = end_idx + 1
        if token == "" then
            break
        end

        table.insert(tokens, token)
    end

    return tokens
end



--[[
    AST from token stream
]]

local NodeConstructors
local parse_chunk

local function node_from_token(tokens, idx)
    local token = tokens[idx]
    local prev = tokens[idx - 1]

    if prev == "[" then
        return NodeConstructors.indexer(tokens, idx)
    end

    if string.sub(token, 1, 1) == "#" then
        return NodeConstructors.comment(tokens, idx)
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

function parse_chunk(tokens: { string }, idx)
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
        return node, 0
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
    indexer = function(tokens: { string }, idx: number)
        local node = new_node("indexer", tokens[idx], idx, 3)
        return node, 3
    end,
    array = function(tokens: { string }, idx: number)
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
    PrintVisitor.size_specifier = function()
        -- handled by parent
    end
    PrintVisitor.indexer = function(self, node: ASTNode)
        print_desc(self, "indexer literal: " .. node.Value)
    end
    PrintVisitor.list = function(self, node: ASTNode)
        local size = node.Value[#node.Value].Value
        -- size could be an error message
        print_desc(self, `list: max_size( {size} )`)
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
local ArgSizeVisitor = new_visitor()
do 
    ArgSizeVisitor.root = function(self, node: ASTNode)
        local sizes = self:CollectChildren(node)

        local arg_sizes = { }
        for i = 1, #sizes, 1 do
            arg_sizes[i] = sizes[i]
        end

        return arg_sizes
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
    ArgSizeVisitor.size_specifier = function(self, node: ASTNode)
        return bytes_to_store_value(node.Value)
    end
    ArgSizeVisitor.indexer = function(self, node: ASTNode)
        return string.len(node.Value)
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

-- Calculates a linear list of sizes of each node. The sum of this will equal the sum of the ArgSizeVisitor
local NodeSizeVisitor = new_visitor()
do 
    NodeSizeVisitor.root = function(self, node: ASTNode)
        local sizes = self:CollectChildren(node)

        return table.clone(sizes)
    end
    NodeSizeVisitor.error = function(self, node: ASTNode)
        return math.huge
    end
    NodeSizeVisitor.error_with_children = function(self, node: ASTNode)
        return table.unpack(self:CollectChildren(node))
    end
    NodeSizeVisitor.comment = function(self, node: ASTNode)
        return nil
    end
    NodeSizeVisitor.type_literal = function(self, node: ASTNode)
        return type_literal_sizes[node.Value]
    end
    ArgSizeVisitor.size_specifier = function(self, node: ASTNode)
        return bytes_to_store_value(node.Value)
    end
    NodeSizeVisitor.indexer = function(self, node: ASTNode)
        return string.len(node.Value)
    end
    NodeSizeVisitor.list = function(self, node: ASTNode)
        return table.unpack(self:CollectChildren(node))
    end
    NodeSizeVisitor.vector3 = function(self, node: ASTNode)
        return table.unpack(self:CollectChildren(node))
    end
end

local SerializeVisitor = new_visitor()
do
    SerializeVisitor.root = function(self, node: ASTNode)
        local sizes = node:Accept(ArgSizeVisitor)
        local procedures = self:CollectChildren(node)

        local buffer_size = sum(sizes)

        if buffer_size == math.huge then
            warn("Serialization structure has errors")
            return
        end


        local function serialize_args(...)
            local args = { ... }
            local cursor = 0
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
    SerializeVisitor.size_specifier = function(self, node: ASTNode)
        local bytes = bytes_to_store_value(node.Value)
        return raw_byte_writers[bytes_to_store_value(node.Value)]
    end
    SerializeVisitor.indexer = function(self, node: ASTNode)
        return writers[terminal_to_idx.indexer]
    end
    SerializeVisitor.list = function(self, node: ASTNode)
        local fns = self:CollectChildren(node)
        local write_size = table.remove(fns)
        local len = #fns

        local f = function(t: { }, b: buffer, idx: number)
            local s = write_size(len, b, idx)

            for i = 0, #t - 1, len do
                for j = 1, len, 1 do
                    s += fns[j](t[i + j], b, idx + s)
                end
            end

            return s
        end
        return f
    end
    SerializeVisitor.vector3 = function(self, node: ASTNode)
        local fns = self:CollectChildren(node)
        local f = function(v: Vector3, b: buffer, idx: number)
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
        local procedures = self:CollectChildren(node)

        local arg_ct = #arg_sizes

        if sum(arg_sizes) == math.huge then
            warn("Serialization structure has errors")
            return
        end

        local function deserialize_buf(b: buffer)
            local ret = table.create(arg_ct)
            local cursor = 0
            local size = buffer.len(b)

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
    DeserializeVisitor.size_specifier = function(self, node: ASTNode)
        return raw_byte_readers[bytes_to_store_value(node.Value)]
    end
    DeserializeVisitor.indexer = function(self, node: ASTNode)
        return readers[terminal_to_idx.indexer]
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
        local f = function(b: buffer, idx: number)
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

    local basic_test = [[
            i8,
            i16,
            i32,
            u8,
            u16,
            u32,
            f32,
            f64,
            vector3(i8, i16, u32),
            list(
                max_size: 32,
                i8, f64,
            )
    ]]

    -- local serializer, deserializer, ast2 = compile_serdes_str(basic_test)
    -- local ser2 = serializer(1, 2, 3, 4, 5, 6, 7, 8, Vector3.new(9, 10, 11), {12, 13})
    -- print(deserializer(ser2))

    local s1, d1, ast1 = compile_serdes_str(nesteds_test)
    ast1:Accept(PrintVisitor)
    local serial = s1(1, {2, 3}, Vector3.new(4, 5, 6))
    print(d1(serial))


    local s3, d3, ast3 = compile_serdes_str(nested_list_test)
    local ser3 = s3({ {1, 3, 3}, {4, 5, 6}, {7, 8, 9}})
    print(d3(ser3))
end


return mod
--!strict


local LMT = require(game.ReplicatedFirst.Util.LMTypes)
local Config = require(game.ReplicatedFirst.Util.Config.Config)

local mod = { }

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
        return NodeConstructors.specific_index(tokens, idx)
    end

    if string.sub(token, 1, 1) == "#" then
        return NodeConstructors.comment(tokens, idx)
    end

    local node_ctor = NodeConstructors[token]

    if not node_ctor then
        if tokens[idx + 1] == "(" then
            return NodeConstructors.error_with_children(tokens, idx, `Unrecognized type identifier {token}`)
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

function ASTNode:IsLiteral()
    return typeof(self.Value) == "string"
end

function ASTNode:Accept(visitor)
    return visitor:Visit(self)
end

function ASTNode:Print(depth: number?)
    depth = depth or 0

    local out = ""
    for i = 1, depth, 1 do
        out ..= "\t"
    end

    out ..= self.Type
    if self:IsLiteral() then
        if self.Type == "error" then
            out ..= ": " .. self.Extra
            print(out)
        else
            out ..= " : " .. self.Value
            print(out)
        end
    else
        if self.Type == "error" then
            out ..= ": " .. self.Extra
            print(out)
        else
            print(out)
        end

        for i,v in self.Value do
            v:Print(depth + 1)
        end
    end
end

local function new_node(type: string, value: unknown, index: number, size: number, extra: string?)
    local node = {
        Type = type,
        Value = value,
        Index = index,
        TokenSize = size,
        Extra = extra or false,
    }

    setmetatable(node, ASTNode)

    return node
end

type ASTNode = typeof(new_node("" :: string, "" :: unknown, 1 :: number, 1 :: number))

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
    error_with_children = function(tokens: { string }, idx: number, err: string)
        local children, consumed = parse_chunk(tokens, idx + 1)
        local consumed_total = consumed + 1
        local node = new_node("error", children, idx, consumed_total, err)
        return node, consumed_total
    end,
    comment = function(tokens: { string }, idx: number)
        -- The entire comment is a single token
        local node = new_node("comment", tokens[idx], idx, 1)
        return node, 1
    end,
    literal = function(tokens: { string }, idx: number)
        local node = new_node("literal", tokens[idx], idx, 1)
        return node, 1
    end,
    specific_index = function(tokens: { string }, idx: number)
        local node = new_node("specific_index", tokens[idx], idx, 3)
        return node, 3
    end,
    table = function(tokens: { string }, idx: number)
        local children, consumed = parse_chunk(tokens, idx + 1)
        local consumed_total = consumed + 1
        local node = new_node("table", children, idx, consumed_total)
        return node, consumed_total
    end,
    vector3 = function(tokens: { string }, idx: number)
        local children, consumed = parse_chunk(tokens, idx + 1)
        local consumed_total = consumed + 1
        local node = new_node("vector3", children, idx, consumed_total)
        return node, consumed_total
    end,
    i8= function(tokens: { string }, idx: number)
        return NodeConstructors.literal(tokens, idx)
    end,
    i16= function(tokens: { string }, idx: number)
        return NodeConstructors.literal(tokens, idx)
    end,
    i32= function(tokens: { string }, idx: number)
        return NodeConstructors.literal(tokens, idx)
    end,
    i64= function(tokens: { string }, idx: number)
        return NodeConstructors.literal(tokens, idx)
    end,
    u8= function(tokens: { string }, idx: number)
        return NodeConstructors.literal(tokens, idx)
    end,
    u16= function(tokens: { string }, idx: number)
        return NodeConstructors.literal(tokens, idx)
    end,
    u32= function(tokens: { string }, idx: number)
        return NodeConstructors.literal(tokens, idx)
    end,
    u64= function(tokens: { string }, idx: number)
        return NodeConstructors.literal(tokens, idx)
    end,
    f8= function(tokens: { string }, idx: number)
        return NodeConstructors.literal(tokens, idx)
    end,
    f16= function(tokens: { string }, idx: number)
        return NodeConstructors.literal(tokens, idx)
    end,
    f32= function(tokens: { string }, idx: number)
        return NodeConstructors.literal(tokens, idx)
    end,
    f64= function(tokens: { string }, idx: number)
        return NodeConstructors.literal(tokens, idx)
    end,
}

NodeConstructors = _NodeConstructors





local Visitor = { }
Visitor.__index = Visitor

local function new_visitor()
    local visitor: { [string]: ((any, ASTNode) -> (any)) | false | any} = {
        root = false,
        error = false,
        error_with_children = false,
        comment = false,
        literal = false,
        specific_index = false,
        table = false,
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
    PrintVisitor.literal = function(self, node: ASTNode)
        print_desc(self, "type: " .. node.Value)
    end
    PrintVisitor.specific_index = function(self, node: ASTNode)
        print_desc(self, "indexer literal: " .. node.Value)
    end
    PrintVisitor.table = function(self, node: ASTNode)
        print_desc(self, "table: ")
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

local literal_sizes = {
    i8 = 1,
    i16 = 2,
    i32 = 4,
    u8 = 1,
    u16 = 2,
    u32 = 4,
    f32 = 4,
    f64 = 8,
}

local index_to_type = {
    "i8",
    "i16",
    "i32",
    "u8",
    "u16",
    "u32",
    "f32",
    "f64",
    "table",
    "vector3",
    "specific_index"
}

local type_to_index = table.create(#index_to_type)

for i,v in index_to_type do
    type_to_index[v] = i
end

local function sum(t: { number })
    local s = 0
    for i,v in t do
        s += v
    end

    return s
end

local ArgSizeVisitor = new_visitor()
do 
    ArgSizeVisitor.root = function(self, node: ASTNode)
        print("Calculating sizes")
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
        return 0
    end
    ArgSizeVisitor.literal = function(self, node: ASTNode)
        return literal_sizes[node.Value]
    end
    ArgSizeVisitor.specific_index = function(self, node: ASTNode)
        return string.len(node.Value)
    end
    ArgSizeVisitor.table = function(self, node: ASTNode)
        return sum(self:CollectChildren(node))
    end
    ArgSizeVisitor.vector3 = function(self, node: ASTNode)
        return sum(self:CollectChildren(node))
    end
end

local NodeSizeVisitor = new_visitor()
do 
    NodeSizeVisitor.root = function(self, node: ASTNode)
        print("Calculating sizes")
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
    NodeSizeVisitor.literal = function(self, node: ASTNode)
        if node.Value == "vector3" then
            print()
            end
        return literal_sizes[node.Value]
    end
    NodeSizeVisitor.specific_index = function(self, node: ASTNode)
        return string.len(node.Value)
    end
    NodeSizeVisitor.table = function(self, node: ASTNode)
        return table.unpack(self:CollectChildren(node))
    end
    NodeSizeVisitor.vector3 = function(self, node: ASTNode)
        return table.unpack(self:CollectChildren(node))
    end
end

local SerializeVisitor = new_visitor()
do
    SerializeVisitor.fn_order = { }
    SerializeVisitor.root = function(self, node: ASTNode)
        print("Beginning serializer")
        
        SerializeVisitor.fn_order = { }
        local children_sers = self:TraverseChildren(node)

        local sizes = node:Accept(NodeSizeVisitor)
        local fn_orders = self:CollectChildren(node)

        local function i8(v: number, b: buffer, idx: number)
            buffer.writei8(b, idx, v)
            return 1, 0
        end
        local function i16(v: number, b: buffer, idx: number)
            buffer.writei16(b, idx, v)
            return 2, 0
        end
        local function i32(v: number, b: buffer, idx: number)
            buffer.writei32(b, idx, v)
            return 4, 0
        end
        local function u8(v: number, b: buffer, idx: number)
            buffer.writeu8(b, idx, v)
            return 1, 0
        end
        local function u16(v: number, b: buffer, idx: number)
            buffer.writeu16(b, idx, v)
            return 2, 0
        end
        local function u32(v: number, b: buffer, idx: number)
            buffer.writeu32(b, idx, v)
            return 4, 0
        end
        local function f32(v: number, b: buffer, idx: number)
            buffer.writef32(b, idx, v)
            return 4, 0
        end
        local function f64(v: number, b: buffer, idx: number)
            buffer.writef64(b, idx, v)
            return 8, 0
        end


        local writers

        local function vector3(v: Vector3, b: buffer, idx: number, fn_idx: number)
            local s = 0
            s += writers[fn_idx + 1](v.X, b, idx)
            s += writers[fn_idx + 2](v.Y, b, idx + s)
            s += writers[fn_idx + 3](v.Z, b, idx + s)

            return s, 3
        end

        writers = {
            i8, i16, i32, u8, u16, u32, f32, f64, --[[table]] false, vector3, false
        }

        local function serialize_args(...)
            local args = { ... }
            local cursor = 0
            local fn_cursor = 1
            local b = buffer.create(sum(sizes))
            for i = 1, #args, 1 do
                local val = args[i]
                local fn_order = fn_orders[i]
                local written, fn_orders_consumed = writers[fn_order](val, b, cursor, fn_cursor)

                if fn_orders_consumed then
                    fn_cursor += fn_orders_consumed
                end
                
                fn_cursor += 1
                cursor += written
            end
        end
        
        return serialize_args
    end
    SerializeVisitor.error = function(self, node: ASTNode)
        return nil
    end
    SerializeVisitor.error_with_children = function(self, node: ASTNode)
        return table.unpack(self:CollectChildren(node))
    end
    SerializeVisitor.comment = function(self, node: ASTNode)
        return nil
    end
    SerializeVisitor.literal = function(self, node: ASTNode)
        return type_to_index[node.Value]
    end
    SerializeVisitor.specific_index = function(self, node: ASTNode)
        return type_to_index.specific_index
    end
    SerializeVisitor.table = function(self, node: ASTNode)
        return table.unpack(self:CollectChildren(node))
    end
    SerializeVisitor.vector3 = function(self, node: ASTNode)
        return table.unpack(self:CollectChildren(node))
    end
end





-- function mod.__tests(G: LMT.LMGame, T: LMT.Tester)
--     local tokens = parse(t)
--     print(tokens)
-- end

local function str_to_ast(str)
    local tokens = tokenize(str)
    local ast = parse_token_stream(tokens)
    return ast
end

function mod.__init(G)
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
            f64
    ]]

    --serialize
    local function a()

    end
    
    warn("DOING IT")
    local ast1 = str_to_ast(basic_test)
    ast1:Accept(PrintVisitor)
    -- ast1:Accept(NodeSizeVisitor)
    local serializer = ast1:Accept(SerializeVisitor)
    local serial = serializer(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
    print()
    -- local sizes = ast1:Accept(SizeVisitor)
    -- str_to_ast(trialing_comma_test):Accept(PrintVisitor)
    -- str_to_ast(test_2):Accept(PrintVisitor)
    -- print("Parsing", t)
    -- for i,v in tokens do
    --     print(i, v)
    -- end
    -- print(tokens)
end


return mod
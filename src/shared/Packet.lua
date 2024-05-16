--!strict


local LMT = require(game.ReplicatedFirst.Util.LMTypes)
local Config = require(game.ReplicatedFirst.Util.Config.Config)

local mod = { }

local Separators = {
    ["("] = true,
    [")"] = true,
    [","] = true
}

local function is_separator(c: string)
    if c == "(" or c == ")" or c == "," or c == ":" then
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

    -- if we get here, we have a word-ey thing
    local end_idx = start_idx
    while true do
        local c = string.sub(str, end_idx, end_idx)
        if c == "" then
            break
        elseif is_separator(c) or is_whitespace(c) then
            break
        end

        end_idx += 1
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


local NodeConstructors

local parse_chunk
local function node_from_token(tokens, idx)
    local token = tokens[idx]
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
    literal = function(tokens: { string }, idx: number)
        local node = new_node("literal", tokens[idx], idx, 1)
        return node, 1
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
    i8 = function(tokens: { string }, idx: number)
        return NodeConstructors.literal(tokens, idx)
    end
}

NodeConstructors = _NodeConstructors


-- local Serializers = {
--     table = function(period: number, ...)
--         return function(t: { unknown })
--             -- for i
--         end
--     end,
--     i8 = function()
-- }

local AST = {
    ToSerializer = function(ast)
        return function(...)
            local args = { ... }
            for i = 1, #args, 1 do
                local arg = args[i]
            end
        end
    end
}

function ASTNode:Print(depth: number?)
    depth = depth or 0

    local out = ""
    for i = 1, depth, 1 do
        out ..= "\t"
    end

    out ..= self.Type
    if self:IsLiteral() then
        out ..= " : " .. self.Value
        print(out)
    else
        if self.Type == "error" then
            -- must not be literal, but is an error, meaning it's an error_with_children
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


function mod.new(type_desc: string)
end

local t = [[
table(
    number: vector3(i8,f32,f16),
    string:i16,
    string: i32,
    vector99(i8, i8, i8)
)

]]

-- function mod.__tests(G: LMT.LMGame, T: LMT.Tester)
--     local tokens = parse(t)
--     print(tokens)
-- end

function mod.__init(G)
    warn("DOING IT")
    local tokens = tokenize(t)
    local ast = parse_token_stream(tokens)
    ast:Print()
    -- print("Parsing", t)
    -- for i,v in tokens do
    --     print(i, v)
    -- end
    -- print(tokens)
end


return mod
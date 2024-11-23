--!strict
--!native

local Tokenizer = require(script.Tokenizer)
local Players = game:GetService("Players")

local SCRIPT_NAME = script.Name

local mod = {}

type i8_literal = "i8"
type i16_literal = "i16"
type i32_literal = "i32"
type u8_literal = "u8"
type u16_literal = "u16"
type u32_literal = "u32"
type f32_literal = "f32"
type f64_literal = "f64"
type PrimitiveLiterals =
	i8_literal
	| i16_literal
	| i32_literal
	| u8_literal
	| u16_literal
	| u32_literal
	| f32_literal
	| f64_literal



type NodeAttributes = {
	[string]: any,
}



type ASTParseRoot = {
	Type: "root",
	Value: ASTParseChildren,
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTParseError = {
	Type: "error",
	Value: Token,
	Extra: string,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTParseErrorWChildren = {
	Type: "error",
	Value: ASTParseChildren,
	Extra: string,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTParseComment = {
	Type: "comment",
	Value: string,
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTParseTypeLiteral = {
	Type: "type_literal",
	Value: PrimitiveLiterals,
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTParseStringLiteral = {
	Type: "string_literal",
	Value: string,
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTParseNumberLiteral = {
	Type: "number_literal",
	Value: number,
	Extra: PrimitiveLiterals,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTParseEnum = {
	Type: "enum",
	Value: { ASTParseStringLiteral | ASTParseError | ASTParseErrorWChildren },
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTParseArray = {
	Type: "array",
	Value: ASTParseHostNodes,
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTParsePeriodicArray = {
	Type: "periodic_array",
	Value: ASTParseHostNodes,
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTParseVector3 = {
	Type: "vector3",
	Value: { ASTParseTypeLiteral | ASTParseError | ASTParseErrorWChildren },
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTParseSizeSpecifier = {
	Type: "size_specifier",
	Value: number,
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTParseBinding = {
	Type: "binding",
	Value: ASTParseTerminals,
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTParseMap = {
	Type: "map",
	Value: { ASTParseBinding },
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTParseString = {
	Type: "string",
	Value: unknown,
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTParseStruct = {
	Type: "struct",
	Value: { ASTParseBinding | ASTParseError },
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTParseCFrame = {
	Type: "cframe",
	Value: { PrimitiveLiterals | ASTParseError },
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTParsePlayer = {
	Type: "player",
	Value: { ASTParsePlayer },
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}

type ASTParseChildren = { ASTParseNodes }
type ASTParseTerminal =
	ASTParseTypeLiteral
	| ASTParseStringLiteral
	| ASTParseNumberLiteral
	| ASTParseString
	| ASTParseError
	| ASTParsePlayer
type ASTParseHostNodes =
	ASTParseTerminal
	& {
		ASTParseVector3
		| ASTParseEnum
		| ASTParseArray
		| ASTParsePeriodicArray
		| ASTParseMap
		| ASTParseStruct
		| ASTParseErrorWChildren
		| ASTParseCFrame
		| ASTParsePlayer
	}
type ASTParseTerminals = { ASTParseTerminal | ASTParseError | ASTParseErrorWChildren }
type ASTParseNodes =
	ASTParseError
	| ASTParseErrorWChildren
	| ASTParseComment
	| ASTParseTypeLiteral
	| ASTParseStringLiteral
	| ASTParseNumberLiteral
	| ASTParseEnum
	| ASTParseArray
	| ASTParsePeriodicArray
	| ASTParseVector3
	| ASTParseSizeSpecifier
	| ASTParseBinding
	| ASTParseMap
	| ASTParseString
	| ASTParseStruct
	| ASTParseCFrame
	| ASTParsePlayer

type ASTValidRoot = {
	Type: "root",
	Value: ASTValidChildren,
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTValidComment = {
	Type: "comment",
	Value: string,
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTValidTypeLiteral = {
	Type: "type_literal",
	Value: PrimitiveLiterals,
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTValidStringLiteral = {
	Type: "string_literal",
	Value: string,
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTValidNumberLiteral = {
	Type: "number_literal",
	Value: number,
	Extra: PrimitiveLiterals,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTValidEnum = {
	Type: "enum",
	Value: { ASTValidStringLiteral },
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTValidArray = {
	Type: "array",
	Value: ASTValidHostNodes,
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTValidPeriodicArray = {
	Type: "periodic_array",
	Value: ASTValidHostNodes,
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTValidVector3 = {
	Type: "vector3",
	Value: { ASTValidTypeLiteral },
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTValidSizeSpecifier = {
	Type: "size_specifier",
	Value: number,
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTValidBinding = {
	Type: "binding",
	Value: ASTValidTerminals,
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTValidMap = {
	Type: "map",
	Value: { ASTValidBinding },
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTValidString = {
	Type: "string",
	Value: unknown,
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTValidStruct = {
	Type: "struct",
	Value: { ASTValidBinding },
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTValidCFrame = {
	Type: "cframe",
	Value: { PrimitiveLiterals },
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}
type ASTValidPlayer = {
	Type: "player",
	Value: false,
	Extra: false,
	TokenIndex: number,
	TokenSize: number,
	Attributes: NodeAttributes,
}

type ASTValidChildren = { ASTValidNodes }
type ASTValidTerminal = ASTValidTypeLiteral | ASTValidStringLiteral | ASTValidNumberLiteral | ASTValidString
type ASTValidHostNodes =
	{ ASTValidTerminal }
	& { 
		ASTValidVector3
		| ASTValidEnum
		| ASTValidArray
		| ASTValidPeriodicArray
		| ASTValidMap
		| ASTValidStruct
		| ASTValidCFrame
		| ASTValidPlayer
	}
type ASTValidTerminals = { ASTValidTerminal }
type ASTValidNodes =
	ASTValidComment
	| ASTValidTypeLiteral
	| ASTValidStringLiteral
	| ASTValidNumberLiteral
	| ASTValidEnum
	| ASTValidArray
	| ASTValidPeriodicArray
	| ASTValidVector3
	| ASTValidSizeSpecifier
	| ASTValidBinding
	| ASTValidMap
	| ASTValidString
	| ASTValidStruct
	| ASTValidCFrame
	| ASTValidPlayer

local TAB_BYTE = string.byte("\t")

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

local function r_i8(b: buffer, idx: number): (number, number)
	return buffer.readi8(b, idx), 1
end
local function r_i16(b: buffer, idx: number): (number, number)
	return buffer.readi16(b, idx), 2
end
local function r_i32(b: buffer, idx: number): (number, number)
	return buffer.readi32(b, idx), 4
end
local function r_u8(b: buffer, idx: number): (number, number)
	return buffer.readu8(b, idx), 1
end
local function r_u16(b: buffer, idx: number): (number, number)
	return buffer.readu16(b, idx), 2
end
local function r_u32(b: buffer, idx: number): (number, number)
	return buffer.readu32(b, idx), 4
end
local function r_f32(b: buffer, idx: number): (number, number)
	return buffer.readf32(b, idx), 4
end
local function r_f64(b: buffer, idx: number): (number, number)
	return buffer.readf64(b, idx), 8
end

-- Non-terminal writers rely on upvalues and are generated in the serialize/deserialize visitors
local writers = {
	w_i8,
	w_i16,
	w_i32,
	w_u8,
	w_u16,
	w_u32,
	w_f32,
	w_f64,
}

local readers = {
	r_i8,
	r_i16,
	r_i32,
	r_u8,
	r_u16,
	r_u32,
	r_f32,
	r_f64,
}

-- Fortunately we only use these functions to store byte lengths, so u32 is enough
local raw_byte_writers: { (v: number, b: buffer, idx: number) -> number } = {
	[1] = w_u8,
	[2] = w_u16,
	[3] = w_u32,
	[4] = w_u32,
}
local raw_byte_readers = {
	[1] = r_u8,
	[2] = r_u16,
	[3] = r_u32,
	[4] = r_u32,
}

local function sum(t: { [any]: number })
	local s = 0
	for i, v in t do
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
	if bytes == 3 then
		bytes = 4
	end

	return bytes
end

local function write_size_specifier(v: number, b: buffer, idx: number)
	assert(v < 2 ^ 30)
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

local function count_table_keys(t: {})
	local i = 0
	for _, _ in t do
		i += 1
	end

	return i
end

local function is_separator(c: string)
	return c == "(" or c == ")" or c == "," or c == ":" or c == "[" or c == "]"
end

type Token = Tokenizer.Token
type Tokens = Tokenizer.Tokens
type Location = Tokenizer.Location
type TokenLocation = Tokenizer.TokenLocation

type NodeConstructor<R, E...> = (tokens: Tokens, idx: number, E...) -> (R, number)

local NodeConstructors: {
	root: NodeConstructor<ASTParseChildren>,
	error: NodeConstructor<ASTParseError, string, number>,
	error_with_unparsed_children: NodeConstructor<ASTParseErrorWChildren, string>,
	error_with_children: NodeConstructor<ASTParseErrorWChildren, string, number, ASTParseChildren>,
	comment: NodeConstructor<nil>,
	type_literal: NodeConstructor<ASTParseTypeLiteral>,
	string_literal: NodeConstructor<ASTParseStringLiteral>,
	number_literal: NodeConstructor<ASTParseNumberLiteral | ASTParseError>,
	-- TODO: This was designed out but may be used again for predicting max sizes?
	size_specifier: NodeConstructor<ASTParseSizeSpecifier | ASTParseError>,
	max_size: NodeConstructor<ASTParseSizeSpecifier | ASTParseError>,
	binding: NodeConstructor<ASTParseBinding, ASTValidTerminals, number>,
}

local Keywords: {
	i8: NodeConstructor<ASTParseTypeLiteral>,
	i16: NodeConstructor<ASTParseTypeLiteral>,
	i32: NodeConstructor<ASTParseTypeLiteral>,
	u8: NodeConstructor<ASTParseTypeLiteral>,
	u16: NodeConstructor<ASTParseTypeLiteral>,
	u32: NodeConstructor<ASTParseTypeLiteral>,
	f32: NodeConstructor<ASTParseTypeLiteral>,
	f64: NodeConstructor<ASTParseTypeLiteral>,
	string: NodeConstructor<ASTParseString>,
	enum: NodeConstructor<ASTParseEnum>,
	array: NodeConstructor<ASTParseArray>,
	periodic_array: NodeConstructor<ASTParsePeriodicArray | ASTParseError>,
	map: NodeConstructor<ASTParseMap | ASTParseError>,
	struct: NodeConstructor<ASTParseStruct | ASTParseError>,
	vector3: NodeConstructor<ASTParseVector3 | ASTParseError>,
	cframe: NodeConstructor<ASTParseCFrame | ASTParseError>,
	player: NodeConstructor<ASTParsePlayer>,
}

local Attributes = {
	optional = true,
}

local function next_node_from_position<R>(
	tokens: Tokens,
	idx: number
): (
	R | ASTParseStringLiteral | ASTParseNumberLiteral | ASTParseError | ASTParseErrorWChildren,
	number
)
	local leading_tokens_consumed = 0
	local token = tokens[idx]
	while token and is_separator(token) do
		idx += 1
		leading_tokens_consumed += 1
		token = tokens[idx]
	end

	if not token then
		local node, consumed = NodeConstructors.error(tokens, idx - 1, "Unexpected end of input", 1)
		return node, consumed + leading_tokens_consumed
	end

	if token == '"' then
		local node, consumed = NodeConstructors.string_literal(tokens, idx)
		return node, consumed + leading_tokens_consumed
	end

	if tonumber(token) ~= nil then
		local node, consumed = NodeConstructors.number_literal(tokens, idx)
		return node, consumed + leading_tokens_consumed
	end

	if token == "@" then
		local next_node, consumed = next_node_from_position(tokens, idx + 2)
		
		local attribute = tokens[idx + 1]
		if not Attributes[attribute] then
			if typeof(next_node.Value) == "table" then
				local err, _ = NodeConstructors.error_with_children(tokens, idx + 1, `Unrecognized attribute {attribute}`, next_node.TokenSize + 2, next_node.Value)
				return err, consumed + leading_tokens_consumed + 2
			else
				local err, _ = NodeConstructors.error_with_children(tokens, idx + 1, `Unrecognized attribute {attribute}`, 3, {next_node})
				return err, consumed + leading_tokens_consumed + 2
			end
		end

		next_node.Attributes[attribute] = true

		return next_node, consumed + leading_tokens_consumed + 2
	end

	local node_ctor = Keywords[token]

	if not node_ctor then
		if tokens[idx + 1] == "(" then
			local node, consumed = NodeConstructors.error_with_unparsed_children(tokens, idx, `Unrecognized type identifier {token}`)
			return node, consumed + leading_tokens_consumed
		else
			local node, consumed = NodeConstructors.error(tokens, idx, `Unrecognized type identifier {token}`, 1)
			return node, consumed + leading_tokens_consumed
		end
	end

	local node, node_consumed = node_ctor(tokens, idx)
	return node, node_consumed + leading_tokens_consumed
end

local function parse_binding(tokens: Tokens, idx: number): (ASTParseBinding | ASTParseErrorWChildren, number)
	local lhs, rhs, consumed
	local consumed_total = 0
	lhs, consumed = next_node_from_position(tokens, idx)
	consumed_total += consumed
	idx += consumed

	if tokens[idx] == ":" then
		idx += 1
		rhs, consumed = next_node_from_position(tokens, idx)
		consumed_total += (consumed + 1)
		idx += consumed

		local binding, _ = NodeConstructors.binding(tokens, idx, { lhs, rhs }, consumed_total)

		-- Hoist attributes, which will end up on the lhs since it will directly follow the attributes
		for i,v in lhs.Attributes do
			binding.Attributes[i] = v
		end

		return binding, consumed_total
	else
		rhs, consumed = next_node_from_position(tokens, idx)
		consumed_total += consumed
		idx += consumed

		return NodeConstructors.error_with_children(
			tokens,
			idx - consumed_total,
			`Colon required after left hand side of type binding`,
			consumed_total,
			{ lhs, rhs }
		)
	end
end

local function parse_binding_list(
	tokens: Tokens,
	idx: number
): ({ ASTParseBinding | ASTParseError | ASTParseErrorWChildren }, number)
	local children: { ASTParseBinding | ASTParseError | ASTParseErrorWChildren }, consumed_total = {}, 1

	if tokens[idx] ~= "(" then
		local err =
			NodeConstructors.error(tokens, idx, `Unexpected token {tokens[idx]}: missing ( to open binding list`, 1)
		table.insert(children, err)
		return children, 1
	end

	idx += 1

	while true do
		local token = tokens[idx]
		if not token then
			local err = NodeConstructors.error(tokens, idx - 1, "Unexpected end of input", 1)
			table.insert(children, err)
			return children, consumed_total
		end

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
local function parse_chunk(tokens: Tokens, idx: number): (ASTParseChildren, number)
	local token_ct = #tokens
	local consumed = 0
	local nodes: ASTParseChildren = {}
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

		local root_node, children_consumed = next_node_from_position(tokens, idx)

		consumed += children_consumed
		idx += children_consumed

		if root_node then
			table.insert(nodes, root_node)
		end
	end

	return nodes, consumed
end

local function parse_token_stream(tokens: { string })
	return NodeConstructors.root(tokens, 1)
end

local function new_node<T, R>(type: string, value: T, index: number, tokens_consumed: number, extra: string?): R
	-- @Types
	-- Ideally calling this function with data that doesn't align with the node types wouldn't work
	-- but for some reason it either always works or never works depending on the signature
	local node = {
		Type = type,
		Value = value,
		TokenIndex = index,
		TokenSize = tokens_consumed,
		Extra = extra or false,
		Attributes = { } :: NodeAttributes,
	}

	return (node :: any) :: R
end

local RootConstructs = {
	type_literal = true,
	string = true,
	string_literal = true,
	number_literal = true,
	array = true,
	periodic_array = true,
	vector3 = true,
	enum = true,
	map = true,
	struct = true,
	cframe = true,
	player = true
}

local function ASTNodeIsValidHost<Node>(node: Node)
	return RootConstructs[node.Type] == true
end

-- For visitors which return numbers for trivial nodes
-- and functions for non-trivial nodes
local function VisitorChildrenAreTrivial<Children>(children: Children)
	if typeof(children) == "number" then
		return true
	end

	for i, v in children do
		if typeof(v) ~= "number" then
			return false
		end
	end

	return true
end

local function ASTChildrenHasOptionals<Children>(children: Children)
	for _, node in children do
		if node.Attributes.optional then
			return true
		end
	end

	return false
end

local function VisitorVisit<Visitor, Node, R>(self: Visitor, node: Node): R
	local ty = node.Type
	local visit_fn = self[ty]
	if not visit_fn then
		error(`Visitor missing impl for {node.Type}`)
	end

	return visit_fn(self, node)
end

local function ASTNodeAccept<Node, Visitor, R>(node: Node, visitor: Visitor): R
	local ret = VisitorVisit(visitor, node)
	return ret
end

local function VisitorTraverseChildren<Visitor, Node>(self: Visitor, node: Node)
	local children = node.Value
	local len = #children

	for i = 1, len, 1 do
		ASTNodeAccept(children[i], self)
	end

	return
end

local function VisitorCollectChildren<Visitor, Node, R>(self: Visitor, node: Node): R
	local children = node.Value
	local len = #children
	local vals = table.create(len)

	for i = 1, len, 1 do
		-- Some weird incantation that lets a visitor be able to return any number of values without using tables
		-- This behavior is desirable to let CollectChildren output a linear list of return values even if some
		-- nodes return multiple values
		-- E.G. the NodeSizeVisitor wants a linear list of node sizes
		local val = { ASTNodeAccept(children[i], self) }
		for _, v in val do
			table.insert(vals, v)
		end
	end

	return vals
end

-- Each function return the node and then the number of tokens it consumed
-- The parse function handles closing parenthesis but not opening ones since each of these
-- will be consuming tokens after the opening parenthesis

local function root(tokens: Tokens, idx: number)
	local children, consumed = parse_chunk(tokens, 1)
	local node: ASTParseRoot = new_node("root", children, idx, consumed)
	return node, consumed
end
local function _error(tokens: Tokens, idx: number, err: string, size: number)
	local node: ASTParseError = new_node("error", tokens[idx], idx, size, err)
	return node, size
end
local function error_with_children(
	tokens: Tokens,
	idx: number,
	err: string,
	token_size: number,
	children: ASTParseChildren
)
	local node: ASTParseErrorWChildren = new_node("error", children, idx, token_size, err)
	return node, token_size
end
local function error_with_unparsed_children(tokens: Tokens, idx: number, err: string)
	local children, consumed = parse_chunk(tokens, idx + 1)
	local consumed_total = consumed + 1
	local node, _ = error_with_children(tokens, idx, err, consumed_total, children)
	return node, consumed_total
end
local function comment(tokens: Tokens, idx: number)
	-- The entire comment is a single token
	-- local node = new_node("comment", tokens[idx], idx, 1)
	return nil, 1
end
local function type_literal(tokens: Tokens, idx: number)
	local node: ASTParseTypeLiteral = new_node("type_literal", tokens[idx], idx, 1)
	return node, 1
end
local function string_literal(tokens: Tokens, idx: number)
	local node: ASTParseStringLiteral = new_node("string_literal", tokens[idx + 1], idx, 3)
	return node, 3
end
local function number_literal(tokens: Tokens, idx: number)
	local n = tonumber(tokens[idx])
	if typeof(n) == "number" then
		local primitive
		if n % 1 == 0 then
			primitive = "i32"
		else
			primitive = "f64"
		end

		local node: ASTParseNumberLiteral = new_node("number_literal", n, idx, 1, primitive)
		return node, 1
	else
		return _error(tokens, idx, "Internal error: passed non-number to number_literal", 1)
	end
end
local function _string(tokens: Tokens, idx: number)
	local node: ASTParseString = new_node("string", false, idx, 1)
	return node, 1
end
local function enum(tokens: Tokens, idx: number)
	local children, consumed = parse_chunk(tokens, idx + 1)
	local consumed_total = consumed + 1

	for i, v in children do
		if v.Type ~= "string_literal" then
			local err, _ =
				_error(tokens, v.TokenIndex, `Unexpected {v.Value}, enum can only contain string literals`, v.TokenSize)
			children[i] = err
		end
	end

	-- Specifies the size of the numbers stored in the buffer, not the length
	-- table.insert(children, new_node("size_specifier", #children, -1, 0))
	local node: ASTParseEnum = new_node("enum", children, idx, consumed_total)

	return node, consumed_total
end
local function array(tokens: Tokens, idx: number)
	local children, consumed = parse_chunk(tokens, idx + 1)
	local consumed_total = consumed + 1

	for i, v in children do
		if not ASTNodeIsValidHost(v) then
			if v.Type ~= "error" then
				local err, _ = _error(
					tokens,
					v.TokenIndex,
					`Unexpected {v.Value}, array can only contain read/write constructs`,
					v.TokenSize
				)
				children[i] = err
			end
		end
	end

	local node: ASTParseArray = new_node("array", children, idx, consumed_total)
	return node, consumed_total
end
local function periodic_array(tokens: Tokens, idx: number)
	local children, consumed = parse_chunk(tokens, idx + 1)
	local consumed_total = consumed + 1

	if #children == 0 then
		return _error(tokens, idx, "periodic_array must contain at least one serializable object", consumed_total)
	else
		for i, v in children do
			if not ASTNodeIsValidHost(v) then
				if v.Type ~= "error" then
					local err, _ = _error(
						tokens,
						v.TokenIndex,
						`Unexpected {v.Value}, array can only contain read/write constructs`,
						v.TokenSize
					)
					children[i] = err
				end
			end
		end
	end

	local node: ASTParsePeriodicArray = new_node("periodic_array", children, idx, consumed_total)
	return node, consumed_total
end
local function map(tokens: Tokens, idx: number)
	local children, consumed = parse_binding_list(tokens, idx + 1)
	local consumed_total = consumed + 1

	if #children > 1 then
		for i, v in children do
			local err, _ = _error(tokens, v.TokenIndex, "map can only have one binding", v.TokenSize)
			children[i] = err
		end
	elseif #children == 0 then
		return _error(tokens, idx, "map must contain a type binding", consumed_total)
	end

	local child_type = children[1].Type
	if child_type ~= "binding" and child_type ~= "error" then
		return _error(tokens, idx, "map must contain a type binding", consumed_total)
	end

	local node: ASTParseMap = new_node("map", children, idx, consumed_total)
	return node, consumed_total
end
local function struct(tokens: Tokens, idx: number)
	local children, consumed = parse_binding_list(tokens, idx + 1)
	local consumed_total = consumed + 1

	if #children > 0 then
		for i, v in children do
			local child_type = v.Type
			if child_type ~= "binding" then
				if child_type ~= "error" then
					local err, _ = _error(tokens, v.TokenIndex, `struct expected type binding, got {v.Type}`, v.TokenSize)
					children[i] = err
				end
			else
				local lhs = v.Value[1]
				local lhs_type = lhs.Type
				if lhs_type ~= "error" and lhs_type ~= "number_literal" and lhs_type ~= "string_literal" then
					children[i] = _error(
						tokens,
						lhs.TokenIndex,
						"left hand side of struct bindings must be a number or string literal",
						lhs.TokenSize
					)
				end
			end
		end
	else
		return _error(tokens, idx, "struct must contain at least one binding", consumed_total)
	end

	local node: ASTParseStruct = new_node("struct", children, idx, consumed_total)
	return node, consumed_total
end
local function vector3(tokens: Tokens, idx: number)
	local children, consumed = parse_chunk(tokens, idx + 1)
	local consumed_total = consumed + 1

	local is_ok = #children == 3
	for i, v in children do
		if v.Type ~= "type_literal" then
			is_ok = false
			break
		end
	end

	if not is_ok then
		return _error(tokens, idx, "vector3 expects 3 type literals", consumed_total)
	end

	local node: ASTParseVector3 = new_node("vector3", children, idx, consumed_total)
	return node, consumed_total
end
local function cframe(tokens: Tokens, idx: number)
	local children, consumed = parse_chunk(tokens, idx + 1)
	local consumed_total = consumed + 1

	local is_ok = #children == 3
	for i, v in children do
		if v.Type ~= "type_literal" then
			is_ok = false
			break
		end
	end

	if not is_ok then
		return _error(tokens, idx, "cframe expects 3 type literals (for encoding its position vector)", consumed_total)
	end

	local node: ASTParseCFrame = new_node("cframe", children, idx, consumed_total)
	return node, consumed_total
end
local function size_specifier(tokens: Tokens, idx: number)
	local seperator = tokens[idx + 1]
	local size = tonumber(tokens[idx + 2])

	if not is_separator(seperator) then
		return _error(tokens, idx, "Missing seperator for size specifier", 2)
	end

	if not size then
		return _error(tokens, idx, "Expected number for size specifier", 3)
	end

	local node: ASTParseSizeSpecifier = new_node("size_specifier", size, idx, 3)
	return node, 3
end
local function max_size(tokens: Tokens, idx: number)
	return size_specifier(tokens, idx)
end
local function binding(tokens: Tokens, idx: number, children: ASTValidTerminals, token_size: number)
	local node: ASTParseBinding = new_node("binding", children, idx, token_size)
	return node, token_size
end
local function player(tokens: Tokens, idx: number)
	local node: ASTParsePlayer = new_node("player", false, idx, 1)
	return node, 1
end
local function i8(tokens: Tokens, idx: number)
	return type_literal(tokens, idx)
end
local function i16(tokens: Tokens, idx: number)
	return type_literal(tokens, idx)
end
local function i32(tokens: Tokens, idx: number)
	return type_literal(tokens, idx)
end
local function u8(tokens: Tokens, idx: number)
	return type_literal(tokens, idx)
end
local function u16(tokens: Tokens, idx: number)
	return type_literal(tokens, idx)
end
local function u32(tokens: Tokens, idx: number)
	return type_literal(tokens, idx)
end
local function f32(tokens: Tokens, idx: number)
	return type_literal(tokens, idx)
end
local function f64(tokens: Tokens, idx: number)
	return type_literal(tokens, idx)
end

NodeConstructors = {
	root = root,
	error = _error,
	error_with_unparsed_children = error_with_unparsed_children,
	error_with_children = error_with_children,
	comment = comment,
	type_literal = type_literal,
	string_literal = string_literal,
	number_literal = number_literal,
	size_specifier = size_specifier,
	max_size = max_size,
	binding = binding,
}

Keywords = {
	i8 = i8,
	i16 = i16,
	i32 = i32,
	u8 = u8,
	u16 = u16,
	u32 = u32,
	f32 = f32,
	f64 = f64,
	string = _string,
	enum = enum,
	array = array,
	periodic_array = periodic_array,
	map = map,
	struct = struct,
	vector3 = vector3,
	cframe = cframe,
	player = player,
}

-- Visitor that can take in non-error-checked ASTs
type ParseVisitor<
	ParentVisitor,
	RootRet,
	CommentRet,
	ErrorRet,
	TypeLiteralRet,
	StringLiteralRet,
	NumberLiteralRet,
	StringRet,
	EnumRet,
	ArrayRet,
	PeriodicArrayRet,
	Vector3Ret,
	SizeSpecifierRet,
	BindingRet,
	MapRet,
	StructRet,
	CFrameRet,
	PlayerRet
> = {
	root: (ParentVisitor, ASTParseRoot) -> RootRet,
	comment: (ParentVisitor, ASTParseComment) -> CommentRet,
	error: (ParentVisitor, ASTParseError) -> ErrorRet,
	type_literal: (ParentVisitor, ASTParseTypeLiteral) -> TypeLiteralRet,
	string_literal: (ParentVisitor, ASTParseStringLiteral) -> StringLiteralRet,
	number_literal: (ParentVisitor, ASTParseNumberLiteral) -> NumberLiteralRet,
	enum: (ParentVisitor, ASTParseEnum) -> EnumRet,
	array: (ParentVisitor, ASTParseArray) -> ArrayRet,
	periodic_array: (ParentVisitor, ASTParsePeriodicArray) -> PeriodicArrayRet,
	vector3: (ParentVisitor, ASTParseVector3) -> Vector3Ret,
	size_specifier: (ParentVisitor, ASTParseSizeSpecifier) -> SizeSpecifierRet,
	binding: (ParentVisitor, ASTParseBinding) -> BindingRet,
	map: (ParentVisitor, ASTParseMap) -> MapRet,
	string: (ParentVisitor, ASTParseString) -> StringRet,
	struct: (ParentVisitor, ASTParseStruct) -> StructRet,
	cframe: (ParentVisitor, ASTParseCFrame) -> CFrameRet,
	player: (ParentVisitor, ASTParsePlayer) -> PlayerRet,
}

type ValidVisitor<
	ParentVisitor,
	RootRet,
	TypeLiteralRet,
	StringLiteralRet,
	NumberLiteralRet,
	StringRet,
	EnumRet,
	ArrayRet,
	PeriodicArrayRet,
	Vector3Ret,
	SizeSpecifierRet,
	BindingRet,
	MapRet,
	StructRet,
	CFrameRet,
	PlayerRet
> = {
	root: (ParentVisitor, ASTValidRoot) -> RootRet,
	type_literal: (ParentVisitor, ASTValidTypeLiteral) -> TypeLiteralRet,
	string_literal: (ParentVisitor, ASTValidStringLiteral) -> StringLiteralRet,
	number_literal: (ParentVisitor, ASTValidNumberLiteral) -> NumberLiteralRet,
	enum: (ParentVisitor, ASTValidEnum) -> EnumRet,
	array: (ParentVisitor, ASTValidArray) -> ArrayRet,
	periodic_array: (ParentVisitor, ASTValidPeriodicArray) -> PeriodicArrayRet,
	vector3: (ParentVisitor, ASTValidVector3) -> Vector3Ret,
	size_specifier: (ParentVisitor, ASTValidSizeSpecifier) -> SizeSpecifierRet,
	binding: (ParentVisitor, ASTValidBinding) -> BindingRet,
	map: (ParentVisitor, ASTValidMap) -> MapRet,
	string: (ParentVisitor, ASTValidString) -> StringRet,
	struct: (ParentVisitor, ASTValidStruct) -> StructRet,
	cframe: (ParentVisitor, ASTValidCFrame) -> CFrameRet,
	player: (ParentVisitor, ASTValidPlayer) -> PlayerRet,
}

-- stylua: ignore
type ErrorReportVisitor = ParseVisitor<
	ErrorReportVisitor,
	nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
>

local function PrintErrors(node: ASTParseNodes, src: string, locations: { TokenLocation })
	local source_by_line = string.split(src, "\n")
	local line_start_idx: { number } = table.create(#source_by_line)

	local s,l
	local _level = 1
	local script_pattern = "\." .. SCRIPT_NAME .. "$"
	local trace = ""
	repeat
		_level += 1
		s, l = debug.info(_level, "sl")

		if s and l and l > -1 then
			local is_in_this_file = string.find(s, script_pattern, 1, false)
			if not is_in_this_file then
				trace ..= s .. " " .. l .. "\n"
			end
		else
			break
		end
	until false

	warn("SerDesmond:\nError compiling SerDes string\n\nTraceback:")
	warn(trace)
	warn("\n\nRaw source:")
	warn(src)

	for i = 1, #source_by_line, 1 do
		line_start_idx[i] = string.len(source_by_line[i - 1] or "") + (line_start_idx[i - 1] or 0) + 1
	end

	local AnnotateSourceVisitor: ErrorReportVisitor = {
		root = function(self, node)
			VisitorTraverseChildren(self, node)
		end,
		comment = function(self, node)
		end,
		error = function(self, node)
			local location = locations[node.TokenIndex]

			warn(`\nL: {location.Start.Line}:{location.Start.Index}`)
			local line: string = source_by_line[location.Start.Line]
			print(line)

			local err_highlighter = ""
			for i = line_start_idx[location.Start.Line], location.Start.Index - 1 do
				local a = string.byte(src, i, i)
				if a == TAB_BYTE then
					err_highlighter ..= "\t"
				else
					err_highlighter ..= " "
				end
			end

			local end_idx = if location.End.Line == location.Start.Line then location.End.Index else string.len(line)
			for i = location.Start.Index, end_idx, 1 do
				err_highlighter ..= "^"
			end

			warn(err_highlighter)
			warn("Error: " .. node.Extra)

			if typeof(node.Value) == "table" then
				VisitorTraverseChildren(self, node)
			end
		end,
		type_literal = function(self, node)
		end,
		string_literal = function(self, node)
		end,
		number_literal = function(self, node)
		end,
		enum = function(self, node)
			VisitorTraverseChildren(self, node)
		end,
		array = function(self, node)
			VisitorTraverseChildren(self, node)
		end,
		periodic_array = function(self, node)
			VisitorTraverseChildren(self, node)
		end,
		vector3 = function(self, node)
			VisitorTraverseChildren(self, node)
		end,
		size_specifier = function(self, node)
		end,
		binding = function(self, node)
			VisitorTraverseChildren(self, node)
		end,
		map = function(self, node)
			VisitorTraverseChildren(self, node)
		end,
		string = function(self, node)
		end,
		struct = function(self, node)
			VisitorTraverseChildren(self, node)
		end,
		cframe = function(self, node)
			VisitorTraverseChildren(self, node)
		end,
		player = function(self, node)
		end
	}

	ASTNodeAccept(node, AnnotateSourceVisitor)
end

-- stylua: ignore
type PrintASTVisitor = ParseVisitor<
	PrintASTVisitor,
	nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
>

local function PrintAST(ast: ASTParseRoot | ASTValidRoot)
	local indent = 0
	local function print_desc(self, desc: string)
		local out = ""
		for i = 1, indent, 1 do
			out ..= "\t"
		end

		print(out .. desc)
	end

	local visitor: PrintASTVisitor = {
		root = function(self, node)
			print_desc(self, "root")
			indent += 1
			VisitorTraverseChildren(self, node)
			indent -= 1
		end,
		comment = function(self, node)
			print_desc(self, "comment: " .. node.Value)
		end,
		error = function(self, node)
			print_desc(self, "error: " .. node.Extra)
			if typeof(node.Value) == "table" then
				indent += 1
				VisitorTraverseChildren(self, node)
				indent -= 1
			end
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
			indent += 1
			VisitorTraverseChildren(self, node)
			indent -= 1
		end,
		array = function(self, node)
			print_desc(self, "array:")
			indent += 1
			VisitorTraverseChildren(self, node)
			indent -= 1
		end,
		periodic_array = function(self, node)
			print_desc(self, "periodic_array:")
			indent += 1
			VisitorTraverseChildren(self, node)
			indent -= 1
		end,
		map = function(self, node)
			print_desc(self, "map:")
			indent += 1
			VisitorTraverseChildren(self, node)
			indent -= 1
		end,
		struct = function(self, node)
			print_desc(self, "struct:")
			indent += 1
			VisitorTraverseChildren(self, node)
			indent -= 1
		end,
		vector3 = function(self, node)
			print_desc(self, "vector3:")
			indent += 1
			VisitorTraverseChildren(self, node)
			indent -= 1
		end,
		size_specifier = function(self, node)
			-- handled by parent
		end,
		binding = function(self, node)
			print_desc(self, "binding")
			indent += 1
			VisitorTraverseChildren(self, node)
			indent -= 1
		end,
		cframe = function(self, node)
			print_desc(self, "cframe")
			indent += 1
			VisitorTraverseChildren(self, node)
			indent -= 1
		end,
		player = function(self, node)
			print_desc(self, "player")
		end
	}

	ASTNodeAccept(ast, visitor)
end

type ValidateVisitor = ParseVisitor<
	ValidateVisitor,
	ASTValidRoot?,
	nil,
	number,
	nil,
	nil,
	nil,
	nil,
	number?,
	number?,
	number?,
	number?,
	nil,
	number?,
	number?,
	number?,
	number?,
	nil
>

local ValidateVisitor: ValidateVisitor = {
	root = function(self, node)
		local is_valid = sum(VisitorCollectChildren(self, node)) < math.huge
		if is_valid then
			return (node :: any) :: ASTValidRoot
		else
			return nil
		end
	end,
	comment = function(self, node)
		return nil
	end,
	error = function(self, node)
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
		return sum(VisitorCollectChildren(self, node))
	end,
	array = function(self, node)
		return sum(VisitorCollectChildren(self, node))
	end,
	map = function(self, node)
		return sum(VisitorCollectChildren(self, node))
	end,
	struct = function(self, node)
		return sum(VisitorCollectChildren(self, node))
	end,
	periodic_array = function(self, node)
		return sum(VisitorCollectChildren(self, node))
	end,
	vector3 = function(self, node)
		return sum(VisitorCollectChildren(self, node))
	end,
	size_specifier = function(self, node)
		return nil
	end,
	binding = function(self, node)
		return sum(VisitorCollectChildren(self, node))
	end,
	cframe = function(self, node)
		return sum(VisitorCollectChildren(self, node))
	end,
	player = function(self, node)
		return nil
	end
}

-- Calculates the byte size each argument to the serializer will take up
-- For variable size nodes, it will calculate the max size

type SizeCalcFn<T> = (T) -> number
type SizeCalcRootRet = { number | SizeCalcFn<unknown> }
type SizeCalcVisitor = ValidVisitor<
	SizeCalcVisitor,
	SizeCalcRootRet,
	number,
	number,
	number,
	SizeCalcFn<string>,
	SizeCalcFn<{ string }>,
	number | SizeCalcFn<{ unknown }>,
	SizeCalcFn<{ unknown }>,
	number,
	number,
	(number | SizeCalcFn<unknown>, number | SizeCalcFn<unknown>) -> number,
	SizeCalcFn<{ [string]: number }> | SizeCalcFn<{ unknown }>,
	SizeCalcFn<{ [string | number]: unknown }> | number,
	number,
	number
>

local SizeCalcVisitor: SizeCalcVisitor = {
	root = function(self, node)
		return VisitorCollectChildren(self, node)
	end,
	type_literal = function(self, node)
		return type_literal_sizes[node.Value]
	end,
	size_specifier = function(self, node)
		return bytes_to_store_dynamic_size(node.Value)
	end,
	enum = function(self, node)
		local children = VisitorCollectChildren(self, node)

		return function(t: { string })
			local encoded_len = bytes_to_store_dynamic_size(#t)
			local encoded_number_size = bytes_to_store_dynamic_size(#children)
			return #t * encoded_number_size + encoded_len
		end
	end,
	binding = function(self, node)
		-- @Types
		-- children resolves to {(((unknown) -> number) | number) -> number}
		-- Should resolve to    {((unknown) -> number) | number}
		local children = VisitorCollectChildren(self, node)
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
				rs = rhs(r)
			end

			return ls + rs
		end
	end,
	string_literal = function(self, node)
		local len = string.len(node.Value)
		return bytes_to_store_dynamic_size(len) + len
	end,
	number_literal = function(self, node)
		return type_literal_sizes[node.Extra]
	end,
	string = function(self, node)
		return function(s: string)
			local len = string.len(s)
			return bytes_to_store_dynamic_size(len) + len
		end
	end,
	array = function(self, node)
		local children = VisitorCollectChildren(self, node)
		if VisitorChildrenAreTrivial(children) then
			return sum(children)
		else
			local dynamics = {}
			for i, v in children do
				if typeof(v) == "function" then
					dynamics[i] = v
				end
			end

			return function(t: { unknown })
				local total = 0
				for i, v in t do
					local size = children[i]
					if typeof(size) == "function" then
						total += size(v)
					else
						total += size
					end
				end

				return total
			end
		end
	end,
	periodic_array = function(self, node)
		local children = VisitorCollectChildren(self, node)
		if VisitorChildrenAreTrivial(children) then
			-- local size_padding = table.remove(child_sizes)
			local len_per_period = #children
			local size_per_period = sum(children)

			return function(t: { unknown })
				-- TODO: this breaks if a child is not a type literal
				local periods = #t / len_per_period
				assert(periods % 1 == 0)
				return periods * size_per_period + bytes_to_store_dynamic_size(periods)
			end
		else
			local dynamics = {}
			for i, v in children do
				if typeof(v) == "function" then
					dynamics[i] = v
				end
			end

			local len_per_period = #children

			return function(t: { unknown })
				local periods = #t / len_per_period
				local total = 0
				for i, v in t do
					local size = children[(i - 1) % len_per_period + 1]
					if typeof(size) == "function" then
						total += size(v)
					else
						total += size
					end
				end

				return periods + total + bytes_to_store_dynamic_size(periods)
			end
		end
	end,
	map = function(self, node)
		local children = VisitorCollectChildren(self, node)
		local binding_calc = children[1]

		return function(t: {})
			local s = bytes_to_store_dynamic_size(count_table_keys(t))
			for i, v in t do
				s += binding_calc(i, v)
			end

			return s
		end
	end,
	struct = function(self, node)
		local ast_children = node.Value
		local struct_len = bytes_to_store_dynamic_size(#ast_children)

		local map: { [string | number]: SizeCalcFn<unknown> | number } = {}
		for i, v in ast_children do
			local lhs = v.Value[1].Value :: string | number
			map[lhs] = ASTNodeAccept(v.Value[2], self)
		end

		local has_optionals = ASTChildrenHasOptionals(ast_children)

		if not has_optionals then
			if VisitorChildrenAreTrivial(map) then
				return sum(map :: { [string | number]: number })
			end

			local alpha = struct_len
			local optimized_map: { [string | number]: SizeCalcFn<unknown> } = {}
			for i, v in map do
				if typeof(v) == "number" then
					alpha += v
				else
					optimized_map[i] = v
				end
			end

			return function(t: { [string | number]: unknown })
				local s = alpha
				for i, v in optimized_map do
					s += v(t[i])
				end

				return s
			end
		else
			local optionals: { [string | number]: SizeCalcFn<unknown> | number } = { }
			for i,v in ast_children do
				if v.Attributes.optional then
					local lhs = v.Value[1].Value :: string | number
					optionals[lhs] = map[lhs]
				end
			end

			local alpha = 0
			local optimized_map: { [string | number]: SizeCalcFn<unknown> | number } = { }
			for i,v in map do
				if typeof(v) == "number" then
					if optionals[i] then
						optimized_map[i] = v
					else
						alpha += v
					end
				else
					optimized_map[i] = v
				end
			end

			local bytes_per_key = bytes_to_store_value(#ast_children)

			return function(t: { [string | number]: unknown })
				local keys = count_table_keys(t)
				local s = alpha + keys + bytes_to_store_dynamic_size(keys)

				for i,v in t do
					s += bytes_per_key

					local calc = optimized_map[i]
					if typeof(calc) == "number" then
						s += calc
					elseif typeof(calc) == "function" then
						s += calc(v)
					end
				end

				return s
			end
		end
	end,
	vector3 = function(self, node)
		return sum(VisitorCollectChildren(self, node))
	end,
	cframe = function(self, node)
		return sum(VisitorCollectChildren(self, node)) + 6
	end,
	player = function(self, node)
		return 8
	end
}

-- Serialize/deserialize visitors assume the AST has not been mutated between each-others visits
-- The order of for..in loops needs to be the same for these visitors
-- While the order is undefined, it is consistent as long as the table being iterated is not mutated
type WriterFn<V> = (V, buffer, number) -> number
type SerializeVisitor = ValidVisitor<
	SerializeVisitor,
	(...any) -> buffer,
	WriterFn<number>,
	WriterFn<string>,
	WriterFn<number>,
	WriterFn<string>,
	WriterFn<{ string }>,
	WriterFn<{ unknown }>,
	WriterFn<{ unknown }>,
	WriterFn<Vector3>,
	WriterFn<number>,
	(unknown, unknown, buffer, number) -> number,
	WriterFn<{ [unknown]: unknown }>,
	WriterFn<{ [unknown]: unknown }>,
	WriterFn<CFrame>,
	WriterFn<Player>
>

local SerializeVisitor: SerializeVisitor = {
	root = function(self, node)
		local sizes = ASTNodeAccept(node, SizeCalcVisitor)

		local procedures = VisitorCollectChildren(self, node)

		local function serialize_args(...)
			local args = { ... }
			local cursor = 0

			local buffer_size = 0
			for i, v in args do
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
	type_literal = function(self, node)
		return writers[terminal_to_idx[node.Value]]
	end,
	string_literal = function(self, node)
		local str = node.Value
		return function(_, b: buffer, idx: number)
			local len = string.len(str)
			local s = write_size_specifier(len, b, idx)

			buffer.writestring(b, idx + s, str, len)

			return len + s
		end
	end,
	number_literal = function(self, node)
		return writers[terminal_to_idx[node.Extra]]
	end,
	string = function(self, node)
		return function(t: string, b: buffer, idx: number)
			local len = string.len(t)
			local s = write_size_specifier(len, b, idx)

			buffer.writestring(b, idx + s, t, len)

			return len + s
		end
	end,
	size_specifier = function(self, node)
		return raw_byte_writers[bytes_to_store_value(node.Value)]
	end,
	binding = function(self, node)
		local children = VisitorCollectChildren(self, node)
		local lhs, rhs = children[1], children[2]
		return function(k, v, b: buffer, idx: number)
			local s = 0
			s += lhs(k, b, idx)
			s += rhs(v, b, idx + s)

			return s
		end
	end,
	enum = function(self, node)
		local ast_children = node.Value
		local byte_writer = raw_byte_writers[bytes_to_store_value(#ast_children)]

		local str_to_num = (table.create(#ast_children) :: any) :: { [string]: number }
		for i, v in ast_children do
			str_to_num[v.Value] = i
		end

		local function f(t: { string }, b: buffer, idx: number)
			-- record the actual amount being written to the buffer
			local s = write_size_specifier(#t, b, idx)
			for i, v in t do
				s += byte_writer(str_to_num[v], b, idx + i)
			end

			return s
		end

		return f
	end,
	array = function(self, node)
		local fns = VisitorCollectChildren(self, node)

		local function f(t: {}, b: buffer, idx: number)
			local s = 0

			for i = 1, #t, 1 do
				s += fns[i](t[i], b, idx + s)
			end

			return s
		end

		return f
	end,
	periodic_array = function(self, node)
		local fns = VisitorCollectChildren(self, node)
		local period = #fns

		local function f(t: {}, b: buffer, idx: number)
			local len = #t
			local s = write_size_specifier(len / period, b, idx)

			for i = 0, len - period, period do
				for j = 1, period, 1 do
					s += fns[j](t[i + j], b, idx + s)
				end
			end

			return s
		end
		return f
	end,
	map = function(self, node)
		local children = VisitorCollectChildren(self, node)
		local writer = children[1]

		return function(t: {}, b: buffer, idx: number)
			local len = count_table_keys(t)
			local s = write_size_specifier(len, b, idx)

			for i, v in t do
				s += writer(i, v, b, idx + s)
			end

			return s
		end
	end,
	struct = function(self, node)
		local ast_children = node.Value

		local has_optionals = ASTChildrenHasOptionals(ast_children)

		local lhs_to_rhs_writer = {}
		for i, v in ast_children do
			local lhs_literal = v.Value[1].Value :: number | string
			local rhs_writer = ASTNodeAccept(v.Value[2], self)
			lhs_to_rhs_writer[lhs_literal] = rhs_writer
		end

		if not has_optionals then
			return function(t: {}, b: buffer, idx: number)
				local s = 0
				for i, writer in lhs_to_rhs_writer do
					s += writer(t[i], b, idx + s)
				end

				return s
			end
		else
			local maxn = #ast_children
			local lhs_writer = raw_byte_writers[bytes_to_store_value(maxn)]

			local lhs_index_map: { [number | string]: number } = table.create(maxn)
			for i = 1, maxn, 1 do
				local lhs_literal = ast_children[i].Value[1].Value
				lhs_index_map[lhs_literal] = i
			end

			return function(t: { }, b: buffer, idx: number)
				local keys = count_table_keys(t)
				local s = write_size_specifier(keys, b, idx)

				for i, v in t do
					s += lhs_writer(lhs_index_map[i], b, idx + s)
					s += lhs_to_rhs_writer[i](v, b, idx + s)
				end

				return s
			end
		end
	end,
	vector3 = function(self, node)
		local fns = VisitorCollectChildren(self, node)

		local function f(v: Vector3, b: buffer, idx: number)
			local s = 0
			s += fns[1](v.X, b, idx + s)
			s += fns[2](v.Y, b, idx + s)
			s += fns[3](v.Z, b, idx + s)

			return s
		end

		return f
	end,
	cframe = function(self, node)
		local fns = VisitorCollectChildren(self, node)

		local function f(v: CFrame, b: buffer, idx: number)
			local s = 0
			s += fns[1](v.X, b, idx + s)
			s += fns[2](v.Y, b, idx + s)
			s += fns[3](v.Z, b, idx + s)

			idx += s
			
			local r = 2^15 - 1
			local pitch, yaw, roll = v:ToEulerAnglesYXZ()
			pitch = (pitch / math.pi * r) // 1
			yaw = (yaw / math.pi * r) // 1
			roll = (roll / math.pi * r) // 1
			
			buffer.writei16(b, idx, pitch)
			buffer.writei16(b, idx + 2, yaw)
			buffer.writei16(b, idx + 4, roll)

			return s + 6
		end

		return f
	end,
	player = function(self, node)
		return function(v: Player, b: buffer, idx: number)
			local user_id = v.UserId
			local top = user_id // 2^32
			local bottom = user_id % 2^32

			buffer.writeu32(b, 0, top)
			buffer.writeu32(b, 4, bottom)

			return 8
		end
	end
}

type ReaderFn<V> = (buffer: buffer, idx: number) -> (V, number)
type DeserializeVisitor = ValidVisitor<
	DeserializeVisitor,
	(buffer) -> ...unknown,
	ReaderFn<number>,
	ReaderFn<string>,
	ReaderFn<number>,
	ReaderFn<string>,
	ReaderFn<{ string }>,
	ReaderFn<{ unknown }>,
	ReaderFn<{ unknown }>,
	ReaderFn<Vector3>,
	ReaderFn<number>,
	(buffer, number) -> (unknown, unknown, number),
	ReaderFn<{ [unknown]: unknown }>,
	ReaderFn<{ [unknown]: unknown }>,
	ReaderFn<CFrame>,
	ReaderFn<Player>
>

local DeserializeVisitor: DeserializeVisitor = {
	root = function(self, node)
		local sizes = ASTNodeAccept(node, SizeCalcVisitor)

		local procedures = VisitorCollectChildren(self, node)
		local arg_ct = #sizes

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
	error = function(self, node)
		return nil
	end,
	error_with_children = function(self, node)
		return nil
	end,
	comment = function(self, node)
		return nil
	end,
	type_literal = function(self, node)
		return readers[terminal_to_idx[node.Value]]
	end,
	string_literal = function(self, node)
		return function(b: buffer, idx: number)
			local bsize, s = read_size_specifier(b, idx)

			return buffer.readstring(b, idx + s, bsize), bsize + s
		end
	end,
	number_literal = function(self, node)
		return readers[terminal_to_idx[node.Extra]]
	end,
	string = function(self, node)
		return function(b: buffer, idx: number)
			local bsize, s = read_size_specifier(b, idx)

			return buffer.readstring(b, idx + s, bsize), bsize + s
		end
	end,
	size_specifier = function(self, node)
		return raw_byte_readers[bytes_to_store_value(node.Value)]
	end,
	enum = function(self, node)
		-- also has a size_specifier as the last child
		local ast_children = node.Value
		local byte_size = bytes_to_store_value(#ast_children)
		local byte_reader = raw_byte_readers[byte_size]

		local num_to_str = table.create(#ast_children)
		for i, v in ast_children do
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
	array = function(self, node)
		local fns = VisitorCollectChildren(self, node)
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
	periodic_array = function(self, node)
		local fns = VisitorCollectChildren(self, node)
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
	map = function(self, node)
		local fns = VisitorCollectChildren(self, node)
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
	struct = function(self, node)
		local ast_children = node.Value
		local struct_len = #ast_children

		local map = {}
		for i, v in ast_children do
			local lhs_literal = v.Value[1].Value :: number | string
			local rhs_writer = ASTNodeAccept(v.Value[2], self)
			map[lhs_literal] = rhs_writer
		end

		local has_optionals = ASTChildrenHasOptionals(ast_children)

		if not has_optionals then
			return function(b: buffer, idx: number)
				local s = 0
				local ret: { [number | string]: any } = table.create(struct_len)
				for l, reader in map do
					local r, read = reader(b, idx + s)
					s += read
					ret[l] = r
				end

				return ret, s
			end
		else
			local maxn = #ast_children
			local lhs_reader = raw_byte_readers[bytes_to_store_value(maxn)]

			local lhs_index_map: { [number]: number | string } = table.create(maxn)
			for i = 1, maxn, 1 do
				local lhs_literal = ast_children[i].Value[1].Value
				lhs_index_map[i] = lhs_literal
			end

			return function(b: buffer, idx: number)
				local keys, s = read_size_specifier(b, idx)
				local ret: { [number | string]: unknown } = table.create(s)

				for i = 1, keys, 1 do
					local l_idx, read1 = lhs_reader(b, idx + s)
					local l = lhs_index_map[l_idx]
					s += read1

					local r, read2 = map[l](b, idx + s)
					s += read2

					ret[l] = r
				end

				return ret, s
			end
		end
	end,
	vector3 = function(self, node)
		local fns = VisitorCollectChildren(self, node)

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
	binding = function(self, node)
		local children = VisitorCollectChildren(self, node)
		local lhs, rhs = children[1], children[2]
		return function(b: buffer, idx: number)
			local l, s = lhs(b, idx)
			local r, s2 = rhs(b, idx + s)

			return l, r, s + s2
		end
	end,
	cframe = function(self, node)
		local fns = VisitorCollectChildren(self, node)

		local function f(b: buffer, idx: number)
			local s = 0
			local x, s1 = fns[1](b, idx + s)
			s += s1
			local y, s1 = fns[2](b, idx + s)
			s += s1
			local z, s1 = fns[3](b, idx + s)
			s += s1

			idx += s

			local r = 2^15 - 1
			local pitch = buffer.readi16(b, idx)
			local yaw = buffer.readi16(b, idx + 2)
			local roll = buffer.readi16(b, idx + 4)

			local v = CFrame.new(Vector3.new(x, y, z))
				 * CFrame.fromEulerAnglesYXZ(pitch / r * math.pi, yaw / r * math.pi, roll / r * math.pi)
			
			return v, s + 6
		end

		return f
	end,
	player = function(self, node)
		return function(b: buffer, idx: number)
			local top = buffer.readu32(b, idx)
			local bottom = buffer.readu32(b, idx + 4)
			local id = top * 2^32 + bottom
			local plr = Players:GetPlayerByUserId(id)

			return plr, 8
		end
	end
}

local function str_to_ast(str)
	local tokens, locations = Tokenizer(str)
	local ast = parse_token_stream(tokens)
	return ast, locations
end

function mod.Compile<S, D>(str, annotate_errors: boolean?): (S?, D?, ASTValidRoot?)
	local parsed_ast_root, locations = str_to_ast(str)
	--PrintAST(parsed_ast_root)

	local valid_ast_root: ASTValidRoot? = ASTNodeAccept(parsed_ast_root, ValidateVisitor)
	if not valid_ast_root then
		if annotate_errors then
			PrintErrors(parsed_ast_root, str, locations)
		end

		return
	end

	local serializer = ASTNodeAccept(valid_ast_root, SerializeVisitor)
	local deserializer = ASTNodeAccept(valid_ast_root, DeserializeVisitor)

	return serializer, deserializer, valid_ast_root
end

function mod.PrettyCompile(str, annotate_errors: boolean?)
	local s, d, ast = mod.Compile(str, annotate_errors)
	return {
		Serialize = s,
		Deserialize = d,
		Ast = ast,
	}
end

function mod.PrintAST(ast: ASTParseRoot | ASTValidRoot)
	PrintAST(ast)
end

-- Expose these for testing
mod.write_size_specifier = write_size_specifier
mod.read_size_specifier = read_size_specifier

return mod

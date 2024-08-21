--!strict
--!native

local QUOTE_BYTE = string.byte('"')
local POUND_BYTE = string.byte("#")
local NONE_BYTE = string.byte("")
local NEWLINE_BYTE = string.byte("\n")
local TAB_BYTE = string.byte("\t")
local SPACE_BYTE = string.byte(" ")
local OPAREN_BYTE = string.byte("(")
local CPAREN_BYTE = string.byte(")")
local COMMA_BYTE = string.byte(",")
local COLON_BYTE = string.byte(":")
local LBRACKET_BYTE = string.byte("[")
local RBRACKET_BYTE = string.byte("]")
local AT_BYTE = string.byte("@")

local function is_separator(c: number)
	return c == OPAREN_BYTE
		or c == CPAREN_BYTE
		or c == COMMA_BYTE
		or c == COLON_BYTE
		or c == LBRACKET_BYTE
		or c == RBRACKET_BYTE
		or c == AT_BYTE
end

local function is_whitespace(c: number)
	return c == SPACE_BYTE or c == TAB_BYTE
end

local function get_str_token(str: string, idx: number)
	local end_idx = idx
	local lines_consumed = 0

	local c = string.byte(str, idx, idx)
	if c == QUOTE_BYTE or c == NONE_BYTE then
		return "", idx, idx, lines_consumed
	end

	repeat
		end_idx += 1
		c = string.byte(str, end_idx, end_idx)
		if c == NEWLINE_BYTE then
			lines_consumed += 1
		end
	until c == QUOTE_BYTE or c == NONE_BYTE

	end_idx -= 1

	return string.sub(str, idx, end_idx), idx, end_idx, lines_consumed
end

local function get_token(str: string, idx: number)
	local lines_consumed = 0
	-- Find the first non-white-space character
	local start_idx = idx
	while true do
		while true do
			local c = string.byte(str, start_idx, start_idx)
			if is_whitespace(c) then
				start_idx += 1
			elseif c == NEWLINE_BYTE then
				start_idx += 1
				lines_consumed += 1
			elseif is_separator(c) or c == QUOTE_BYTE then
				-- if it's a separator, the beginning is the end
				return string.char(c), start_idx, start_idx, lines_consumed
			else
				break
			end
		end

		if string.byte(str, start_idx, start_idx) == POUND_BYTE then
			-- Skip comments
			local c
			repeat
				start_idx += 1
				c = string.byte(str, start_idx, start_idx)
			until c == NEWLINE_BYTE or c == NONE_BYTE
		else
			break
		end
	end

	local end_idx = start_idx

	-- if we get here, we have a word-ey thing
	while true do
		local c = string.byte(str, end_idx, end_idx)
		if c == NONE_BYTE then
			break
		elseif is_separator(c) or c == QUOTE_BYTE or is_whitespace(c) or c == NEWLINE_BYTE then
			break
		end

		end_idx += 1
	end

	end_idx -= 1

	local word = string.sub(str, start_idx, end_idx)
	return word, start_idx, end_idx, lines_consumed
end

export type Token = string
export type Tokens = { string }
export type Location = { Line: number, Index: number }
export type TokenLocation = { Start: Location, End: Location }

local function tokenize(str: string)
	local tokens: Tokens = {}
	local token_locations: { TokenLocation } = {}

	local idx = 1
	local line = 1
	while true do
		local token, start_idx, end_idx, lines_consumed = get_token(str, idx)
		if token == "" then
			break
		end

		table.insert(tokens, token)
		idx = end_idx + 1

		-- get_token only consumes leading newlines, so this token is on current line + lines_consumed
		line += lines_consumed
		table.insert(
			token_locations,
			{ Start = { Line = line, Index = start_idx }, End = { Line = line, Index = end_idx } }
		)

		-- Strings are special
		if token == '"' then
			token, start_idx, end_idx, lines_consumed = get_str_token(str, idx)
			table.insert(tokens, token)
			table.insert(token_locations, {
				Start = { Line = line, Index = start_idx },
				End = { Line = line + lines_consumed + lines_consumed, Index = end_idx },
			})
			idx = end_idx + 1
			line += lines_consumed

			local str_end = string.sub(str, idx, idx)
			table.insert(tokens, str_end)
			table.insert(token_locations, { Start = { Line = line, Index = idx }, End = { Line = line, Index = idx } })
			idx += 1
		end
	end

	return tokens, token_locations
end

return tokenize

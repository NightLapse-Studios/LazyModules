--!strict
--!native

local is_separator = require(script.Parent.is_separator)

local function is_token_separator(c: string)
    return is_separator(c) or c == "\""
end

local function is_whitespace(c: string)
    if c == " " or c == "\t" or c == "\n" then
        return true
    end

    return false
end

local function get_str_token(str: string, idx: number)
    local end_idx = idx
    local c = string.sub(str, idx, idx)
    if c == "\"" or c == "" then
        return "", idx
    end

    repeat
        end_idx += 1
        c = string.sub(str, end_idx, end_idx)
    until c == "\"" or c == ""

    end_idx -= 1
    
    return string.sub(str, idx, end_idx), end_idx
end

local function get_token(str: string, idx: number)
    -- Find the first non-white-space character
    local start_idx = idx
    while true do
        local c = string.sub(str, start_idx, start_idx)
        if is_whitespace(c) then
            start_idx += 1
        elseif is_token_separator(c) then
            -- if it's a separator, the beginning is the end
            return c, start_idx
        else
            break
        end
    end

    local end_idx = start_idx

    if string.sub(str, end_idx, end_idx) == "#" then
        -- Handle comments
        local c
        repeat
            end_idx += 1
            c = string.sub(str, end_idx, end_idx) 
        until c == "\n" or c == ""
    else
        -- if we get here, we have a word-ey thing
        while true do
            local c = string.sub(str, end_idx, end_idx)
            if c == "" then
                break
            elseif is_token_separator(c) or is_whitespace(c) then
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

        -- Strings are special
        if token == "\"" then
            token, end_idx = get_str_token(str, idx)
            idx = end_idx + 1
            table.insert(tokens, token)

            local str_end = string.sub(str, idx, idx)
            table.insert(tokens, str_end)
            idx += 1
        end
    end

    return tokens
end

return tokenize

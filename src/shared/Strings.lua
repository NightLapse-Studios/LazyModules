
local formatsToName = {
	["%S"] = "Seconds",
	["%M"] = "Minutes",
	["%H"] = "Hours",
	["%D"] = "Days",
	["%W"] = "Weeks",
	["%m"] = "Months",
	["%Y"] = "Years",
	["%d"] = "Decades",
	["%C"] = "Centuries",
}

local String = {
	SECONDS_IN_A_ = {
		Seconds = 1,
		Minutes = 60,
		Hours = 3600,
		Days = 86400,
		Weeks = 604800,
		Months = 2628000,
		Years = 31540000,
		Decades = 315400000,
		Centuries = 3154000000,
	},
	FORMATS = { -- respective to above
		"%S",
		"%M",
		"%H",
		"%D",
		"%W",
		"%m",
		"%Y",
		"%d",
		"%C",
	},
}

local WordsPerMinute = 200

function iter (tbl, i)
	local e, subStr
	i, e, subStr = string.find(tbl[1], tbl[2], i + 1)
	if i ~= nil then
		return i, e, subStr
	end
end

--[[
	for StartIndex, EndIndex, CaptureSubString in String.FindItterator("aba", "a") do
		print(StartIndex, EndIndex, CaptureSubString)
	end
	--> 1 1 a
		3 3 a
]]
function String.FindItterator(str, find)
	return
		iter,-- the ipairs replacement
		{str, "(" .. find .. ")"},-- the table to itterate accross, I wrap find in parenthesis so that string.find returns the capture.
		0-- the ipairs pointless param.
end

function String.BuildString(Char, Amount)
	return string.rep(Char, Amount)
end

function String.NthCharInString(str, char, n)

	local occur = 0

	for i = 1, #str do 
		if string.sub(str, i,i) == char then
			occur += 1
		end
		if occur == n then
			return i
		end
	end
    return nil
end

function String.AddSpacesToVarName(name)
	local spacesBeforeCaps = string.gsub(name, "(%u)", " %1")
	
	return string.sub(spacesBeforeCaps, 2, -1)-- remove leading space
end

function String.TimeToRead(msg)
	local _, wordCount = string.gsub(msg, "%S+", "")
	local secondsPerWord = 60 / WordsPerMinute
	return wordCount * secondsPerWord
end

-- does not allow for escaping the %
-- you cant do the same pattern more than once
-- a number after the pattern tells how many digits it should try to fill with 0, max 9
-- if clip is a number, then values that are 0 wont be included, the characters that are clip indicies after it will be removed as well
-- but not if there are non 0s before the 0.
-- EX: print(String.FormatTime("%H2:%M2:%S2", 340, 3, 1)) -> 05:40
function String.FormatTime(format, seconds, start, clip)
	local hitNonZero = false
	start = start or #String.FORMATS
	
	seconds = math.floor(seconds)
	for i = start, 1, -1 do
		local pat = String.FORMATS[i]

		local s, e = string.find(format, pat, 1, true)
		if s then
			local name = formatsToName[pat]
			local value = math.floor(seconds / String.SECONDS_IN_A_[name])
			local secs = value * String.SECONDS_IN_A_[name]

			seconds -= secs

			value = tostring(value)
			local fill = string.sub(format, e + 1, e + 1)
			if fill then
				local num = tonumber(fill)
				if num then
					e += 1
					value = String.BuildString("0", num - #value) .. value
				end
			end

			if clip and secs <= 0 and not hitNonZero then
				value = ""
				e += clip
			end
			if secs > 0 then
				hitNonZero = true
			end

			format = string.sub(format, 1, s - 1) .. value .. string.sub(format, e + 1, -1)
		end
	end

	return format
end

local digits = 8 -- will give us (start-finish + 1)^digits possible combos
local start, finish = 33, 125
local chars = finish - start + 1
function String.NumToAlphabetOrder(int)
	-- Takes an int and returns a simple string that can be used to
	-- sort alphabetically in that ints position.
	-- ex with only a and b: 1 => aaa, 2 => aab, 3 => aba
	local ret = ""
	
	-- convert base 10 to base chars number system and convert to ASCII
	while int > 0 do
		local remainder = int%chars
		ret = string.char(start + remainder) .. ret
		int = math.floor(int/chars)
	end
	
	-- add remaining digits so that alphabetical sort works
	local len = #ret
	ret = string.rep(string.char(start-1), digits - len) .. ret
	
	if digits - len < 0 then
		error("Critical Overflow")
	end
	
	return ret
end


local deletionCost = 1
local insertionCost = 0
local subCost = 1

function String.LevenshteinDistance(str1, str2)
	local len1 = string.len(str1)
	local len2 = string.len(str2)
	
        -- quick cut-offs to save time
	if (len1 == 0) then
		return len2
	elseif (len2 == 0) then
		return len1
	elseif (str1 == str2) then
		return 0
	end
	
	local matrix = {}
	local cost = 0
	
        -- initialise the base matrix values
	for i = 0, len1, 1 do
		matrix[i] = {}
		matrix[i][0] = i
	end
	for j = 0, len2, 1 do
		matrix[0][j] = j
	end
	
        -- actual Levenshtein algorithm
	for i = 1, len1, 1 do
		for j = 1, len2, 1 do
			if string.sub(str1, i, i) == string.sub(str2, j, j) then
				cost = 0
			else
				cost = subCost
			end
			
			matrix[i][j] = math.min(matrix[i-1][j] + deletionCost, matrix[i][j-1] + insertionCost, matrix[i-1][j-1] + cost)
		end
	end
	
        -- return the last value - this is the Levenshtein distance
	return matrix[len1][len2]
end

-- DERPRECATED FOR LANGUAGES, SEE: TextManager.lua
--[[ function String.FormatNumber(num)
	local _, _, minus, int, fraction = string.find(tostring(num), "([-]?)(%d+)([.]?%d*)")

	if not int then
		return num
	end
	-- reverse the int-string and append a comma to all blocks of 3 digits
	int = string.gsub(string.reverse(int), "(%d%d%d)", "%1,")

	-- reverse the int-string back remove an optional comma and put the 
	-- optional minus and fractional part back
	return minus .. string.gsub(string.reverse(int), "^,", "") .. fraction
end ]]

function String.NthFind(Search_str, find_str, n, plain)
	local finds = {}
	local original_s, original_f = string.find(Search_str, find_str, 1, plain)
	if original_s then
		finds[#finds + 1] = {original_s, original_f}
		local s,f = original_s, original_f
		while true do
			s,f = string.find(Search_str, find_str, s + 1, plain)
			if s and s ~= original_s then
				finds[#finds + 1] = {s, f}
			else
				break
			end
		end
		local abs = math.abs(n)
		if #finds >= abs then
			if abs == n then
				return finds[n][1], finds[n][2]
			else
				return finds[(#finds + n) + 1][1], finds[(#finds + n) + 1][2]
			end
		end
	end
	return nil
end

function String.Compress(str)
	local Chars = {}
	for i = 32, 126 do
		local ch = string.char(i)
		Chars[ch] = i
	end
  
	local p,c = "",""
	p ..= string.sub(str,1,1)
	local code = 127
	local Increment = 0
	local output_code = {}
	for i = 1, #str do
		c ..= string.sub(str, i, i)
		if Chars[p .. c] then
			p ..= c
		else
			Increment += 1
			output_code[Increment] = tostring(Chars[p])
			Chars[p .. c] = code
			code += 1
			p = c
		end
		c = ""
	end
	output_code[Increment + 1] = tostring(Chars[p])
	return output_code
end

function String.Extract(output_code)
	local Chars = table.create(126 - 32)
	for i = 32, 126 do
		local ch = ""
		ch = string.char(i)
		Chars[i] = ch
	end
	local old = tonumber(output_code[1])
	local new
	local s = Chars[old]
	local c = ""
	c ..= string.sub(s,1,1)
	local count = 127
	local Code = ""
	for i = 2, #output_code do
		new = tonumber(output_code[i])
		if not Chars[new] then
			s = Chars[old]
			s ..= c
		else
			s = Chars[new]
		end
		Code ..= s
		c = ""
		c ..= string.sub(s,1,1)
		Chars[count] = Chars[old] .. c
		count += 1
		old = new
	end
	return Code
end

return String

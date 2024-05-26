--!native
return function(c: string)
    if c == "(" or c == ")" or c == "," or c == ":" or c == "[" or c == "]" then
        return true
    end

    return false
end

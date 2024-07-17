--!strict
--!native

local is_separator = require(script.Parent.is_separator)

local function is_token_separator(c: string)
	return is_separator(c) or c == '"'
end

local function is_whitespace(c: string)
	if c == " " or c == "\t" then
		return true
	end

	return false
end

local function is_newline(c: string)
	return c == "\n"
end

local function get_str_token(str: string, idx: number)
	local end_idx = idx
	local lines_consumed = 0

	local c = string.sub(str, idx, idx)
	if c == '"' or c == "" then
		return "", idx, idx, lines_consumed
	end

	repeat
		end_idx += 1
		c = string.sub(str, end_idx, end_idx)
		if is_newline(c) then
			lines_consumed += 1
		end
	until c == '"' or c == ""

	end_idx -= 1

	return string.sub(str, idx, end_idx), idx, end_idx, lines_consumed
end

local function get_token(str: string, idx: number)
	local lines_consumed = 0
	-- Find the first non-white-space character
	local start_idx = idx
	while true do
		local c = string.sub(str, start_idx, start_idx)
		if is_whitespace(c) then
			start_idx += 1
		elseif is_newline(c) then
			start_idx += 1
			lines_consumed += 1
		elseif is_token_separator(c) then
			-- if it's a separator, the beginning is the end
			return c, start_idx, start_idx, lines_consumed
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
			elseif is_token_separator(c) or is_whitespace(c) or is_newline(c) then
				break
			end

			end_idx += 1
		end
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
			table.insert(
				token_locations,
				{
					Start = { Line = line, Index = start_idx },
					End = { Line = line + lines_consumed + lines_consumed, Index = end_idx },
				}
			)
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

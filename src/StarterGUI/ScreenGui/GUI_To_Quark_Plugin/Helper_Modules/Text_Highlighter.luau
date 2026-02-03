--!strict
--
-- REQUIRES
--
local Blue_Keywords   = require("./Highlighting/Blue_Keywords")
local Gold_Keywords   = require("./Highlighting/Gold_Keywords")
local Pink_Keywords   = require("./Highlighting/Pink_Keywords")
--
-- CONSTANTS
--
local COLOR_BLUE  = Color3.fromRGB(73,  155, 255)
local COLOR_GOLD  = Color3.fromRGB(253, 184, 23)
local COLOR_PINK  = Color3.fromRGB(255, 1,   81)
local COLOR_GREEN = Color3.fromRGB(124, 255, 124)
--
-- LOCAL FUNCTIONS
--
local function color3_to_hex(color: Color3): string
	local r = math.floor(color.R * 255)
	local g = math.floor(color.G * 255)
	local b = math.floor(color.B * 255)
	return string.format("#%02X%02X%02X", r, g, b)
end

local function higlight_text_region(text: string, start_pos: number, end_pos: number, color: Color3): string
	local before = string.sub(text,      (1),              start_pos - 1)
	local target = string.sub(text,      start_pos,        end_pos)
	local after  = string.sub(text,      end_pos + 1)

	local hex_color = color3_to_hex(color)

	return before .. `<font color="{hex_color}">{target}</font>` .. after
end

local function highlight_pattern(text: string, regex_pattern: string, color: Color3): string
	local result = text
	local offset = 0
	local max_iterations = 1000
	local iteration = 1
	
	while (iteration < max_iterations) do
		local start_pos, end_pos = string.find(result, regex_pattern, offset, false)
		
		if (start_pos == nil) then
			break
		end

		result = higlight_text_region(result, start_pos, end_pos :: number, color)

		-- Adjust offset for next search
		local len = string.len(`<font color="{color3_to_hex(color)}"></font>`)
		local highlighted_length = len + ((end_pos or text:len()) - start_pos + 1)
		offset = start_pos + highlighted_length
		
		iteration += 1
	end

	return result
end

local function highlight_keywords(text: string, keywords: {[string]: boolean}, color: Color3): string
	local result = text

	-- Sort keywords by length (longest first) to avoid partial matches
	local sorted_keywords = {} :: {string}
	for keyword in keywords do
		table.insert(sorted_keywords, keyword)
	end
	
	table.sort(sorted_keywords, function(a: string, b: string)
		local a_len = a:len()
		local b_len = b:len()
		
		return (a_len > b_len)
	end)

	for _, keyword in ipairs(sorted_keywords) do
		-- Pattern to match whole words only
		local pattern = "%f[%a_]" .. keyword .. "%f[^%a_]"
		result = highlight_pattern(result, pattern, color)
	end

	return result
end

local function highlight_numbers(text: string): string
	-- Pattern for numbers (including decimals and scientific notation)
	local patterns = {
		"%-?%d+%.%d+[eE][%+%-]?%d+",  -- Scientific notation
		"%-?%d+[eE][%+%-]?%d+",       -- Scientific notation without decimal
		"%-?%d+%.%d+",                -- Decimal numbers
		"%-?%d+",                     -- Integers
	}

	local result = text
	for _, pattern in ipairs(patterns) do
		result = highlight_pattern(result, pattern, COLOR_GOLD)
	end

	return result
end
--
-- MODULE DEFINITION 
--
local Text_Highlighter = {}

function Text_Highlighter.Highlight(text: string): string
	if text == "" then
		return ""
	end

	local highlighted = text

	highlighted = highlight_numbers(highlighted)

	highlighted = highlight_keywords(highlighted, Pink_Keywords, COLOR_PINK)
	highlighted = highlight_keywords(highlighted, Blue_Keywords, COLOR_BLUE)
	highlighted = highlight_keywords(highlighted, Gold_Keywords, COLOR_GOLD)

	return highlighted
end
--
-- RETURN VALUE
--
return Text_Highlighter
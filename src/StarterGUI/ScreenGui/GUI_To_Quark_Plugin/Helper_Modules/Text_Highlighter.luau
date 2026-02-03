--!strict
--
-- REQUIRES
--
local Blue_Keywords   = require("./Highlighting/Blue_Keywords")
local Gold_Keywords   = require("./Highlighting/Gold_Keywords")
local Pink_Keywords   = require("./Highlighting/Pink_Keywords")
local Yellow_Keywords = require("./Highlighting/Yellow_Keywords")
--
-- CONSTANTS
--
local COLOR_BLUE   = Color3.fromRGB(73,  155, 255)
local COLOR_GOLD   = Color3.fromRGB(253, 184, 23)
local COLOR_PINK   = Color3.fromRGB(255, 1,   81)
local COLOR_GREEN  = Color3.fromRGB(124, 255, 124)
local COLOR_YELLOW = Color3.fromRGB(251, 255, 25)
--
-- LOCAL TYPES
--
type Pattern_Occurrence = {
    start_pos: number,
    end_pos:   number,
    color:     Color3
}
--
-- LOCAL FUNCTIONS
--
local function color3_to_hex(color: Color3): string
    local r = math.floor(color.R * 255)
    local g = math.floor(color.G * 255)
    local b = math.floor(color.B * 255)
    return string.format("#%02X%02X%02X", r, g, b)
end

local function find_pattern_occurrences(text:          string,
										regex_pattern: string,
										color:         Color3)
										
									   : {Pattern_Occurrence}
									   
    local occurrences = {}
    local offset = 1
    local max_iterations = 1000
    local iteration = 1
    
    while (iteration < max_iterations) do
        local start_pos, end_pos = string.find(text, regex_pattern, offset, false)
        
        if (start_pos == nil) then
            break
        end

        table.insert(occurrences, {
            start_pos = start_pos,
            end_pos   = end_pos,
            color     = color
        } :: Pattern_Occurrence)

        offset = end_pos + 1
        iteration += 1
    end

    return occurrences
end

local function find_keyword_occurrences(text:      string,
										keywords: {string},
										color:     Color3)
										
									   : {Pattern_Occurrence}
    local occurrences = {}

    -- Sort keywords by length (longest first) to avoid partial matches
    local sorted_keywords = {} :: {string}
    for _, keyword in keywords do
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
        local keyword_occurrences = find_pattern_occurrences(text, pattern, color)
        
        for _, occurrence in ipairs(keyword_occurrences) do
            table.insert(occurrences, occurrence)
        end
    end

    return occurrences
end

local function find_number_occurrences(text: string): {Pattern_Occurrence}
    local occurrences = {}
    local patterns = {
        {pattern = "%-?%d+%.%d+[eE][%+%-]?%d+",      color = COLOR_GOLD},  -- Scientific notation
        {pattern = "%-?%d+[eE][%+%-]?%d+",           color = COLOR_GOLD},  -- Scientific notation without decimal
		{pattern = "(%d+%.%d+)",                     color = COLOR_GOLD},  -- Decimal numbers
		{pattern = "(%b(?<!0[bx])%d+(%d|_){0,}%b)",  color = COLOR_GOLD},  -- Integers
		{pattern = "(0b(1|0)+(?!%d))",               color = COLOR_GOLD},  -- Binary
		{pattern = "(0x%w+)",                        color = COLOR_GOLD}   -- Hexadecimal
    }

    for _, pattern_info in ipairs(patterns) do
        local pattern_occurrences = find_pattern_occurrences(text, pattern_info.pattern, pattern_info.color)
        
        for _, occurrence in ipairs(pattern_occurrences) do
            table.insert(occurrences, occurrence)
        end
    end

    return occurrences
end

local function process_occurrences_from_end(text: string, all_occurrences: {Pattern_Occurrence}): string
    -- Sort occurrences by start position (ascending)
    table.sort(all_occurrences, function(a: Pattern_Occurrence, b: Pattern_Occurrence)
        return a.start_pos < b.start_pos
    end)

    -- Process from end to start
    for i = #all_occurrences, 1, -1 do
        local occurrence = all_occurrences[i]
        
        local before = string.sub(text, 1, occurrence.start_pos - 1)
        local target = string.sub(text, occurrence.start_pos, occurrence.end_pos)
        local after  = string.sub(text, occurrence.end_pos + 1)
        
        local hex_color = color3_to_hex(occurrence.color)
        
        text = before .. `<font color="{hex_color}">{target}</font>` .. after
    end

    return text
end
--
-- MODULE DEFINITION 
--
local Text_Highlighter = {}

function Text_Highlighter.Highlight(text: string): string
    if text == "" then
        return ""
    end

    -- Collect all pattern occurrences first
    local all_occurrences = {}
  
    
    -- Find keyword occurrences
    local pink_occurrences = find_keyword_occurrences(text, Pink_Keywords, COLOR_PINK)
    local blue_occurrences = find_keyword_occurrences(text, Blue_Keywords, COLOR_BLUE)
    local gold_occurrences = find_keyword_occurrences(text, Gold_Keywords, COLOR_GOLD)

	-- Find number occurrences
	local number_occurrences = find_number_occurrences(text)
	for _, occurrence in ipairs(number_occurrences) do
		table.insert(all_occurrences, occurrence)
	end
	
    for _, occurrence in ipairs(pink_occurrences) do
        table.insert(all_occurrences, occurrence)
    end
    
    for _, occurrence in ipairs(blue_occurrences) do
        table.insert(all_occurrences, occurrence)
    end
    
    for _, occurrence in ipairs(gold_occurrences) do
        table.insert(all_occurrences, occurrence)
    end

    -- Remove any duplicate/overlapping occurrences (keep only one occurrence per position)
    -- We'll sort by start position and remove overlaps
    table.sort(all_occurrences, function(a: Pattern_Occurrence, b: Pattern_Occurrence)
        if a.start_pos == b.start_pos then
            return a.end_pos > b.end_pos  -- Prefer longer matches for same start position
        end
        return a.start_pos < b.start_pos
    end)
    
    local filtered_occurrences = {}
    local last_end = 0
    
    for _, occurrence in all_occurrences do
        if occurrence.start_pos > last_end then
            table.insert(filtered_occurrences, occurrence)
            last_end = occurrence.end_pos
        end
    end

    -- Process from end to start
    return process_occurrences_from_end(text, filtered_occurrences)
end
--
-- RETURN VALUE
--
return Text_Highlighter
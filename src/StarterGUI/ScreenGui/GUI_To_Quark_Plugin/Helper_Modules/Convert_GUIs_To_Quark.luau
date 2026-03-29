--!strict
--
-- SERVICES
--
local Reflection_Service = game:GetService("ReflectionService")
--
-- LOCAL TYPES
--
type GUI_Class_Name          = string
type GUI_Class_Property_Name = string

type DEPRECATED_PROPERTY     = "DEPRECATED"

type GUI_Class_Properties_Map = {
	[GUI_Class_Name]: {
		Properties: {
			[GUI_Class_Property_Name]: DEPRECATED_PROPERTY | any
		},
		Child_Classes: {GUI_Class_Name}
	}
}
--
-- CONSTANTS
--
local DEPRECATED_PROPERTY_NAME: DEPRECATED_PROPERTY = "DEPRECATED"
--
-- LOCAL VARIABLES
--
local Default_GUI_Class_Properties = {} :: GUI_Class_Properties_Map
--
-- LOCAL FUNCTIONS
--
local function Get_Top_Level_Instances(input_instances: {Instance})
    --
    -- Create a set of all instances for quick lookup.
    --
    local instance_lookup: {[Instance]: boolean} = {}
    for _, instance in input_instances do
        instance_lookup[instance] = true
    end
    --
    -- Collect instances with no parent in the set.
    --
    local top_level_instances = {}
    for _, instance in input_instances do
        local parent = instance.Parent
        --
        -- Instance has a parent, and it's in the input instances set? => Continue.
        --
        if ((parent ~= nil) and (instance_lookup[parent] ~= nil)) then
            continue
        end

        table.insert(top_level_instances, instance)
    end

    return top_level_instances
end

local function Prepare_GUI_Class_Properties_Table(gui_class_name: string)
	--
	-- Class already exists in the table? => return
	--
	if (Default_GUI_Class_Properties[gui_class_name] ~= nil) then
		return
	end

	local class_dump = Reflection_Service:GetClass(gui_class_name)
	--
	-- Invalid class name? => return.
	--
	if (class_dump == nil) then
		return
	end
	--
	-- Valid class name?
	--         =>
	-- Add all properties of this class
	-- to Default_GUI_Class_Properties, and call this function
	-- with all child class names to recursively construct
	-- the whole Default_GUI_Class_Properties table.
	--
	local properties_dump = Reflection_Service:GetPropertiesOfClass(gui_class_name)
	local properties_table = {}

	pcall(function()
		local instance_with_default_property_values = Instance.new(gui_class_name)

		for _, property in properties_dump do
			--
			-- Deprecated property? => Set value to "DEPRECATED" and continue.
			--
			if (property.Display ~= nil) then
				if (property.Display.DeprecationMessage ~= nil) then
					properties_table[property.Name] = DEPRECATED_PROPERTY_NAME
					instance_with_default_property_values:Destroy()
					continue
				end
			end
			--
			-- Normal property? => Copy the value from instance_with_default_property_values.
			--
			local success, value = pcall(function()
				return instance_with_default_property_values[property.Name]
			end)
			if (success == true) then
				properties_table[property.Name] = value
			else
				properties_table[property.Name] = true
			end

			instance_with_default_property_values:Destroy()
		end
	end)

	Default_GUI_Class_Properties[gui_class_name] = {
		Child_Classes = class_dump.Subclasses or {},
		Properties    = properties_table
	}

	if (class_dump.Subclasses == nil) then
		return
	end

	for key, child_class in class_dump.Subclasses do
		Prepare_GUI_Class_Properties_Table(child_class)
	end
end

local function Parse_Font_String(input: string): string?
    -- Extract the content between the braces
    local inside = input:match("Font%s*{(.*)}")
    if not inside then
        return nil
    end

    -- Parse key-value pairs separated by commas
    local pairs = {}
    for pair in inside:gmatch("[^,]+") do
        local key, value = pair:match("(%w+)%s*=%s*(.*)")
        if key and value then
            key = key:gsub("%s", "")                     -- remove whitespace from key
            value = value:gsub("^%s*(.-)%s*$", "%1")     -- trim value
            pairs[key] = value
        end
    end

    -- Retrieve the required fields
    local family = pairs["Family"]
    local weight = pairs["Weight"]
    local style  = pairs["Style"]

    if not (family and weight and style) then
        return nil
    end

    -- Format the output string
    return string.format(
        'Font.new("%s", Enum.FontWeight.%s, Enum.FontStyle.%s)',
        family, weight, style
    )
end

--
-- Round a number to three decimal places.
--
local function Rnd(value: number)
    return (math.round(value * 1000) / 1000)
end

local function Format_Value_For_Quark_Code(value: any, propertyName: string): string
	local value_type = typeof(value)
	local is_color_property = propertyName:lower():find("color") ~= nil
	--
	-- Switch-case analog in lua is just a table of functions.
	--
	local type_handlers = {
        string = function(val: string)
            -- Check if string is a font face
            local font_str = Parse_Font_String(val)
            if (font_str ~= nil) then
                return font_str
            end
			-- Check if string contains only numbers (with optional decimal)
            if val:match("^[%d%.]+$") then
                local num_val = tonumber(val) or 0
                return `{Rnd(num_val)}`
			else
				return `"{val}"`
			end
		end,

		number = function(val: number)
			return `{Rnd(val)}`
		end,

		boolean = function(val)
			return val and "true" or "false"
		end,

		UDim = function(val)
            return `UDim.new({Rnd(val.Scale)}, {Rnd(val.Offset)})`
		end,

		UDim2 = function(val)
            return `UDim2.new({Rnd(val.X.Scale)}, {Rnd(val.X.Offset)}, {Rnd(val.Y.Scale)}, {Rnd(val.Y.Offset)})`
		end,

		Vector2 = function(val)
			return `Vector2.new({Rnd(val.X)}, {Rnd(val.Y)})`
		end,

		Vector3 = function(val)
			if is_color_property then
                return `Color3.new({Rnd(val.X)}, {Rnd(val.Y)}, {Rnd(val.Z)})`
			else
                return `Vector3.new({Rnd(val.X)}, {Rnd(val.Y)}, {Rnd(val.Z)})`
			end
		end,

		Color3 = function(val)
            return `Color3.new({Rnd(val.R)}, {Rnd(val.G)}, {Rnd(val.B)})`
		end,

		BrickColor = function(val)
			return `BrickColor.new("{val.Name}")`
		end,

		EnumItem = function(val)
			return `Enum.{tostring(val)}`
		end,

		table = function(val)
			-- Handle specific numeric table formats
			if #val == 2 and typeof(val[1]) == "number" and typeof(val[2]) == "number" then
                val[1] = Rnd(val[1])
                val[2] = Rnd(val[2])
				return `UDim.new({val[1]}, {val[2]})`

			elseif #val == 4 and typeof(val[1]) == "number" and typeof(val[2]) == "number"
				and typeof(val[3]) == "number" and typeof(val[4]) == "number" then
                val[1] = Rnd(val[1])
                val[2] = Rnd(val[2])
                val[3] = Rnd(val[3])
                val[4] = Rnd(val[4])
				return `UDim2.new({val[1]}, {val[2]}, {val[3]}, {val[4]})`

			elseif #val == 3 and typeof(val[1]) == "number" and typeof(val[2]) == "number"
				and typeof(val[3]) == "number" then
                val[1] = Rnd(val[1])
                val[2] = Rnd(val[2])
                val[3] = Rnd(val[3])
				if is_color_property then
					return `Color3.new({val[1]}, {val[2]}, {val[3]})`
				else
					return `Vector3.new({val[1]}, {val[2]}, {val[3]})`
				end
			else
				-- Generic table: concatenate elements
				local parts = {}
				for _, v in ipairs(val) do
					table.insert(parts, tostring(v))
				end
				return table.concat(parts, ", ")
			end
		end
	}

	-- Get handler for the type
	local handler = type_handlers[value_type]

	if handler then
		return handler(value)
	else
		-- Fallback for unhandled types
		local string_value = tostring(value)
		if string_value:match("^[%d%.]+$") then
			return string_value
		else
			return `"{string_value}"`
		end
	end
end

--
-- Collects all non-default, non-deprecated properties of a gui_instance
-- into a sorted array of {key, value} pairs.
--
local function Collect_Sorted_Properties(gui_instance: GuiBase, class: string): {{key: string, value: any}}
	local class_dump = Default_GUI_Class_Properties[class]
	local props = {}

	for key, default_val in class_dump.Properties do
		--
		-- Deprecated property? => Skip.
		--
		if (default_val == DEPRECATED_PROPERTY_NAME) then
			continue
		end

		local success, instance_val = pcall(function()
			return (gui_instance :: any)[key]
		end)
		if (not success) then
			continue
		end
		--
		-- Property has the default value? => Skip.
		--
		if (instance_val == default_val) then
			continue
		end

		table.insert(props, {key = key, value = instance_val})
	end
	--
	-- Sort alphabetically so the output is deterministic and readable.
	--
	table.sort(props, function(a, b)
		return a.key < b.key
	end)

	return props
end

--
-- Recursively converts a GuiBase instance and all its GuiBase descendants
-- into Quark code.
--
-- depth controls the indentation level:
--   depth = 0  =>  top-level, emits  `local Name = New "Class" { ... }`
--   depth > 0  =>  child node, emits  `<indent>New "Class" { Name = "...", ... }`
--
-- Children of the instance are placed inside a `Children = { ... }` block.
-- The child nodes are indented by depth + 2 (one extra level for inner content
-- of the current node, one more for being inside the Children block).
--
local function GUI_Instance_To_Quark_Code(gui_instance: GuiBase, depth: number?): string
	depth = depth or 0

	local class        = gui_instance.ClassName
	local indent       = string.rep("\t", depth)
	local inner_indent = string.rep("\t", depth + 1)

	local class_dump = Default_GUI_Class_Properties[class]
	if (class_dump == nil) then
		warn(`Class dump for {class} wasn't found. Report this to the plugin developers.`)
		return ""
	end

	local props = Collect_Sorted_Properties(gui_instance, class)

	--
	-- Build the opening line.
	-- Top-level nodes get a variable declaration; child nodes get an inline New.
	--
	local code = ""

	if (depth == 0) then
		code = `local {gui_instance.Name} = New "{class}" \{\n`
	else
		--
		-- Child node: start inline, always include Name first so the
		-- reader can immediately identify what this node is.
		--
		code = `{indent}New "{class}" \{\n`
		code = code .. `{inner_indent}Name = "{gui_instance.Name}",\n`
	end

	--
	-- Emit sorted properties.
	-- Skip Name for child nodes since we already wrote it above.
	--
	for _, prop in props do
		if ((depth > 0) and (prop.key == "Name")) then
			continue
		end

		local formatted = Format_Value_For_Quark_Code(prop.value, prop.key)
		code = code .. `{inner_indent}{prop.key} = {formatted},\n`
	end

	--
	-- Collect GuiBase children and emit them inside a Children block.
	--
	local gui_children: {GuiBase} = {}
	for _, child in gui_instance:GetChildren() do
		if child:IsA("GuiBase") then
			table.insert(gui_children, child :: GuiBase)
		end
	end

	if (#gui_children > 0) then
		code = code .. `{inner_indent}Children = \{\n`

		for _, child in gui_children do
			--
			-- depth + 2: +1 for inner content of this node, +1 for being
			-- inside the Children = { } block.
			--
			local child_code = GUI_Instance_To_Quark_Code(child, depth + 2)
			code = code .. child_code .. ",\n"
		end

		code = code .. `{inner_indent}\},\n`
	end

	code = code .. `{indent}\}`

	return code
end
--
-- MODULE OPERATION
--
Prepare_GUI_Class_Properties_Table("GuiBase2d")
--
-- RETURN VALUE
--
-- Returning a table so Plugin_GUI can also access Get_Top_Level_Instances
-- without duplicating it.
--
return {
	Convert          = GUI_Instance_To_Quark_Code,
	Get_Top_Level    = Get_Top_Level_Instances,
}
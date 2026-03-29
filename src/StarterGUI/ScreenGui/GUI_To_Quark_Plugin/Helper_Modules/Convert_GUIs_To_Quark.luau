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
				return val
			else
				return `"{val}"`
			end
		end,

		number = tostring,

		boolean = function(val)
			return val and "true" or "false"
		end,

		UDim = function(val)
			return `UDim.new({val.Scale}, {val.Offset})`
		end,

		UDim2 = function(val)
			return `UDim2.new({val.X.Scale}, {val.X.Offset}, {val.Y.Scale}, {val.Y.Offset})`
		end,

		Vector2 = function(val)
			return `Vector2.new({val.X}, {val.Y})`
		end,

		Vector3 = function(val)
			if is_color_property then
				return `Color3.new({val.X}, {val.Y}, {val.Z})`
			else
				return `Vector3.new({val.X}, {val.Y}, {val.Z})`
			end
		end,

		Color3 = function(val)
			return `Color3.new({val.R}, {val.G}, {val.B})`
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
				return `UDim.new({val[1]}, {val[2]})`

			elseif #val == 4 and typeof(val[1]) == "number" and typeof(val[2]) == "number"
				and typeof(val[3]) == "number" and typeof(val[4]) == "number" then
				return `UDim2.new({val[1]}, {val[2]}, {val[3]}, {val[4]})`

			elseif #val == 3 and typeof(val[1]) == "number" and typeof(val[2]) == "number"
				and typeof(val[3]) == "number" then
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

local function GUI_Instance_To_Quark_Code(gui_instance: GuiBase, recursion: number?): string
	local class = gui_instance.ClassName
	recursion = recursion or 1

	local quark_code = `local {gui_instance.Name} = New "{class}" \{`

	local class_dump = Default_GUI_Class_Properties[class]
	if (class_dump == nil) then
		warn(`Class dump for {class} wan't found. Report this to the plugin developers.`)
		return ""
	end

	quark_code = `{quark_code}\n-- Properties start\n`

	for key, property in Default_GUI_Class_Properties[class].Properties do
		local success, instance_property_value = pcall(function()
			return gui_instance[key]
		end)
		if (not success) then
			continue
		end
		--
		-- Gui instance's property has the default value? => Skip this property.
		--
		if (instance_property_value == property) then
			continue
		end
		--
		-- Developer is using a deprecated property? => We don't care, skip this property.
		--
		if (property == DEPRECATED_PROPERTY_NAME) then
			print(`Property {key} of class {class} in instance {gui_instance.Name} is deprecated. Skipping it.`)
			continue
		end

		-- Format the value for Quark
		local formatted_value = Format_Value_For_Quark_Code(instance_property_value, key)

		for i = 1, recursion do
			quark_code = quark_code .. "\t"
		end
		quark_code = `{quark_code} {key} = {formatted_value},\n`
	end
	quark_code = `{quark_code}\n-- Properties end`
	quark_code = `{quark_code}\n}`

	return quark_code
end
--
-- MODULE OPERATION
--
Prepare_GUI_Class_Properties_Table("GuiBase2d")
--
-- RETURN VALUE
--
return GUI_Instance_To_Quark_Code
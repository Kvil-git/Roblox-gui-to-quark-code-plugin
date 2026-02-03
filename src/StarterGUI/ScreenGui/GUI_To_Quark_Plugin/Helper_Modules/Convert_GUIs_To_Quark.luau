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

local function formatValueForQuark(value: any, propertyName: string): string
	local valueType = typeof(value)

	if valueType == "string" then
		-- Check if the string contains only numbers (possibly with decimal point)
		if value:match("^[%d%.]+$") then
			return value
		else
			-- Wrap non-numeric strings in quotes
			return `"{value}"`
		end

	elseif valueType == "number" then
		return tostring(value)

	elseif valueType == "boolean" then
		return value and "true" or "false"

	elseif valueType == "UDim" then
		return `UDim.new({value.Scale}, {value.Offset})`

	elseif valueType == "UDim2" then
		return `UDim2.new({value.X.Scale}, {value.X.Offset}, {value.Y.Scale}, {value.Y.Offset})`

	elseif valueType == "Vector2" then
		return `Vector2.new({value.X}, {value.Y})`

	elseif valueType == "Vector3" then
		-- Check if property name contains "Color" to determine if it should be Color3
		if propertyName:lower():find("color") then
			return `Color3.new({value.X}, {value.Y}, {value.Z})`
		else
			return `Vector3.new({value.X}, {value.Y}, {value.Z})`
		end

	elseif valueType == "Color3" then
		return `Color3.new({value.R}, {value.G}, {value.B})`

	elseif valueType == "BrickColor" then
		return `BrickColor.new("{value.Name}")`

	elseif valueType == "EnumItem" then
		-- Handle Enum items (like Font enums, etc.)
		return `Enum.{tostring(value)}`

	elseif valueType == "table" then
		-- Handle tables (like for certain properties)
		if #value == 2 and typeof(value[1]) == "number" and typeof(value[2]) == "number" then
			-- Two numbers in a table - likely UDim
			return `UDim.new({value[1]}, {value[2]})`
		elseif #value == 4 and typeof(value[1]) == "number" and typeof(value[2]) == "number" 
			and typeof(value[3]) == "number" and typeof(value[4]) == "number" then
			-- Four numbers in a table - likely UDim2
			return `UDim2.new({value[1]}, {value[2]}, {value[3]}, {value[4]})`
		elseif #value == 3 and typeof(value[1]) == "number" and typeof(value[2]) == "number" 
			and typeof(value[3]) == "number" then
			-- Three numbers - check property name
			if propertyName:lower():find("color") then
				return `Color3.new({value[1]}, {value[2]}, {value[3]})`
			else
				return `Vector3.new({value[1]}, {value[2]}, {value[3]})`
			end
		else
			-- Generic table handling
			local parts = {}
			for i, v in ipairs(value) do
				table.insert(parts, tostring(v))
			end
			return table.concat(parts, ", ")
		end

	else
		-- Fallback for other types
		local strValue = tostring(value)
		-- Check if it looks like a number
		if strValue:match("^[%d%.]+$") then
			return strValue
		else
			return `"{strValue}"`
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
		local formatted_value = formatValueForQuark(instance_property_value, key)

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
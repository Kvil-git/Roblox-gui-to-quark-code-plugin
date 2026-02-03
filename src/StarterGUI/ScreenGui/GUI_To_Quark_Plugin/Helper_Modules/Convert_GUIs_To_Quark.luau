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

local function GUI_Instance_To_Quark_Code(gui_instance: GuiBase, recursion: number?): string
	local class = gui_instance.ClassName
	recursion = recursion or 1

	local quark_code = `local {gui_instance.Name} = New "{class}" \{`

	local class_dump = Default_GUI_Class_Properties[class]
	if (class_dump == nil) then
		warn(`Class dump for {class} wan't found. Report this to the plugin developers.`)
		return ""
	end

	quark_code = `{quark_code}\n--Propeties start\n`

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

		for i = 1, recursion do
			quark_code = quark_code .. "\t"
		end
		quark_code = `{quark_code} {key} = {instance_property_value},\n`
	end
	quark_code = `{quark_code}\n--Propeties end`
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
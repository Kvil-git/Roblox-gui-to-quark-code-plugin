--!strict
--
-- LOCAL FUNCTIONS
--
local function Create_Toolbar(dock_widget_GUI: DockWidgetPluginGui,
							  toolbar:         PluginToolbar
							  
                             ): {PluginToolbarButton}
	local buttons = {}
	
	local plugin_button = toolbar:CreateButton (
		"GUI To Quark",                 -- Text that will appear below button.
		"Open \\GUI To Quark\\ menu",   -- Text that will appear if you hover your mouse on button.
		"rbxassetid://106091908857038"  -- Button icon.
	)
	
	table.insert(buttons, plugin_button)

	return buttons
end
--
-- MODULE DEFINITION 
--
local Plugin_Toolbar = {}

function Plugin_Toolbar.Initialize(dock_widget_GUI: DockWidgetPluginGui, toolbar: PluginToolbar)
	Create_Toolbar(dock_widget_GUI, toolbar)
end
--
-- RETURN VALUE
--
return Plugin_Toolbar
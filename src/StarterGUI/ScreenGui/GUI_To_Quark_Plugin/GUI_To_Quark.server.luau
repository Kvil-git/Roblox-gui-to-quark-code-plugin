--!strict
--
-- ASSERTS
--
assert(plugin, "This script must be run from a plugin!")
--
-- REQUIRES
--
local Plugin_GUI     = require("./Helper_Modules/Plugin_GUI")
local Plugin_Toolbar = require("./Helper_Modules/Plugin_Toolbar")
--
-- VARIABLES
--
local dock_widget_info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, true, true)
local dock_widget_GUI
local plugin_toolbar
--
-- PLUGIN DEFINITION 
--
local Logger_Plugin_Script = {}
--
-- PLUGIN OPERATION
--
--
-- Create the plugin's GUI and set it's title.
--
plugin_toolbar        =  plugin:CreateToolbar("GUI_To_Quark")
dock_widget_GUI       =  plugin:CreateDockWidgetPluginGuiAsync("GUI_To_Quark_Pluguin_ID", dock_widget_info)
dock_widget_GUI.Title = "GUI To Quark"
--
-- Initialize the plugin's GUI.
--
Plugin_Toolbar  .Initialize  (dock_widget_GUI, plugin_toolbar)
Plugin_GUI      .Initialize  (dock_widget_GUI)
--
-- RETURN VALUE
--
return Logger_Plugin_Script
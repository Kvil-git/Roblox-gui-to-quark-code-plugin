--!strict
--
-- SERVICES
--
local Selection = game:GetService("Selection")
--
-- REQUIRES
--
local Helper_Functions  = require("./Helper_Functions")
local GUI_To_Quark_Code = require("./Convert_GUIs_To_Quark")
local Text_Highlighter  = require("./Text_Highlighter")
--
-- CONSTANTS
--
local Main_Frame = script.Parent.Parent.Main_Frame
local Text_Box   = Main_Frame.Code_Scrolling_Frame.Code_Textbox
--
-- LOCAL VARIABLES
--
local is_syntax_highlighted = (false)
--
-- LOCAL FUNCTIONS
--
local function Convert_GUIs_To_Quark()
	local selected_instances = Selection:Get()
	local text = ""
	for key, instance in selected_instances do
		if (instance:IsA("GuiBase") == false) then
			continue
		end

		local instance_quark_code = GUI_To_Quark_Code(instance :: GuiBase)
		text = `{text}\n{instance_quark_code}`
	end

	if (is_syntax_highlighted) then
		-- Apply syntax highlighting to the generated code
		text = Text_Highlighter.Highlight(text)
	end
	
	Text_Box.Text = text
end
--
-- MODULE DEFINITION 	
--
local Plugin_GUI = {}

function Plugin_GUI.Initialize(dock_widget_GUI: DockWidgetPluginGui)
	Main_Frame.Parent = dock_widget_GUI
	Helper_Functions.Sync_Gui_Colors(Main_Frame:GetDescendants())


	local convert_button = Main_Frame.Convertion_Button
	convert_button.MouseButton1Click:Connect(Convert_GUIs_To_Quark)
	
	
	local syntax_higlight_button = Main_Frame.Syntax_Highlight_Button
	syntax_higlight_button.MouseButton1Click:Connect(function()
		is_syntax_highlighted = (not is_syntax_highlighted)
		if (is_syntax_highlighted == true) then
			syntax_higlight_button.BackgroundColor3 = Color3.fromRGB(68, 255, 0)
		else
			syntax_higlight_button.BackgroundColor3 = Color3.fromRGB(62, 62, 62)
		end
		
		Convert_GUIs_To_Quark()
	end)
end
--
-- RETURN VALUE
--
return Plugin_GUI
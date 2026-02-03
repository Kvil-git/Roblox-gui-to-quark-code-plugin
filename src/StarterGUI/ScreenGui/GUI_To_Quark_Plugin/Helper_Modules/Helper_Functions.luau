--!strict
--
-- MODULE DEFINITION 
--
local Helper_Functions = {}

function Helper_Functions.Sync_Gui_Colors(objects: {GuiObject})
	--
    -- set_colors is named with small letters because it's local.
	--
	local function set_colors()
		for _, gui_object in objects do
			--
			-- Sync background color
			--
			pcall(function()
				local studio_theme = settings().Studio.Theme
				gui_object.BackgroundColor3 = studio_theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
			end)
			--
			-- Sync text color
			--
			pcall(function()
				local studio_theme = settings().Studio.Theme
				gui_object.TextColor3 = studio_theme:GetColor(Enum.StudioStyleGuideColor.MainText)
			end)
		end
	end
	--
	-- Run 'set_colors()' function to initially sync colors
	--
	set_colors()
	--
	-- Connect 'ThemeChanged' event to the 'set_colors()' function
	--
	settings().Studio.ThemeChanged:Connect(set_colors)
end
--
-- RETURN VALUE
--
return Helper_Functions
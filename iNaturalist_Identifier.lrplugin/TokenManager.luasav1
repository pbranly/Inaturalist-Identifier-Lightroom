--[[
=====================================================================================
 Script       : TokenManager.lua
 Purpose      : Manage iNaturalist API token within Lightroom plugin
 Author       : Philippe

 Functional Overview:
 Provides a modal interface for entering and saving the iNaturalist API token.
 Handles opening the token generation page in the browser and storing the token
 in Lightroom plugin preferences.

 Key Features:
 - Modal dialog for token input and saving
 - Opens token generation page in browser
 - Saves token persistently via plugin preferences
 - Asynchronous execution for smooth UX
 - Graceful error handling
 - Modular export for integration

 Dependencies:
 - Lightroom SDK: LrPrefs, LrDialogs, LrView, LrTasks
 - Localization via LOC()
 - Platform detection: WIN_ENV, MAC_ENV
=====================================================================================
--]]

-- Import Lightroom SDK modules
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrView    = import "LrView"
local LrTasks   = import "LrTasks"

-- UI factory and plugin preferences
local f     = LrView.osFactory()
local prefs = LrPrefs.prefsForPlugin()

-- Property table for UI binding
local props = { token = prefs.token or "" }

-- Function: openTokenPage
local function openTokenPage()
    local url = "https://www.inaturalist.org/users/api_token"
    LrTasks.startAsyncTask(function()
        local openCommand
        if WIN_ENV then
            openCommand = 'start "" "' .. url .. '"'      -- Windows
        elseif MAC_ENV then
            openCommand = 'open "' .. url .. '"'          -- macOS
        else
            openCommand = 'xdg-open "' .. url .. '"'      -- Linux/Unix
        end
        LrTasks.execute(openCommand)
    end)
end

-- Unified Function: showOrUpdateTokenDialog
-- Displays the token dialog, prefilled with the current token if it exists.
local function showOrUpdateTokenDialog()
    -- Refresh current token from prefs
    props.token = prefs.token or ""

    local contents = f:column {
        bind_to_object = props,
        spacing = f:control_spacing(),

        f:static_text {
            title = LOC("$$$/iNat/TokenDialog/Instruction=Please paste your iNaturalist token (valid for 24 hours):"),
            width = 400
        },

        f:edit_field {
            value = LrView.bind("token"),
            width_in_chars = 50
        },

        f:push_button {
            title = LOC("$$$/iNat/TokenDialog/OpenPage=Open token generation page"),
            action = openTokenPage
        },

        f:push_button {
            title = LOC("$$$/iNat/TokenDialog/Save=Save token"),
            action = function()
                prefs.token = props.token
                LrDialogs.message(LOC("$$$/iNat/TokenDialog/Saved=Token successfully saved."))
            end
        }
    }

    LrDialogs.presentModalDialog {
        title = LOC("$$$/iNat/TokenDialog/Title=iNaturalist Token Setup"),
        contents = contents
    }
end

-- Exported functions
return {
    showOrUpdateTokenDialog = showOrUpdateTokenDialog
}

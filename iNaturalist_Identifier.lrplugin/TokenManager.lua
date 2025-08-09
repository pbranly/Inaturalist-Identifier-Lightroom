--[[
=====================================================================================
 Script       : TokenManager.lua
 Purpose      : Manage iNaturalist API token within Lightroom plugin
 Author       : Philippe

 Functional Overview:
 Combines UI dialog for entering/saving token and utility to refresh it.
 Provides a modal interface and a callable function to trigger token update.

 Key Features:
 - Modal dialog for token input and saving
 - Opens token generation page in browser
 - Saves token persistently via plugin preferences
 - Asynchronous execution for smooth UX
 - Graceful error handling
 - Modular export for integration

 Dependencies:
 - Lightroom SDK: LrPrefs, LrDialogs, LrView, LrTasks, LrPathUtils, LrFileUtils
 - Localization via LOC()
 - Platform detection: WIN_ENV, MAC_ENV
=====================================================================================
--]]

-- Import Lightroom SDK modules
local LrPrefs     = import "LrPrefs"
local LrDialogs   = import "LrDialogs"
local LrView      = import "LrView"
local LrTasks     = import "LrTasks"
local LrPathUtils = import "LrPathUtils"
local LrFileUtils = import "LrFileUtils"

-- UI factory and plugin preferences
local f     = LrView.osFactory()
local prefs = LrPrefs.prefsForPlugin()

-- Property table for UI binding
local props = {
    token = prefs.token or ""
}

-- Function: openTokenPage
local function openTokenPage()
    local url = "https://www.inaturalist.org/users/api_token"
    LrTasks.startAsyncTask(function()
        local openCommand
        if WIN_ENV then
            openCommand = 'start "" "' .. url .. '"'
        elseif MAC_ENV then
            openCommand = 'open "' .. url .. '"'
        else
            openCommand = 'xdg-open "' .. url .. '"'
        end
        LrTasks.execute(openCommand)
    end)
end

-- Function: showTokenDialog
local function showTokenDialog()
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

-- Function: runUpdateTokenScript
local function runUpdateTokenScript()
    local updateScriptPath = LrPathUtils.child(_PLUGIN.path, "update_token.lua")

    if LrFileUtils.exists(updateScriptPath) then
        LrTasks.startAsyncTask(function()
            dofile(updateScriptPath)
        end)
    else
        LrDialogs.message(LOC("$$$/iNat/Error/MissingUpdateScript=Token update script missing: update_token.lua"))
    end
end

-- Exported functions
return {
    showTokenDialog = showTokenDialog,
    runUpdateTokenScript = runUpdateTokenScript
}
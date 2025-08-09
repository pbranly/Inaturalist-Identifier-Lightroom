--[[
=====================================================================================
 Script       : TokenUpdater.lua
 Purpose      : Execute an auxiliary script to refresh the iNaturalist token
 Author       : Philippe

 Functional Overview:
 This module defines a utility function used within a Lightroom plugin to refresh
 the iNaturalist authentication token. It checks for the presence of a helper script
 named `update_token.lua` located in the plugin directory. If found, it executes the
 script asynchronously to avoid blocking the Lightroom UI. If the script is missing,
 it alerts the user with a modal dialog.

 Key Features:
 - Asynchronous execution using Lightroom's task system
 - Graceful error handling with user notification
 - Modular design for easy integration into other plugin components

 Typical Use:
 - Called when the iNaturalist token needs to be refreshed
 - Ensures smooth user experience by running in the background

 Dependencies:
 - Lightroom SDK modules: LrPathUtils, LrFileUtils, LrTasks, LrDialogs
=====================================================================================
--]]

-- Import required Lightroom SDK modules
local LrPathUtils = import "LrPathUtils"   -- For constructing file paths
local LrFileUtils = import "LrFileUtils"   -- For checking file existence
local LrTasks     = import "LrTasks"       -- For running asynchronous tasks
local LrDialogs   = import "LrDialogs"     -- For displaying modal dialogs

--[[
 Function: runUpdateTokenScript
 Description:
 Checks whether the `update_token.lua` script exists in the plugin folder.
 If found, executes it asynchronously using `LrTasks.startAsyncTask`.
 If not found, displays an error message to the user.

 Steps:
 1. Construct the full path to `update_token.lua` using `_PLUGIN.path`.
 2. Check if the file exists.
 3. If it exists:
    - Run it asynchronously using `dofile`.
 4. If it does not exist:
    - Show a modal error dialog.
--]]
local function runUpdateTokenScript()
    local updateScriptPath = LrPathUtils.child(_PLUGIN.path, "update_token.lua")

    if LrFileUtils.exists(updateScriptPath) then
        -- Execute the script in a background task
        LrTasks.startAsyncTask(function()
            dofile(updateScriptPath)
        end)
    else
        -- Notify the user that the script is missing
        LrDialogs.message(LOC("$$$/iNat/Error/MissingUpdateScript=Token update script missing: update_token.lua"))
    end
end

-- Export the function for use in other plugin modules
return {
    runUpdateTokenScript = runUpdateTokenScript
}
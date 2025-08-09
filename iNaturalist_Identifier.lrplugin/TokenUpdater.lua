--[[
=====================================================================================
 Script : TokenUpdater.lua
 Purpose : Execute an auxiliary script to refresh the iNaturalist token
 Author  : Philippe (or your name here)
 Description :
 This module provides a function that checks for the presence of the `update_token.lua` 
 script inside the plugin folder and, if found, runs it asynchronously using Lightroom's
 task system. If the script is missing, it alerts the user via a modal dialog.

 Typical Use:
 - Called from within the plugin when a token refresh is required.
 - Ensures non-blocking execution by using `LrTasks.startAsyncTask`.

 Dependencies:
 - Lightroom SDK: LrPathUtils, LrFileUtils, LrTasks, LrDialogs
=====================================================================================
--]]

-- Lightroom SDK imports
local LrPathUtils = import "LrPathUtils"
local LrFileUtils = import "LrFileUtils"
local LrTasks     = import "LrTasks"
local LrDialogs   = import "LrDialogs"

-- Function to run the update_token.lua script asynchronously
local function runUpdateTokenScript()
    local updateScriptPath = LrPathUtils.child(_PLUGIN.path, "update_token.lua")

    if LrFileUtils.exists(updateScriptPath) then
        -- If the script exists, execute it in a background task
        LrTasks.startAsyncTask(function()
            dofile(updateScriptPath)
        end)
    else
        -- Show an error message if the script is missing
        LrDialogs.message(LOC("$$$/iNat/Error/MissingUpdateScript=Token update script missing: update_token.lua"))
    end
end

-- Export the function
return {
    runUpdateTokenScript = runUpdateTokenScript
}
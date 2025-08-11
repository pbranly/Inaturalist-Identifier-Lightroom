--[[
============================================================
Functional Description
------------------------------------------------------------
This module `TokenUpdater.lua` manages the execution of the 
`update_token.lua` script that updates the iNaturalist 
authentication token.

Main features:
1. Verify the presence of the `update_token.lua` script.
2. Run this update script asynchronously in a Lightroom task 
   to avoid blocking the UI.
3. Display an error message if the script is missing.

------------------------------------------------------------
Numbered Steps
1. Import necessary Lightroom modules (paths, files, tasks, dialogs).
2. Define the function `runUpdateTokenScript` which:
    2.1. Builds the full path to `update_token.lua`.
    2.2. Checks if the script exists.
    2.3. Runs the script asynchronously if present.
    2.4. Shows an error message otherwise.
3. Export the function for external use.

------------------------------------------------------------
Called Scripts
- `update_token.lua` (the token update script)

------------------------------------------------------------
Calling Script
- AnimalIdentifier.lua (e.g. when token is missing or invalid)
============================================================
]]

-- [Step 1] Lightroom SDK imports
local LrPathUtils = import "LrPathUtils"
local LrFileUtils = import "LrFileUtils"
local LrTasks    = import "LrTasks"
local LrDialogs  = import "LrDialogs"

-- [Step 2] Function to run update_token.lua asynchronously
local function runUpdateTokenScript()
    -- [2.1] Construct full path of update_token.lua
    local updateScriptPath = LrPathUtils.child(_PLUGIN.path, "update_token.lua")

    -- [2.2] Check if script exists
    if LrFileUtils.exists(updateScriptPath) then
        -- [2.3] Run script in background async task
        LrTasks.startAsyncTask(function()
            dofile(updateScriptPath)
        end)
    else
        -- [2.4] Show error if script missing
        LrDialogs.message(LOC("$$$/iNat/Error/MissingUpdateScript=Token update script missing: update_token.lua"))
    end
end

-- [Step 3] Export the function
return {
    runUpdateTokenScript = runUpdateTokenScript
}

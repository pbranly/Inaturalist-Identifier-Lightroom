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

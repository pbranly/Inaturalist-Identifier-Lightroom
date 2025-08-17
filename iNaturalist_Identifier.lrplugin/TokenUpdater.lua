--[[
============================================================
Functional Description
------------------------------------------------------------
This module `TokenUpdater.lua` manages the iNaturalist authentication token
by storing it in plugin preferences along with a timestamp. Token validity
is determined by checking that the token is not older than 24 hours.

Main Features:
1. Display a modal dialog for entering and saving the token.
2. Open the official token generation page in the browser.
3. Save the token and its timestamp in Lightroom plugin preferences.
4. Provide a simple function to check token status based on age.
5. Provide a function to return a user-friendly status text.

Modules and Scripts Used:
- LrPrefs
- LrDialogs
- LrView
- LrTasks

Scripts Calling This Module:
- PluginInfoProvider.lua (for UI)
- AnimalIdentifier.lua (to ensure token is fresh before use)

Numbered Steps:
1. Import Lightroom SDK modules.
2. Define runUpdateTokenScript() to display modal dialog and save token.
3. Save the current timestamp when token is saved.
4. Provide isTokenFresh() to check token age.
5. Provide getTokenStatusText() to return human-readable status.
6. Export functions for external use.
============================================================
]]

-- Step 1: Import Lightroom modules
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrView    = import "LrView"
local LrTasks   = import "LrTasks"

local logger = require("Logger")

-- Step 2: Function to run token update UI
local function runUpdateTokenScript()
    LrTasks.startAsyncTask(function()
        local f = LrView.osFactory()
        local prefs = LrPrefs.prefsForPlugin()
        local props = { token = prefs.token or "" }

        local function openTokenPage()
            local url = "https://www.inaturalist.org/users/api_token"
            local openCommand
            if WIN_ENV then
                openCommand = 'start "" "' .. url .. '"'
            elseif MAC_ENV then
                openCommand = 'open "' .. url .. '"'
            else
                openCommand = 'xdg-open "' .. url .. '"'
            end
            LrTasks.execute(openCommand)
        end

        local contents = f:column {
            bind_to_object = props,
            spacing = f:control_spacing(),

            f:static_text {
                title = LOC("$$$/iNat/TokenDialog/Instruction=Please paste your iNaturalist token (valid 24 hours):"),
                width = 400,
            },

            f:edit_field {
                value = LrView.bind("token"),
                width_in_chars = 80
            },

            f:push_button {
                title = LOC("$$$/iNat/TokenDialog/OpenPage=Open token generation page"),
                action = openTokenPage
            },

            f:push_button {
                title = LOC("$$$/iNat/TokenDialog/Save=Save token"),
                action = function()
                    prefs.token = props.token
                    prefs.tokenTimestamp = os.time()  -- Step 3: save timestamp
                    logger.logMessage("[TokenUpdater] Token saved at timestamp: " .. tostring(prefs.tokenTimestamp))
                    LrDialogs.message(LOC("$$$/iNat/TokenDialog/Saved=Token successfully saved."))
                end
            }
        }

        LrDialogs.presentModalDialog {
            title = LOC("$$$/iNat/TokenDialog/Title=iNaturalist Token Setup"),
            contents = contents
        }
    end)
end

-- Step 4: Check if token is fresh (<24h)
local function isTokenFresh()
    local prefs = LrPrefs.prefsForPlugin()
    if not prefs.token or prefs.token == "" then
        return false
    end
    local timestamp = prefs.tokenTimestamp or 0
    local age = os.time() - timestamp
    return age <= 24*3600
end

-- Step 5: Return user-friendly token status text
local function getTokenStatusText()
    if not prefs.token or prefs.token == "" then
        return LOC("$$$/iNat/TokenStatus/None=No token available.")
    end
    if isTokenFresh() then
        return LOC("$$$/iNat/TokenStatus/Valid=Token is fresh and valid (less than 24h old).")
    else
        return LOC("$$$/iNat/TokenStatus/Expired=Token expired. Please refresh.")
    end
end

-- Step 6: Export functions
return {
    runUpdateTokenScript = runUpdateTokenScript,
    isTokenFresh = isTokenFresh,
    getTokenStatusText = getTokenStatusText
}

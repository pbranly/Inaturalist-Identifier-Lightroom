--[[============================================================
TokenUpdater.lua
------------------------------------------------------------
Functional Description:
This module `TokenUpdater.lua` manages the iNaturalist authentication token
for the Lightroom plugin by allowing the user to enter a token and saving it
with a timestamp. Token validity is considered < 24 hours old.

Main Features:
1. Display a modal dialog to enter and save the token.
2. Save the token and its timestamp in Lightroom plugin preferences.
3. Provide functions to check token freshness and display token status.

Modules and Scripts Used:
- LrPrefs
- LrDialogs
- LrView
- LrTasks
- Logger.lua (custom logging)

Called Scripts:
- PluginInfoProvider.lua (e.g., to show token status or open the dialog)

Numbered Steps:
1. Import Lightroom SDK modules and Logger.
2. Define `isTokenFresh()` to check token age (<24h).
3. Define `getTokenStatusText()` to return a human-readable token status.
4. Define `runUpdateTokenScript()` to show a modal UI to enter/update token.
5. Save token and update timestamp when user clicks "Save".
6. Export functions for external use.
============================================================]]

-- Step 1: Lightroom SDK imports
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrView    = import "LrView"
local LrTasks   = import "LrTasks"

local logger = require("Logger")

-- Définition des environnements pour Windows / Mac
local WIN_ENV = package.config:sub(1,1) == '\\'
local MAC_ENV = package.config:sub(1,1) == '/' and os.getenv("OSTYPE") == "darwin"

-- Step 2: Function to check if token is fresh (<24h old)
local function isTokenFresh()
    local prefs = LrPrefs.prefsForPlugin()
    if not prefs.token or prefs.token == "" then
        return false
    end
    local timestamp = prefs.tokenTimestamp or 0
    local age = os.time() - timestamp
    logger.logMessage("[TokenUpdater] Token age in seconds: " .. tostring(age))
    return age <= 24 * 3600
end

-- Step 3: Function to get token status text for UI display
local function getTokenStatusText()
    local prefs = LrPrefs.prefsForPlugin()
    if not prefs.token or prefs.token == "" then
        return LOC("$$$/iNat/TokenStatus/None=No token available.")
    end
    if isTokenFresh() then
        return LOC(
            "$$$/iNat/TokenStatus/Valid=Token is fresh and valid (less than 24h old)."
        )
    else
        return LOC("$$$/iNat/TokenStatus/Expired=Token expired. Please refresh.")
    end
end

-- Step 4: Function to run token update UI
local function runUpdateTokenScript()
    LrTasks.startAsyncTask(function()
        local prefs = LrPrefs.prefsForPlugin()
        local f = LrView.osFactory()
        local props = { token = prefs.token or "" }

        -- Function to open token generation page
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
            logger.logMessage(
                "[TokenUpdater] Opening token page with command: " .. openCommand
            )
            LrTasks.execute(openCommand)
        end

        -- Modal UI
        local contents = f:column {
            bind_to_object = props,
            spacing = f:control_spacing(),

            f:static_text {
                title = LOC(
                    "$$$/iNat/TokenDialog/Instruction=Please paste your iNaturalist token (valid for 24 hours):"
                ),
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
                    prefs.tokenTimestamp = os.time()
                    logger.logMessage(
                        "[TokenUpdater] Token saved. Timestamp updated to "
                        .. tostring(prefs.tokenTimestamp)
                    )
                    LrDialogs.message(
                        LOC("$$$/iNat/TokenDialog/Saved=Token successfully saved.")
                    )
                end
            }
        }

        LrDialogs.presentModalDialog {
            title = LOC("$$$/iNat/TokenDialog/Title=iNaturalist Token Setup"),
            contents = contents
        }
    end)
end

-- Step 6: Export functions
return {
    runUpdateTokenScript = runUpdateTokenScript,
    isTokenFresh = isTokenFresh,
    getTokenStatusText = getTokenStatusText
}

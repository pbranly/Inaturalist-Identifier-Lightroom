--[[============================================================
Functional Description
------------------------------------------------------------
This module `TokenUpdater.lua` manages the iNaturalist 
authentication token update by directly presenting a modal 
dialog to the user.

Main features:
1. Display a modal dialog to enter and save the token.
2. Open the official token generation webpage in the browser.
3. Save the token and its timestamp in Lightroom plugin preferences.

------------------------------------------------------------
Numbered Steps
1. Import necessary Lightroom modules (paths, files, tasks, dialogs, view, prefs).
2. Define the function `runUpdateTokenScript` which:
    2.1 Builds the modal UI.
    2.2 Opens the token generation page.
    2.3 Saves the token and current timestamp in preferences.
3. Export the function for external use.

------------------------------------------------------------
Calling Script
- AnimalIdentifier.lua (e.g. when token is missing or invalid)
============================================================]]

-- [Step 1] Lightroom SDK imports
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrView    = import "LrView"
local LrTasks   = import "LrTasks"

-- [Step 2] Function to run token update UI
local function runUpdateTokenScript()
    LrTasks.startAsyncTask(function()
        -- 2.1 Create UI factory and bind properties
        local f = LrView.osFactory()
        local prefs = LrPrefs.prefsForPlugin()
        local props = { token = prefs.token or "" }

        -- 2.2 Define function to open token generation page
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

        -- 2.3 Build modal UI
        local contents = f:column {
            bind_to_object = props,
            spacing = f:control_spacing(),

            f:static_text {
                title = LOC("$$$/iNat/TokenDialog/Instruction=Please paste your iNaturalist token (valid for 24 hours):"),
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
                    -- Save token
                    prefs.token = props.token
                    -- Save current timestamp
                    prefs.tokenTimestamp = os.time()
                    LrDialogs.message(LOC("$$$/iNat/TokenDialog/Saved=Token successfully saved."))
                end
            }
        }

        -- 2.4 Show modal dialog
        LrDialogs.presentModalDialog {
            title = LOC("$$$/iNat/TokenDialog/Title=iNaturalist Token Setup"),
            contents = contents
        }
    end)
end

-- [Step 3] Export the function
return {
    runUpdateTokenScript = runUpdateTokenScript
}

--[[
=====================================================================================
 Module   : TokenUpdater.lua
 Purpose  : Manage the acquisition and storage of the iNaturalist personal access token
 Author   : Philippe Branly (or your name here)

 Description :
 ------------
 This module provides a complete user interface within Lightroom for managing the 
 iNaturalist personal API token required for authentication with the iNaturalist service.

 The iNaturalist API requires users to authenticate via a token that is generated
 from their user account page. This token expires after 24 hours and must be refreshed
 periodically to continue accessing the API.

 Functional Overview :
 ---------------------
 This module combines two key functionalities:
   1. Opening the official iNaturalist token generation page in the user's default browser.
   2. Providing a modal dialog in Lightroom to paste, view, and save the token.

 When invoked, it displays a dialog where the user can:
   - Click a button to open the token generation URL.
   - Paste the newly generated token into a text field.
   - Save the token persistently using Lightroom's plugin preferences.

 This stored token can later be retrieved by other plugin modules for authenticated API calls.

 Key Features :
 --------------
 - Full UI integration using Lightroom's native LrView system
 - Cross-platform browser launch (macOS, Windows, Linux)
 - Token persistence across Lightroom sessions using LrPrefs
 - Safe asynchronous task execution (non-blocking)
 - Localization-ready with `LOC()` wrappers for all visible strings

 Typical Usage :
 ---------------
 - Called manually by the user from a plugin menu
 - Or triggered automatically when an API call fails due to token expiration

 Integration Example :
 ---------------------
     local tokenUpdater = require("TokenUpdater")
     tokenUpdater.launchTokenUpdater()

 Dependencies :
 --------------
 Lightroom SDK modules:
 - LrPrefs     : for reading/writing plugin preferences
 - LrDialogs   : for displaying UI dialogs
 - LrView      : for creating the modal token input interface
 - LrTasks     : for executing asynchronous shell commands

=====================================================================================
--]]

-- Import Lightroom SDK modules
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrView    = import "LrView"
local LrTasks   = import "LrTasks"

-- Create the module
local TokenUpdater = {}

-- Function: launchTokenUpdater
-- Description:
--    Displays a modal dialog to input or update the iNaturalist API token.
--    Provides a button to open the token generation page in the default browser.
function TokenUpdater.launchTokenUpdater()
    local f = LrView.osFactory()
    local prefs = LrPrefs.prefsForPlugin()
    local props = { token = prefs.token or "" }

    -- Function to open the token generation page in the default browser
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

    -- UI layout definition
    local contents = f:column {
        bind_to_object = props,
        spacing = f:control_spacing(),

        f:static_text {
            title = LOC("$$$/iNat/TokenDialog/Instruction=Please paste your iNaturalist token (valid for 24 hours):"),
            width = 400,
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

    -- Display the UI
    LrDialogs.presentModalDialog {
        title = LOC("$$$/iNat/TokenDialog/Title=iNaturalist Token Setup"),
        contents = contents
    }
end

-- Return the module's public API
return TokenUpdater

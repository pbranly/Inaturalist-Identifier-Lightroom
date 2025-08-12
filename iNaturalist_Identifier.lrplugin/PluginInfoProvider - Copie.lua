--[[
=====================================================================================
PlugInInfoProvider.lua (Modified with Token Status Check)
-------------------------------------------------------------------------------------
Functional Description
-------------------------------------------------------------------------------------
This module defines the Lightroom plugin preferences dialog for the iNaturalist plugin.
It has been modified so that token configuration via TokenUpdater.lua is only offered 
when the stored token is missing or expired. If the token is valid, a message is shown 
informing the user that the token is up-to-date.

Main features:
1. Provide a button to check the token status.
2. If the token is valid → show a message "Token up-to-date".
3. If the token is missing or expired → show a confirmation dialog 
   "Token must be renewed. Do you want to update it now?" with OK/Cancel buttons.
4. Launch TokenUpdater.lua only if the user confirms.
5. Provide a checkbox to enable/disable logging to log.txt.
6. Keep all user-facing messages internationalized via LOC().
7. Keep all log messages in English for consistency in log.txt.

-------------------------------------------------------------------------------------
Numbered Steps
-------------------------------------------------------------------------------------
1. Import Lightroom SDK modules for preferences and UI creation.
2. Import TokenUpdater.lua for token configuration.
3. Import VerificationToken.lua for token validation.
4. Retrieve plugin preferences.
5. Create the logging enable/disable checkbox.
6. Build and return the dialog layout:
    6.1. Display a title and instruction about token configuration.
    6.2. Display a button to check token status and optionally launch TokenUpdater.lua.
    6.3. Display the logging checkbox row.
    6.4. Display a Save button to persist logging preferences.

-------------------------------------------------------------------------------------
Called Scripts
-------------------------------------------------------------------------------------
- TokenUpdater.lua        → Presents a modal dialog to update the token.
- VerificationToken.lua   → Validates the stored token.

-------------------------------------------------------------------------------------
Calling Script
-------------------------------------------------------------------------------------
- Invoked automatically by Lightroom when displaying plugin preferences via Info.lua.
=====================================================================================
]]

-- [Step 1] Lightroom module imports
local LrPrefs   = import "LrPrefs"
local LrView    = import "LrView"
local LrDialogs = import "LrDialogs"

-- [Step 2] Import TokenUpdater module
local tokenUpdater = require("TokenUpdater")

-- [Step 3] Import token validation module
local tokenChecker = require("VerificationToken")

-- [Step 6] Preferences dialog definition
return {
    sectionsForTopOfDialog = function(viewFactory)
        -- [Step 4] Retrieve plugin preferences
        local prefs = LrPrefs.prefsForPlugin()

        -- [Step 5] Checkbox to enable logging
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNaturalist/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false,
            checked_value = true,
            unchecked_value = false,
        }

        -- [Step 6] Return dialog layout
        return {
            {
                title = LOC("$$$/iNaturalist/ConnectionSettings=iNaturalist connection settings"),

                -- [6.1] Instructional message
                viewFactory:static_text {
                    title = LOC("$$$/iNaturalist/TokenNote=Click the button below to check and configure your iNaturalist token."),
                    width = 400,
                },

                -- [6.2] Button to check token status
                viewFactory:push_button {
                    title = LOC("$$$/iNaturalist/ConfigureToken=Configure token"),
                    action = function()
                        local logger = require("Logger")

                        -- Case 1: Token exists and is valid
                        if prefs.token and prefs.token ~= "" and tokenChecker.isTokenValid() then
                            logger.logMessage("Token is up-to-date.")
                            LrDialogs.message(
                                LOC("$$$/iNat/TokenDialog/UpToDateTitle=Token status"),
                                LOC("$$$/iNat/TokenDialog/UpToDate=Token up-to-date")
                            )
                            return
                        end

                        -- Case 2: Token missing or expired
                        logger.logMessage("Token must be renewed.")
                        local choice = LrDialogs.confirm(
                            LOC("$$$/iNat/TokenDialog/MustRenewTitle=Token status"),
                            LOC("$$$/iNat/TokenDialog/MustRenew=Token must be renewed. Do you want to update it now?"),
                            LOC("$$$/iNat/TokenDialog/Ok=OK"),
                            LOC("$$$/iNat/TokenDialog/Cancel=Cancel")
                        )

                        if choice == "ok" then
                            logger.logMessage("User chose to update the token.")
                            tokenUpdater.runUpdateTokenScript()
                        else
                            logger.logMessage("User cancelled token update.")
                        end
                    end,
                },

                -- [6.3] Logging checkbox row
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    logCheck,
                },

                -- [6.4] Save button
                viewFactory:push_button {
                    title = LOC("$$$/iNaturalist/SaveButton=Save"),
                    action = function()
                        prefs.logEnabled = logCheck.value
                        require("Logger").logMessage("Logging preference saved: " .. tostring(logCheck.value))
                    end,
                },
            }
        }
    end
}

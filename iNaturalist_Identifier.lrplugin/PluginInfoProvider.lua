--[[
=====================================================================================
PlugInInfoProvider.lua (Modified)
-------------------------------------------------------------------------------------
Functional Description
-------------------------------------------------------------------------------------
This module defines the Lightroom plugin preferences dialog for the iNaturalist plugin.
It has been modified to remove direct token input and instead use the TokenUpdater.lua
script to manage token entry and saving. This ensures that all token-related logic 
exists in one place and can be reused consistently across the plugin.

Main features:
1. Provide a button to open the TokenUpdater.lua script for token configuration.
2. Provide a checkbox to enable/disable logging to log.txt.
3. Keep all user-facing messages internationalized via LOC().
4. Keep logging in English only for consistency in log.txt.

-------------------------------------------------------------------------------------
Numbered Steps
-------------------------------------------------------------------------------------
1. Import Lightroom SDK modules for preferences, UI creation, and tasks.
2. Import the TokenUpdater.lua module for token configuration.
3. Retrieve plugin preferences.
4. Create the logging enable/disable checkbox.
5. Build and return the dialog layout:
    5.1. Display a title and instruction about configuring the token.
    5.2. Display a button to launch TokenUpdater.lua.
    5.3. Display the logging checkbox row.
    5.4. Display a Save button to persist logging preferences.

-------------------------------------------------------------------------------------
Called Scripts
-------------------------------------------------------------------------------------
- TokenUpdater.lua → Presents a modal dialog to update the token.

-------------------------------------------------------------------------------------
Calling Script
-------------------------------------------------------------------------------------
- Invoked automatically by Lightroom when displaying plugin preferences via Info.lua.
=====================================================================================
]]

-- [Step 1] Lightroom module imports
local LrPrefs = import "LrPrefs"
local LrView  = import "LrView"

-- [Step 2] Import TokenUpdater module
local tokenUpdater = require("TokenUpdater")

-- [Step 5] Preferences dialog definition
return {
    sectionsForTopOfDialog = function(viewFactory)
        -- [Step 3] Retrieve plugin preferences
        local prefs = LrPrefs.prefsForPlugin()

        -- [Step 4] Checkbox to enable logging
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNaturalist/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false,
            checked_value = true,
            unchecked_value = false,
        }

        -- [Step 5] Return dialog layout
        return {
            {
                title = LOC("$$$/iNaturalist/ConnectionSettings=iNaturalist connection settings"),

                -- [5.1] Instructional message
                viewFactory:static_text {
                    title = LOC("$$$/iNaturalist/TokenNote=Click the button below to configure your iNaturalist token."),
                    width = 400,
                },

                -- [5.2] Button to open TokenUpdater
                viewFactory:push_button {
                    title = LOC("$$$/iNaturalist/ConfigureToken=Configure token"),
                    action = function()
                        -- Log in English only
                        require("Logger").logMessage("Opening TokenUpdater dialog from preferences.")
                        tokenUpdater.runUpdateTokenScript()
                    end,
                },

                -- [5.3] Logging checkbox row
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    logCheck,
                },

                -- [5.4] Save button
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

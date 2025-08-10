--[[
=====================================================================================
 Script       : TokenUpdater.lua
 Purpose      : Plugin preferences panel for iNaturalist Lightroom plugin
 Author       : Philippe

 Functional Overview:
 This script defines a preferences section in the Lightroom plugin settings dialog.
 It allows users to configure essential settings for interacting with the iNaturalist API:

 1. Enter or update their personal iNaturalist API token (valid for 24 hours).
 2. Enable or disable diagnostic logging to a local log.txt file.
 3. Open the official iNaturalist token generation page in their default browser.

 These preferences are stored persistently using Lightroom’s plugin-specific settings
 and are used by other modules to authenticate API calls and manage debugging output.

 Key Features:
 - Secure token storage across sessions
 - Logging toggle for troubleshooting
 - Asynchronous browser launch for smooth UI experience

 Dependencies:
 - Lightroom SDK: LrPrefs, LrView, LrTasks
 - Platform detection variables: WIN_ENV, MAC_ENV (must be defined elsewhere)
=====================================================================================
--]]

-- Import Lightroom SDK modules
local LrPrefs = import "LrPrefs"      -- For persistent plugin preferences
local LrView = import "LrView"        -- For building UI elements
local LrTasks = import "LrTasks"      -- For asynchronous command execution

local logger = require("Logger")       -- ajout logger

-- Return the plugin preferences section definition
return {
    sectionsForTopOfDialog = function(viewFactory)
        local prefs = LrPrefs.prefsForPlugin()  -- Load plugin-specific preferences

        -- UI element: Text input field for iNaturalist token
        local tokenField = viewFactory:edit_field {
            value = prefs.token or "",         -- Pre-fill with saved token if available
            width_in_chars = 50                -- Approximate width in characters
        }

        -- UI element: Checkbox to enable or disable logging
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNaturalist/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false,
            checked_value = true,
            unchecked_value = false
        }

        -- Function: Opens the iNaturalist token generation page in the default browser
        local function openTokenPage()
            logger.logMessage("Opening iNaturalist token generation page in browser")
            local url = "https://www.inaturalist.org/users/api_token"
            LrTasks.startAsyncTask(function()
                local openCommand
                if WIN_ENV then
                    openCommand = 'start "" "' .. url .. '"'     -- Windows
                elseif MAC_ENV then
                    openCommand = 'open "' .. url .. '"'         -- macOS
                else
                    openCommand = 'xdg-open "' .. url .. '"'     -- Linux/Unix
                end
                LrTasks.execute(openCommand)
            end)
        end

        -- Return the layout of the preferences panel
        return {
            {
                title = LOC("$$$/iNaturalist/ConnectionSettings=iNaturalist connection settings"),

                -- Instructional text about token validity
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    viewFactory:static_text {
                        title = LOC("$$$/iNaturalist/TokenNote=The token is valid for 24 hours; after that, you must regenerate it at the following address:"),
                        width = 400,
                        alignment = 'left'
                    }
                },

                -- Button to open token generation page
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    viewFactory:push_button {
                        title = LOC("$$$/iNaturalist/OpenTokenPage=Open token generation page"),
                        action = openTokenPage
                    }
                },

                -- Row for token label and input field
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    viewFactory:static_text {
                        title = LOC("$$$/iNaturalist/TokenLabel=Token:"),
                        alignment = 'right',
                        width = 100
                    },
                    tokenField
                },

                -- Row for logging checkbox
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    logCheck
                },

                -- Save button to persist token and logging settings
                viewFactory:push_button {
                    title = LOC("$$$/iNaturalist/SaveButton=Save"),
                    action = function()
                        prefs.token = tokenField.value
                        prefs.logEnabled = logCheck.value
                        logger.logMessage("Preferences saved: token updated, logging " .. (prefs.logEnabled and "enabled" or "disabled"))
                    end
                }
            }
        }
    end
}

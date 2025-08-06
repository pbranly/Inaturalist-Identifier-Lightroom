--[[
=====================================================================================
 Script   : PluginInfoProvider.lua
 Purpose  : Define a custom preferences panel for the iNaturalist Lightroom plugin
 Author   : Philippe Branly (or your name here)

 Description :
 ------------
 This script provides a custom preferences section in Lightroom's Plugin Manager.
 It allows users to configure authentication and logging settings for the 
 iNaturalist integration.

 Specifically, it provides:
   - A button to open the iNaturalist token generation page in the default web browser.
   - A text input field to manually enter or update the API token.
   - A checkbox to enable or disable logging to a local `log.txt` file.
   - A "Save" button to persist changes in the plugin preferences.

 This panel helps ensure the user maintains a valid token (valid for 24 hours)
 and optionally enables logging for debugging purposes.

 Functional Overview :
 ---------------------
 - When the Plugin Manager loads, this module builds and displays the custom section.
 - It uses Lightroom's `LrView` system to define the layout and inputs.
 - Preferences are stored persistently using `LrPrefs.prefsForPlugin()`.

 Key Features :
 --------------
 - Clean UI layout with labels, inputs, and buttons.
 - Safe asynchronous launching of browser URLs.
 - Preferences saved automatically for future Lightroom sessions.
 - Token is required for API requests sent to iNaturalist.

 Dependencies :
 --------------
 - Lightroom SDK: 
     - LrPrefs    : for storing user-defined plugin settings.
     - LrView     : for UI element construction.
     - LrTasks    : for executing system commands (e.g., to open the browser).

=====================================================================================
--]]

-- Lightroom module imports for plugin preferences and UI creation
local LrPrefs = import "LrPrefs"      -- For storing plugin-specific preferences
local LrView = import "LrView"        -- For creating UI elements in the Lightroom plugin dialog
local LrTasks = import "LrTasks"      -- For launching asynchronous tasks

-- Define and return the plugin preferences dialog
return {
    sectionsForTopOfDialog = function(viewFactory)
        local prefs = LrPrefs.prefsForPlugin()  -- Load preferences specific to this plugin

        -- Text input field for the user's iNaturalist token
        local tokenField = viewFactory:edit_field {
            value = prefs.token or "",         -- Use existing token, or empty if none
            width_in_chars = 50,               -- Width of the input field
        }

        -- Checkbox for enabling/disabling logging
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNaturalist/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false, -- Default to false if not set
            checked_value = true,              -- Value stored if checked
            unchecked_value = false,           -- Value stored if unchecked
        }

        -- Function to open the iNaturalist token generation page in the user's browser
        local function openTokenPage()
            local url = "https://www.inaturalist.org/users/api_token"
            LrTasks.startAsyncTask(function()   -- Run asynchronously to avoid UI blocking
                local openCommand
                if WIN_ENV then
                    openCommand = 'start "" "' .. url .. '"'     -- Windows
                elseif MAC_ENV then
                    openCommand = 'open "' .. url .. '"'         -- macOS
                else
                    openCommand = 'xdg-open "' .. url .. '"'     -- Linux or others
                end
                LrTasks.execute(openCommand)     -- Execute the system command to open the URL
            end)
        end

        -- Return the layout of the dialog as a table of UI components
        return {
            {
                title = LOC("$$$/iNaturalist/ConnectionSettings=iNaturalist connection settings"),

                -- Instructional text explaining token duration and where to get a new one
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    viewFactory:static_text {
                        title = LOC("$$$/iNaturalist/TokenNote=The token is valid for 24 hours; after that, you must regenerate it at the following address:"),
                        width = 400,
                        alignment = 'left',
                    },
                },

                -- Row with button to open the token generation page
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    viewFactory:push_button {
                        title = LOC("$$$/iNaturalist/OpenTokenPage=Open token generation page"),
                        action = openTokenPage,
                    },
                },

                -- Row with token label and input field
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    viewFactory:static_text {
                        title = LOC("$$$/iNaturalist/TokenLabel=Token:"),
                        alignment = 'right',
                        width = 100,
                    },
                    tokenField, -- Token input field
                },

                -- Row with logging checkbox
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    logCheck,   -- Logging enable/disable
                },

                -- Button to save entered token and logging setting
                viewFactory:push_button {
                    title = LOC("$$$/iNaturalist/SaveButton=Save"),
                    action = function()
                        prefs.token = tokenField.value     -- Save token input
                        prefs.logEnabled = logCheck.value -- Save logging preference
                    end,
                },
            }
        }
    end
}

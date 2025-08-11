--[[
============================================================
Functional Description
------------------------------------------------------------
This module defines the Lightroom plugin preferences dialog
for the iNaturalist plugin.

Main features:
1. Provide a text input field for the user to enter their 
   iNaturalist API token.
2. Provide a checkbox to enable/disable logging to log.txt.
3. Provide a button to open the token generation page in the
   user's default browser.
4. Save the token and logging preferences.

------------------------------------------------------------
Numbered Steps
1. Import Lightroom modules for preferences, UI creation, and tasks.
2. Retrieve plugin preferences.
3. Create the token input field.
4. Create the logging enable/disable checkbox.
5. Define the function to open the token generation page.
6. Build and return the dialog layout:
    6.1. Display an informational message about token expiration.
    6.2. Display a button to open the token generation page.
    6.3. Display the token input row.
    6.4. Display the logging checkbox row.
    6.5. Display the Save button to persist preferences.

------------------------------------------------------------
Called scripts
- None (uses Lightroom built-in modules only)

------------------------------------------------------------
Calling script
- Invoked automatically by Lightroom when displaying plugin
  preferences via Info.lua
============================================================
]]

-- [Step 1] Lightroom module imports
local LrPrefs = import "LrPrefs"
local LrView = import "LrView"
local LrTasks = import "LrTasks"

-- [Step 6] Preferences dialog definition
return {
    sectionsForTopOfDialog = function(viewFactory)
        -- [Step 2] Retrieve plugin preferences
        local prefs = LrPrefs.prefsForPlugin()

        -- [Step 3] Token input field
        local tokenField = viewFactory:edit_field {
            value = prefs.token or "",
            width_in_chars = 50,
        }

        -- [Step 4] Checkbox to enable logging
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNaturalist/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false,
            checked_value = true,
            unchecked_value = false,
        }

        -- [Step 5] Function to open the token generation page in the default browser
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

        -- [Step 6] Return the dialog layout
        return {
            {
                title = LOC("$$$/iNaturalist/ConnectionSettings=iNaturalist connection settings"),

                -- [6.1] Instructional message about token expiration
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    viewFactory:static_text {
                        title = LOC("$$$/iNaturalist/TokenNote=The token is valid for 24 hours; after that, you must regenerate it at the following address:"),
                        width = 400,
                        alignment = 'left',
                    },
                },

                -- [6.2] Button to open token generation URL
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    viewFactory:push_button {
                        title = LOC("$$$/iNaturalist/OpenTokenPage=Open token generation page"),
                        action = openTokenPage,
                    },
                },

                -- [6.3] Token input row
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    viewFactory:static_text {
                        title = LOC("$$$/iNaturalist/TokenLabel=Token:"),
                        alignment = 'right',
                        width = 100,
                    },
                    tokenField,
                },

                -- [6.4] Logging checkbox row
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    logCheck,
                },

                -- [6.5] Save button to persist token and logging preference
                viewFactory:push_button {
                    title = LOC("$$$/iNaturalist/SaveButton=Save"),
                    action = function()
                        prefs.token = tokenField.value
                        prefs.logEnabled = logCheck.value
                    end,
                },
            }
        }
    end
}

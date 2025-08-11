-- Lightroom module imports
local LrPrefs = import "LrPrefs"
local LrView = import "LrView"
local LrTasks = import "LrTasks"

-- Plugin preferences dialog definition
return {
    sectionsForTopOfDialog = function(viewFactory)
        local prefs = LrPrefs.prefsForPlugin()

        -- Text input field for the user's token
        local tokenField = viewFactory:edit_field {
            value = prefs.token or "",
            width_in_chars = 50,
        }

        -- Checkbox to enable logging
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNaturalist/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false,
            checked_value = true,
            unchecked_value = false,
        }

        -- Opens the token generation page in the user's default browser
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

        -- Return the UI layout for the dialog
        return {
            {
                title = LOC("$$$/iNaturalist/ConnectionSettings=iNaturalist connection settings"),

                -- Instructional message about token expiration
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    viewFactory:static_text {
                        title = LOC("$$$/iNaturalist/TokenNote=The token is valid for 24 hours; after that, you must regenerate it at the following address:"),
                        width = 400,
                        alignment = 'left',
                    },
                },

                -- Button to open the token generation URL
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    viewFactory:push_button {
                        title = LOC("$$$/iNaturalist/OpenTokenPage=Open token generation page"),
                        action = openTokenPage,
                    },
                },

                -- Token input row
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    viewFactory:static_text {
                        title = LOC("$$$/iNaturalist/TokenLabel=Token:"),
                        alignment = 'right',
                        width = 100,
                    },
                    tokenField,
                },

                -- Logging checkbox row
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    logCheck,
                },

                -- Save button to persist token and logging preference
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

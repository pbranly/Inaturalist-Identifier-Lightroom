--[[
=====================================================================================
 Script   : PluginInfoProvider.lua
 Purpose  : Provide a custom preferences panel for the iNaturalist Lightroom plugin
 Author   : Philippe Branly

 Functional Description:
 ------------------------
 This module defines the configuration interface displayed in Lightroom's 
 Plugin Manager for the iNaturalist integration. It allows the user to:

    1. **Authenticate with iNaturalist**
       - The user can paste their iNaturalist API token (valid for 24 hours).
       - A button is provided to directly open the token generation page in 
         the default browser.

    2. **Enable/Disable Logging**
       - Option to enable logging output to `log.txt` for debugging and 
         troubleshooting.

    3. **Save Preferences**
       - The "Save" button stores the token and logging preferences using 
         Lightroom's built-in `LrPrefs` storage, ensuring the settings persist 
         between sessions.

    4. **Check for Plugin Updates via GitHub**
       - The "Check for updates" button fetches the latest release info from 
         a specified GitHub repository using the GitHub REST API.
       - If a newer version than the locally installed one is detected, 
         the user is prompted to open the download page.
       - If the installed version is current, the user is notified that 
         no update is needed.

 Technical Notes:
 ----------------
 - **UI Construction**: 
   Uses `LrView` factory methods (`f:edit_field`, `f:checkbox`, `f:push_button`, etc.) 
   to create rows and controls that form the preferences panel.

 - **Environment Detection**:
   The function `openTokenPage()` detects the operating system 
   (`WIN_ENV`, `MAC_ENV`, or default to Linux/Unix) to execute 
   the correct shell command for opening the URL.

 - **Preferences Management**:
   Uses `LrPrefs.prefsForPlugin()` to access a persistent preferences table 
   unique to the plugin.

 - **Update Checking**:
   - Makes an asynchronous HTTP GET request to GitHub's API with `LrHttp.get()`.
   - Parses the `tag_name` from the returned JSON to extract the latest 
     version number.
   - Compares it to the local version retrieved from the `PluginVersion` module.
   - If newer, prompts the user with a `LrDialogs.confirm()` dialog.

 Example Usage:
 --------------
 This script is automatically called by Lightroom when displaying the 
 Plugin Manager for this plugin. It is not typically invoked directly 
 by other parts of the code.

 Maintenance:
 ------------
 - Update the `githubApiUrl` and release page URL if the repository 
   changes location.
 - Ensure the token note text matches iNaturalist's actual expiration 
   policy if it changes.
 - If additional plugin settings are required, add them as new controls 
   in the `sections` table.

=====================================================================================
--]]
-- Import Lightroom SDK modules
local LrPrefs   = import "LrPrefs"    -- For storing and retrieving plugin preferences
local LrView    = import "LrView"     -- For building custom UI components
local LrTasks   = import "LrTasks"    -- For asynchronous execution
local LrHttp    = import "LrHttp"     -- For making HTTP requests
local LrDialogs = import "LrDialogs"  -- For showing dialogs and alerts

-- Main function returning the plugin's preferences panel definition
return {
    sectionsForTopOfDialog = function(viewFactory)
        -- Retrieve persistent preferences for this plugin
        local prefs = LrPrefs.prefsForPlugin()

        -- Alias to the view factory for convenience
        local f = viewFactory

        ----------------------------------------------------------------------
        -- UI Element: Token input field
        -- Allows the user to paste their iNaturalist API token.
        -- Token is stored in plugin preferences when saved.
        ----------------------------------------------------------------------
        local tokenField = f:edit_field {
            value = prefs.token or "", -- Default to stored token or empty
            width_in_chars = 50,       -- Field width in characters
        }

        ----------------------------------------------------------------------
        -- UI Element: Logging checkbox
        -- Lets the user enable or disable logging to log.txt.
        -- Useful for debugging or error tracking.
        ----------------------------------------------------------------------
        local logCheck = f:checkbox {
            title = LOC("$$$/iNaturalist/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false, -- Default based on saved prefs
            checked_value = true,
            unchecked_value = false,
        }

        ----------------------------------------------------------------------
        -- Function: openTokenPage
        -- Opens the iNaturalist token generation page in the user's browser.
        -- Handles OS-specific commands for Windows, macOS, and Linux.
        ----------------------------------------------------------------------
        local function openTokenPage()
            local url = "https://www.inaturalist.org/users/api_token"
            LrTasks.startAsyncTask(function()
                local openCommand
                if WIN_ENV then
                    openCommand = 'start "" "' .. url .. '"'   -- Windows
                elseif MAC_ENV then
                    openCommand = 'open "' .. url .. '"'       -- macOS
                else
                    openCommand = 'xdg-open "' .. url .. '"'   -- Linux / Unix
                end
                LrTasks.execute(openCommand)
            end)
        end

        ----------------------------------------------------------------------
        -- Build the sections table
        -- Each entry defines a group of UI controls in the Plugin Manager.
        ----------------------------------------------------------------------
        local sections = {
            {
                -- Section title displayed in the Plugin Manager
                title = LOC("$$$/iNaturalist/ConnectionSettings=iNaturalist connection settings"),

                ------------------------------------------------------------------
                -- Information row explaining token expiration policy
                ------------------------------------------------------------------
                f:row {
                    spacing = f:control_spacing(),
                    f:static_text {
                        title = LOC("$$$/iNaturalist/TokenNote=The token is valid for 24 hours; after that, you must regenerate it at the following address:"),
                        width = 400,
                        alignment = 'left',
                    },
                },

                ------------------------------------------------------------------
                -- Button to open the token generation page in the browser
                ------------------------------------------------------------------
                f:row {
                    spacing = f:control_spacing(),
                    f:push_button {
                        title = LOC("$$$/iNaturalist/OpenTokenPage=Open token generation page"),
                        action = openTokenPage,
                    },
                },

                ------------------------------------------------------------------
                -- Token label + editable field for user input
                ------------------------------------------------------------------
                f:row {
                    spacing = f:control_spacing(),
                    f:static_text {
                        title = LOC("$$$/iNaturalist/TokenLabel=Token:"),
                        alignment = 'right',
                        width = 100,
                    },
                    tokenField,
                },

                ------------------------------------------------------------------
                -- Logging checkbox row
                ------------------------------------------------------------------
                f:row {
                    spacing = f:control_spacing(),
                    logCheck,
                },

                ------------------------------------------------------------------
                -- Save button
                -- Commits the entered token and logging preference to persistent storage
                ------------------------------------------------------------------
                f:push_button {
                    title = LOC("$$$/iNaturalist/SaveButton=Save"),
                    action = function()
                        prefs.token = tokenField.value
                        prefs.logEnabled = logCheck.value
                    end,
                },

                ------------------------------------------------------------------
                -- Update check section
                -- Allows the user to check if a newer version of the plugin is available on GitHub.
                ------------------------------------------------------------------
                f:row {
                    spacing = f:control_spacing(),
                    f:push_button {
                        title = LOC("$$$/iNaturalist/CheckUpdate=Vérifier les mises à jour"),
                        action = function()
                            local PluginVersion = require("PluginVersion")
                            local currentVersion = PluginVersion.asString(PluginVersion)

                            -- GitHub API endpoint for latest release
                            local githubApiUrl = "https://api.github.com/repos/pbranly/Inaturalist-Identifier-Lightroom/releases/latest"

                            -- Fetch release info from GitHub
                            LrHttp.get(githubApiUrl, nil, function(body, headers)
                                -- Extract the tag_name from the JSON response
                                local remoteVersion = body and body:match('\\"tag_name\\"%s*:%s*\\"([^\\"\\n]+)\\"')

                                -- Compare remote version to current version
                                if remoteVersion and remoteVersion ~= currentVersion then
                                    local clicked = LrDialogs.confirm(
                                        "Mise à jour disponible : " .. remoteVersion,
                                        "Souhaitez-vous télécharger la nouvelle version ?"
                                    )
                                    if clicked == "ok" then
                                        LrHttp.openUrlInBrowser("https://github.com/pbranly/Inaturalist-Identifier-Lightroom/releases/latest")
                                    end
                                else
                                    LrDialogs.message("Votre plugin est à jour.")
                                end
                            end)
                        end,
                    },
                },
            }
        }

        -- Return the fully built preferences UI
        return sections
    end
}

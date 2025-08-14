--[[
=====================================================================
Functional Description
---------------------------------------------------------------------
This Lightroom plugin UI script defines the **"iNaturalist connection settings"**
dialog. It allows the user to:

1. View the latest plugin version from GitHub.
2. View the current local plugin version.
3. Enable or disable logging.
4. Refresh the GitHub version status on demand.
5. Configure or renew their iNaturalist API token.

The script is designed for asynchronous interaction with GitHub and
token verification systems, ensuring non-blocking UI updates.

=====================================================================
Modules and Scripts Used
---------------------------------------------------------------------
- Lightroom SDK:
    * LrView        - For building UI components.
    * LrPrefs       - For accessing plugin preferences.
    * LrDialogs     - For displaying dialogs to the user.
    * LrTasks       - For running asynchronous tasks.

- Internal Modules:
    * Logger.lua                - Provides logging capabilities.
    * Get_Version_Github.lua    - Fetches the latest plugin version from GitHub.
    * Get_Current_Version.lua   - Returns the current installed plugin version.
    * VerificationToken.lua     - Checks validity of the API token.
    * TokenUpdater.lua          - Handles token renewal/update.

=====================================================================
Scripts That Use This Script
---------------------------------------------------------------------
- This script is typically referenced in **Plugin Manager** configuration
  (`Info.lua` → `LrPluginInfoProvider` entry) to define the configuration panel.

=====================================================================
Execution Steps
---------------------------------------------------------------------
Step 1: Import required Lightroom SDK modules.
Step 2: Import internal helper modules.
Step 3: Create the top-of-dialog section for the Plugin Manager UI.
Step 4: Initialize the "Latest GitHub version" field (default placeholder).
Step 5: Initialize the "Plugin current version" field.
Step 6: Add checkbox to enable/disable logging.
Step 7: Start async task to fetch GitHub version upon dialog load.
Step 8: Create "Refresh GitHub version" button with on-click action.
Step 9: Create "Configure token" button with token validation logic.
Step 10: Create "Save" button to store logging preference.
Step 11: Return the full UI layout definition to Lightroom.

=====================================================================
Step-by-Step Detailed Descriptions
---------------------------------------------------------------------
1. Import required Lightroom modules for UI building, preferences, dialogs, and async tasks.
2. Load logging and version management modules.
3. Define the dialog section builder function (sectionsForTopOfDialog).
4. Set up UI label to display the GitHub version (placeholder until loaded).
5. Display local plugin version retrieved from Get_Current_Version.lua.
6. Provide checkbox for enabling/disabling logging.
7. Automatically fetch GitHub version when the dialog is opened (async).
8. Allow the user to manually refresh GitHub version and show status.
9. Allow the user to configure/renew API token with status checks and confirmations.
10. Save logging preference to Lightroom preferences.
11. Send the fully assembled dialog UI structure to Lightroom.

=====================================================================
]]

local LrView    = import "LrView"       -- Step 1
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrTasks   = import "LrTasks"

local logger         = require("Logger")               -- Step 2
local versionGitHub  = require("Get_Version_Github")
local currentVersion = require("Get_Current_Version").getCurrentVersion

return {
    sectionsForTopOfDialog = function(viewFactory)
        logger.logMessage("[Step 3] Building top-of-dialog section.")

        local prefs = LrPrefs.prefsForPlugin()

        -- Step 4: GitHub version label (initial placeholder)
        logger.logMessage("[Step 4] Initializing GitHub version field.")
        local githubVersionField = viewFactory:static_text { 
            title = LOC("$$$/iNat/GitHubVersionLabel=Latest GitHub version: ..."), 
            width = 400 
        }

        -- Step 5: Local plugin version label
        logger.logMessage("[Step 5] Initializing local plugin version field.")
        local localVersionField = viewFactory:static_text { 
            title = LOC("$$$/iNat/LocalVersionLabel=Plugin current version: ") .. currentVersion(), 
            width = 400 
        }

        -- Step 6: Logging checkbox
        logger.logMessage("[Step 6] Creating logging enable/disable checkbox.")
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNat/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false,
            checked_value = true,
            unchecked_value = false,
        }

        -- Step 7: Auto-fetch GitHub version asynchronously
        logger.logMessage("[Step 7] Starting async GitHub version fetch.")
        LrTasks.startAsyncTask(function()
            versionGitHub.getVersionStatusAsync(function(status)
                githubVersionField.title = LOC("$$$/iNat/GitHubVersionLabel=Latest GitHub version: ") .. status.githubTag
                logger.logMessage("GitHub version fetched: " .. status.githubTag)
            end)
        end)

        -- Step 8: Refresh GitHub version button
        logger.logMessage("[Step 8] Creating GitHub refresh button.")
        local refreshButton = viewFactory:push_button {
            title = LOC("$$$/iNat/RefreshGitHubButton=Version GitHub"),
            action = function()
                logger.logMessage("User clicked Refresh GitHub version button.")
                versionGitHub.getVersionStatusAsync(function(status)
                    githubVersionField.title = LOC("$$$/iNat/GitHubVersionLabel=Latest GitHub version: ") .. status.githubTag
                    logger.logMessage("GitHub version updated on refresh: " .. status.githubTag)
                    LrDialogs.message(
                        LOC("$$$/iNat/VersionStatusTitle=Version status"),
                        status.statusIcon .. " " .. status.statusText
                    )
                end)
            end
        }

        -- Step 9: Configure token button
        logger.logMessage("[Step 9] Creating Configure Token button.")
        local configureTokenButton = viewFactory:push_button {
            title = LOC("$$$/iNat/ConfigureTokenButton=Configure token"),
            action = function()
                logger.logMessage("User clicked Configure Token button.")
                local tokenChecker = require("VerificationToken")
                local tokenUpdater = require("TokenUpdater")

                if prefs.token and prefs.token ~= "" and tokenChecker.isTokenValid() then
                    logger.logMessage("Token is up-to-date.")
                    LrDialogs.message(
                        LOC("$$$/iNat/TokenStatusTitle=Token status"), 
                        LOC("$$$/iNat/TokenUpToDate=Token up-to-date")
                    )
                    return
                end

                logger.logMessage("Token must be renewed.")
                local choice = LrDialogs.confirm(
                    LOC("$$$/iNat/TokenStatusTitle=Token status"),
                    LOC("$$$/iNat/TokenRenewPrompt=Token must be renewed. Do you want to update it now?"),
                    LOC("$$$/iNat/OK=OK"),
                    LOC("$$$/iNat/Cancel=Cancel")
                )

                if choice == "ok" then
                    logger.logMessage("User chose to update the token.")
                    tokenUpdater.runUpdateTokenScript()
                else
                    logger.logMessage("User cancelled token update.")
                end
            end
        }

        -- Step 10: Save preferences button
        logger.logMessage("[Step 10] Creating Save button.")
        local saveButton = viewFactory:push_button {
            title = LOC("$$$/iNat/SaveButton=Save"),
            action = function()
                prefs.logEnabled = logCheck.value
                logger.logMessage("Logging preference saved: " .. tostring(logCheck.value))
            end
        }

        -- Step 11: Returning final dialog layout
        logger.logMessage("[Step 11] Returning full dialog layout to Lightroom.")
        return {
            {
                title = LOC("$$$/iNat/DialogTitle=iNaturalist connection settings"),

                viewFactory:row { spacing = viewFactory:control_spacing(), githubVersionField },
                viewFactory:row { spacing = viewFactory:control_spacing(), localVersionField },
                viewFactory:row { spacing = viewFactory:control_spacing(), refreshButton, configureTokenButton },
                viewFactory:row { spacing = viewFactory:control_spacing(), logCheck },
                viewFactory:row { spacing = viewFactory:control_spacing(), saveButton }
            }
        }
    end
}

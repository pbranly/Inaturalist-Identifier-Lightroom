--[[
====================================================================
Functional Description
--------------------------------------------------------------------
This Lightroom plugin dialog section manages the user interface for 
configuring iNaturalist integration. It enables users to:

1. View the current plugin version and the latest GitHub version.
2. Refresh the GitHub version information manually.
3. Check, refresh, and validate the iNaturalist API token (valid 24h).
4. Enable or disable logging to a local log file.
5. Save the logging preference.

The UI is built using Lightroom's LrView framework and is intended 
for the "Top of Dialog" section in the plugin manager.

--------------------------------------------------------------------
Modules and Scripts Used
--------------------------------------------------------------------
- Lightroom SDK:
  * LrView       : UI layout creation.
  * LrPrefs      : Access plugin preferences.
  * LrDialogs    : Show dialogs and messages.
  * LrTasks      : Run asynchronous tasks.
  
- Local modules:
  * Logger               : Custom logging functions.
  * Get_Version_Github   : Fetches the latest plugin version from GitHub.
  * Get_Current_Version  : Retrieves the current plugin version from Info.lua.
  * VerificationToken    : Validates the current iNaturalist API token.
  * TokenUpdater         : Runs token update process.

--------------------------------------------------------------------
Scripts That Use This Script
--------------------------------------------------------------------
- Loaded by Lightroom's Plugin Manager dialog renderer when displaying 
  the "Top of Dialog" UI for the plugin.

--------------------------------------------------------------------
Numbered Steps
--------------------------------------------------------------------
[1] Initialize plugin preferences and UI fields.
[2] Create static text for current and GitHub versions (same row).
[3] Start async task to fetch latest GitHub version on dialog load.
[4] Create "Version GitHub" refresh button to update version info.
[5] Add informational LOC text about token validity.
[6] Add editable token field with length limit.
[7] Create "Refresh Token" button for token validation/update.
[8] Create checkbox to enable/disable logging.
[9] Create "Save" button to persist logging preference.
[10] Return the structured UI layout to Lightroom.

--------------------------------------------------------------------
Step Descriptions
--------------------------------------------------------------------
[1] Loads plugin preferences using LrPrefs for storing settings.
[2] Builds two static text fields for version display on the same row.
[3] Automatically fetches the latest GitHub version asynchronously at dialog startup.
[4] Allows manual fetching of GitHub version info and displays result in a dialog box.
[5] Displays a message: "Take care that Token validity is limited to 24 hours; it must be refreshed everyday".
[6] Provides a text input field for entering/updating the API token.
[7] Checks token validity and runs update process if expired or missing; renamed button "Refresh Token".
[8] Provides user control to enable or disable logging into "log.txt".
[9] Saves logging preference to persistent plugin storage.
[10] Passes constructed dialog UI back to Lightroom's Plugin Manager.

====================================================================
--]]

local LrView    = import "LrView"
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrTasks   = import "LrTasks"

local logger         = require("Logger")
local versionGitHub  = require("Get_Version_Github")
local currentVersion = require("Get_Current_Version").getCurrentVersion

return {
    sectionsForTopOfDialog = function(viewFactory)
        logger.logMessage("[Step 1] Initializing plugin preferences and UI fields.")
        local prefs = LrPrefs.prefsForPlugin()

        -- [Step 2] Create version fields
        logger.logMessage("[Step 2] Creating static text for current and GitHub versions (same row).")
        local githubVersionField = viewFactory:static_text {
            title = LOC("$$$/iNat/LatestGitHubVersion=Latest GitHub version: ..."),
            width = 200
        }
        local localVersionField = viewFactory:static_text {
            title = LOC("$$$/iNat/CurrentVersion=Plugin current version: ") .. currentVersion(),
            width = 200
        }

        -- [Step 3] Fetch latest GitHub version async at dialog open
        logger.logMessage("[Step 3] Starting async fetch of latest GitHub version on dialog load.")
        LrTasks.startAsyncTask(function()
            versionGitHub.getVersionStatusAsync(function(status)
                githubVersionField.title = LOC("$$$/iNat/LatestGitHubVersion=Latest GitHub version: ") .. status.githubTag
                logger.logMessage("[GitHub] Auto-fetched latest version: " .. status.githubTag)
            end)
        end)

        -- [Step 4] Create refresh button
        logger.logMessage("[Step 4] Creating GitHub refresh button.")
        local refreshButton = viewFactory:push_button {
            title = LOC("$$$/iNat/RefreshGitHub=Version GitHub"),
            action = function()
                logger.logMessage("[GitHub] Manual refresh triggered.")
                versionGitHub.getVersionStatusAsync(function(status)
                    githubVersionField.title = LOC("$$$/iNat/LatestGitHubVersion=Latest GitHub version: ") .. status.githubTag
                    LrDialogs.message(
                        LOC("$$$/iNat/VersionStatus=Version status"),
                        status.statusIcon .. " " .. status.statusText
                    )
                end)
            end
        }

        -- [Step 5] Token info text
        logger.logMessage("[Step 5] Adding informational token validity text.")
        local tokenInfoText = viewFactory:static_text {
            title = LOC("$$$/iNat/TokenValidityInfo=Take care that Token validity is limited to 24 hours; it must be refreshed everyday"),
            width = 400
        }

        -- [Step 6] Editable token field (multi-line)
        logger.logMessage("[Step 6] Creating editable token field (multi-line).")
        local tokenField = viewFactory:edit_field {
        value = prefs.token or "",
        width = 400,
        min_width = 200,
        max_width = 400,
        height = 50,       -- approx. 2 lines
        min_height = 50,
        max_height = 100,  -- allow some vertical growth if needed
        enabled = true,
        wrap = true        -- enable word wrap
        }


        -- [Step 7] Refresh Token button
        logger.logMessage("[Step 7] Creating 'Refresh Token' button.")
        local refreshTokenButton = viewFactory:push_button {
            title = LOC("$$$/iNat/RefreshToken=Refresh Token"),
            action = function()
                local tokenChecker = require("VerificationToken")
                local tokenUpdater = require("TokenUpdater")
                local tokenValue = tokenField.value

                if tokenValue ~= "" and tokenChecker.isTokenValid(tokenValue) then
                    logger.logMessage("[Token] Token is up-to-date.")
                    LrDialogs.message(
                        LOC("$$$/iNat/TokenStatus=Token status"),
                        LOC("$$$/iNat/TokenUpToDate=Token up-to-date")
                    )
                    return
                end

                logger.logMessage("[Token] Token must be renewed.")
                local choice = LrDialogs.confirm(
                    LOC("$$$/iNat/TokenStatus=Token status"),
                    LOC("$$$/iNat/TokenRenewPrompt=Token must be renewed. Do you want to update it now?"),
                    LOC("$$$/iNat/OK=OK"),
                    LOC("$$$/iNat/Cancel=Cancel")
                )

                if choice == "ok" then
                    logger.logMessage("[Token] User chose to update the token.")
                    tokenUpdater.runUpdateTokenScript(tokenValue)
                else
                    logger.logMessage("[Token] User cancelled token update.")
                end
            end
        }

        -- [Step 8] Logging checkbox
        logger.logMessage("[Step 8] Creating logging enable/disable checkbox.")
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNat/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false,
            checked_value = true,
            unchecked_value = false,
        }

        -- [Step 9] Save button
        logger.logMessage("[Step 9] Creating save button for logging preference.")
        local saveButton = viewFactory:push_button {
            title = LOC("$$$/iNat/Save=Save"),
            action = function()
                prefs.logEnabled = logCheck.value
                prefs.token = tokenField.value
                logger.logMessage("[Preferences] Logging preference saved: " .. tostring(logCheck.value))
                logger.logMessage("[Preferences] Token saved.")
            end
        }

        -- [Step 10] Return UI layout
        logger.logMessage("[Step 10] Returning final dialog UI structure.")
        return {
            {
                title = LOC("$$$/iNat/DialogTitle=iNaturalist connection settings"),

                -- Combined row: Current version | Latest GitHub version
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    localVersionField,
                    viewFactory:static_text {
                        title = LOC("$$$/iNat/VersionSeparator= | "),
                        width = 20
                    },
                    githubVersionField
                },

                -- Row: GitHub refresh button
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    refreshButton
                },

                -- Row: token info text
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    tokenInfoText
                },

                -- Row: editable token field
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    tokenField
                },

                -- Row: Refresh Token button
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    refreshTokenButton
                },

                -- Row: logging checkbox
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    logCheck
                },

                -- Row: save button
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    saveButton
                }
            }
        }
    end
}

--[[
====================================================================
Functional Description
--------------------------------------------------------------------
This Lightroom plugin dialog section manages the user interface for 
configuring iNaturalist integration. It enables users to:

1. View the current plugin version and the latest GitHub version.
2. Download or refresh the latest GitHub version.
3. Configure and validate the iNaturalist API token.
4. Enable or disable logging to a local log file.
5. Save the logging preference.

The UI is built using Lightroom's LrView framework and is intended 
for the "Top of Dialog" section in the plugin manager.

Modules and Scripts Used:
- Lightroom SDK:
  * LrView       : UI layout creation.
  * LrPrefs      : Access plugin preferences.
  * LrDialogs    : Show dialogs and messages.
  * LrTasks      : Run asynchronous tasks.
  * LrHttp       : Open URLs in browser.
  * LrLocalization : LOC() for internationalization.
  
- Local modules:
  * Logger               : Custom logging functions.
  * Get_Version_Github   : Fetches the latest plugin version from GitHub.
  * Get_Current_Version  : Retrieves the current plugin version from Info.lua.
  * VerificationToken    : Validates the current iNaturalist API token.
  * TokenUpdater         : Runs token update process.

Scripts That Use This Script:
- Loaded by Lightroom's Plugin Manager dialog renderer when displaying 
  the "Top of Dialog" UI for the plugin.

Numbered Steps:
[1] Initialize plugin preferences and UI fields.
[2] Create static text for current and GitHub versions (same row).
[3] Start async task to fetch latest GitHub version on dialog load.
[4] Create "Download last Github version" button with conditional prompt.
[5] Create token configuration fields and "Refresh Token" button.
[6] Create checkbox to enable/disable logging.
[7] Create "Save" button to persist logging preference.
[8] Return the structured UI layout to Lightroom.

Step Descriptions:
[1] Loads plugin preferences using LrPrefs for storing settings.
[2] Builds two static text fields for version display and arranges them on one row.
[3] Automatically fetches the latest GitHub version asynchronously at dialog startup.
[4] Provides a button to download the latest GitHub version. Shows "Version uptodate" if plugin is current; otherwise asks "Do you want to download the new version?" and opens GitHub on OK.
[5] Adds a text field to display/edit the token and a button to refresh it if expired.
[6] Provides user control to enable or disable logging into "log.txt".
[7] Saves logging preference to persistent plugin storage.
[8] Passes constructed dialog UI back to Lightroom's Plugin Manager.
====================================================================
--]]

local LrView    = import "LrView"
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrTasks   = import "LrTasks"
local LrHttp    = import "LrHttp"
local LrLocalization = import 'LrLocalization'

local logger         = require("Logger")
local versionGitHub  = require("Get_Version_Github")
local currentVersion = require("Get_Current_Version").getCurrentVersion

local LOC = (LrLocalization and LrLocalization.LOC) or function(s) return s:gsub("%$%$%$/.-=", "") end

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

        -- [Step 4] Download last GitHub version button
        logger.logMessage("[Step 4] Creating Download last GitHub version button.")
        local downloadGithubButton = viewFactory:push_button {
            title = LOC("$$$/iNat/DownloadLastGithubVersion=Download last Github version"),
            action = function()
                logger.logMessage("[GitHub] Download last version button clicked.")
                versionGitHub.getVersionStatusAsync(function(status)
                    LrTasks.runOnMainThread(function()
                        local message, openUrl
                        if status.currentVersion == status.githubTag then
                            message = LOC("$$$/iNat/VersionUpToDate=Version uptodate")
                            openUrl = nil
                        else
                            message = LOC("$$$/iNat/DownloadPrompt=Do you want to download the new version?")
                            openUrl = "https://api.github.com/repos/pbranly/Inaturalist-Identifier-Lightroom/releases/latest"
                        end

                        if openUrl then
                            local choice = LrDialogs.confirm(
                                LOC("$$$/iNat/VersionStatus=Version status"),
                                message,
                                LOC("$$$/iNat/OK=OK"),
                                LOC("$$$/iNat/Cancel=Cancel")
                            )
                            if choice == "ok" then
                                logger.logMessage("[GitHub] User chose to open GitHub URL: " .. openUrl)
                                LrHttp.openUrlInBrowser(openUrl)
                            else
                                logger.logMessage("[GitHub] User cancelled GitHub download.")
                            end
                        else
                            LrDialogs.message(
                                LOC("$$$/iNat/VersionStatus=Version status"),
                                message
                            )
                            logger.logMessage("[GitHub] Plugin version is up-to-date.")
                        end
                    end)
                end)
            end
        }

        -- [Step 5] Create token editable field + Refresh Token button
        logger.logMessage("[Step 5] Creating token field and refresh button.")
        local tokenField = viewFactory:edit_field {
            value = prefs.token or "",
            width_in_chars = 90,
            height_in_lines = 2
        }

        local refreshTokenButton = viewFactory:push_button {
            title = LOC("$$$/iNat/RefreshToken=Refresh Token"),
            action = function()
                local tokenChecker = require("VerificationToken")
                local tokenUpdater = require("TokenUpdater")

                if prefs.token and prefs.token ~= "" and tokenChecker.isTokenValid() then
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
                    tokenUpdater.runUpdateTokenScript()
                else
                    logger.logMessage("[Token] User cancelled token update.")
                end
            end
        }

        -- Info line about token validity
        local tokenInfoLine = viewFactory:static_text {
            title = LOC("$$$/iNat/TokenValidityInfo=Take care that Token validity is limited to 24 hours; it must be refreshed everyday"),
            width = 500
        }

        -- [Step 6] Create logging checkbox
        logger.logMessage("[Step 6] Creating logging enable/disable checkbox.")
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNat/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false,
            checked_value = true,
            unchecked_value = false,
        }

        -- [Step 7] Create save button
        logger.logMessage("[Step 7] Creating save button for logging preference.")
        local saveButton = viewFactory:push_button {
            title = LOC("$$$/iNat/Save=Save"),
            action = function()
                prefs.logEnabled = logCheck.value
                logger.logMessage("[Preferences] Logging preference saved: " .. tostring(logCheck.value))
            end
        }

        -- [Step 8] Return UI layout
        logger.logMessage("[Step 8] Returning final dialog UI structure.")
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

                -- Row: Download last GitHub version button
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    downloadGithubButton
                },

                -- Row: token info line
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    tokenInfoLine
                },

                -- Row: token editable field
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

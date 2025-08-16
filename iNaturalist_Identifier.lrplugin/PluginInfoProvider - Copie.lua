--[[
====================================================================
Functional Description
--------------------------------------------------------------------
This Lightroom plugin dialog section manages the user interface for 
configuring iNaturalist integration.

Features:
1. View current plugin version and latest GitHub version.
2. Download the latest GitHub version if outdated.
3. Token field with multiline display and validity info.
4. Refresh Token button below token.
5. Enable/disable logging with save button.

Modules:
- LrView, LrPrefs, LrDialogs, LrTasks, LrHttp
- Logger, Get_Version_Github, Get_Current_Version, VerificationToken, TokenUpdater

Execution Steps:
1. Initialize preferences and UI fields.
2. Display current & GitHub versions.
3. Fetch latest GitHub version async.
4. Download latest GitHub version button.
5. Token field with multiline and comment.
6. Refresh Token button below token.
7. Logging checkbox and save button.
8. Return dialog UI.
====================================================================
--]]

local LrView    = import "LrView"
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrTasks   = import "LrTasks"
local LrHttp    = import "LrHttp"

local logger         = require("Logger")
local versionGitHub  = require("Get_Version_Github")
local currentVersion = require("Get_Current_Version").getCurrentVersion

--local LOC = function(s) return s:gsub("%$%$%$/.-=", "") end

return {
    sectionsForTopOfDialog = function(viewFactory)
        logger.logMessage("[Step 1] Initializing plugin preferences and UI fields.")
        local prefs = LrPrefs.prefsForPlugin()

        -- [Step 2] Version fields
        logger.logMessage("[Step 2] Creating version fields.")
        local githubVersionField = viewFactory:static_text {
            title = LOC("$$$/iNat/LatestGitHubVersion=Latest GitHub version: ..."),
            width = 200
        }
        local localVersionField = viewFactory:static_text {
            title = LOC("$$$/iNat/CurrentVersion=Plugin current version: ") .. currentVersion(),
            width = 200
        }

        -- [Step 3] Fetch GitHub version async
        LrTasks.startAsyncTask(function()
            versionGitHub.getVersionStatusAsync(function(status)
                githubVersionField.title = LOC("$$$/iNat/LatestGitHubVersion=Latest GitHub version: ") .. status.githubTag
                logger.logMessage("[GitHub] Auto-fetched latest version: " .. status.githubTag)
            end)
        end)

        -- [Step 4] Download latest GitHub version button
        logger.logMessage("[Step 4] Creating Download latest GitHub version button.")
        local downloadButton = viewFactory:push_button {
            title = LOC("$$$/iNat/DownloadGitHub=Download last Github version"),
            action = function()
                versionGitHub.getVersionStatusAsync(function(status)
                    if status.currentVersion == status.githubTag then
                        LrDialogs.message(
                            LOC("$$$/iNat/VersionUpToDate=Version uptodate")
                        )
                    else
                        local choice = LrDialogs.confirm(
                            LOC("$$$/iNat/NewVersion=New version available"),
                            LOC("$$$/iNat/DownloadPrompt=Do you want to download the new version?"),
                            LOC("$$$/iNat/OK=OK"),
                            LOC("$$$/iNat/Cancel=Cancel")
                        )
                        if choice == "ok" then
                            LrTasks.startAsyncTask(function()
                                LrHttp.openUrlInBrowser("https://github.com/pbranly/Inaturalist-Identifier-Lightroom/releases/latest")
                            end)
                        end
                    end
                end)
            end
        }

        -- [Step 5] Token field with multiline
        logger.logMessage("[Step 5] Creating token field.")
        local tokenField = viewFactory:edit_field {
            value = prefs.token or "",
            width = 500,
			min_width = 500,
            height = 80, -- allows approx. 2 lines
			wrap = true,        -- indispensable pour forcer le retour à la ligne
            tooltip = LOC("$$$/iNat/TokenTooltip=Your iNaturalist API token")
        }

        -- Comment below GitHub button
        local tokenComment = viewFactory:static_text {
            title = LOC("$$$/iNat/TokenReminder=Take care that Token validity is limited to 24 hours; it must be refreshed every day"),
            width = 500
        }

        -- [Step 6] Refresh Token button below token
        logger.logMessage("[Step 6] Creating Refresh Token button.")
        local refreshTokenButton = viewFactory:push_button {
            title = LOC("$$$/iNat/RefreshToken=Refresh Token"),
            action = function()
                local tokenUpdater = require("TokenUpdater")
                tokenUpdater.runUpdateTokenScript()
            end
        }

        -- [Step 7] Logging checkbox
        logger.logMessage("[Step 7] Creating logging checkbox.")
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNat/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false,
            checked_value = true,
            unchecked_value = false,
        }

        -- [Step 8] Save button
        logger.logMessage("[Step 8] Creating save button.")
        local saveButton = viewFactory:push_button {
            title = LOC("$$$/iNat/Save=Save"),
            action = function()
                prefs.logEnabled = logCheck.value
                prefs.token = tokenField.value
                logger.logMessage("[Preferences] Logging saved, token updated.")
            end
        }

        -- Return UI layout
        logger.logMessage("[Step 9] Returning final UI layout.")
        return {
            {
                title = LOC("$$$/iNat/DialogTitle=iNaturalist connection settings"),

                -- Version row
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    localVersionField,
                    viewFactory:static_text { title = LOC("$$$/iNat/VersionSeparator= | "), width = 20 },
                    githubVersionField
                },

                -- GitHub button row
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    downloadButton
                },

                -- Token comment row
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    tokenComment
                },

                -- Token field row
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    tokenField
                },

                -- Refresh Token button row
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    refreshTokenButton
                },

                -- Logging row
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    logCheck
                },

                -- Save row
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    saveButton
                }
            }
        }
    end
}

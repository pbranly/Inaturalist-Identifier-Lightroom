--[[
====================================================================
Functional Description
--------------------------------------------------------------------
This Lightroom plugin dialog section manages the user interface for 
configuring iNaturalist integration, plugin updates, and logging.

Features:
1. View current plugin version and latest GitHub version.
2. Download the latest GitHub version if outdated.
3. Token field with multiline display and validity info.
4. Refresh Token button below token.
5. Enable/disable logging with save button.
6. Enable/disable automatic update checks.
7. Force update check immediately.

Modules and Scripts Used:
- LrView, LrPrefs, LrDialogs, LrTasks, LrHttp (Lightroom SDK)
- Logger.lua
- Update_plugin.lua (provides getCurrentVersion(), getLatestGitHubVersion(), and forceUpdate())
- TokenUpdater.lua

Execution Steps:
1. Initialize plugin preferences and UI fields.
2. Display current plugin version and latest GitHub version.
3. Fetch latest GitHub version asynchronously.
4. Create button to download latest GitHub version.
5. Create token field with multiline input.
6. Add Refresh Token button.
7. Add logging enable checkbox.
8. Add automatic update check checkbox and "Check now" button.
9. Create Save button for preferences.
10. Return dialog UI layout.
====================================================================
--]]

local LrView    = import "LrView"
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrTasks   = import "LrTasks"
local LrHttp    = import "LrHttp"

local logger  = require("Logger")
local Updates = require("Update_plugin")  -- Provides getCurrentVersion(), getLatestGitHubVersion(), and forceUpdate()

local bind = LrView.bind

return {
    sectionsForTopOfDialog = function(viewFactory)
        -- Step 1: Initialize plugin preferences
        logger.logMessage("[Step 1] Initializing plugin preferences and UI fields.")
        local prefs = LrPrefs.prefsForPlugin()
        if prefs.checkForUpdates == nil then
            prefs.checkForUpdates = true
        end

        -- Step 2: Display version fields
        logger.logMessage("[Step 2] Creating version fields.")
        local githubVersionField = viewFactory:static_text {
            title = LOC("$$$/iNat/LatestGitHubVersion=Latest GitHub version: ..."),
            width = 200
        }
        local localVersionField = viewFactory:static_text {
            title = LOC("$$$/iNat/CurrentVersion=Plugin current version: ") .. Updates.getCurrentVersion(),
            width = 200
        }

        -- Step 3: Fetch latest GitHub version asynchronously
        LrTasks.startAsyncTask(function()
            local latestTag = Updates.getLatestGitHubVersion() or "?"
            githubVersionField.title = LOC("$$$/iNat/LatestGitHubVersion=Latest GitHub version: ") .. latestTag
            logger.logMessage("[GitHub] Auto-fetched latest version: " .. tostring(latestTag))
        end)

        -- Step 4: Download latest GitHub version button
        logger.logMessage("[Step 4] Creating Download latest GitHub version button.")
        local downloadButton = viewFactory:push_button {
            title = LOC("$$$/iNat/DownloadGitHub=Download last Github version"),
            action = function()
                local latestTag = Updates.getLatestGitHubVersion() or "?"
                if Updates.getCurrentVersion() == latestTag then
                    LrDialogs.message(
                        LOC("$$$/iNat/VersionUpToDate=Version up to date")
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
                            -- Open GitHub latest release page
                            LrHttp.openUrlInBrowser("https://github.com/pbranly/Inaturalist-Identifier-Lightroom/releases/latest")
                        end)
                    end
                end
            end
        }

        -- Step 5: Token field with multiline input
        logger.logMessage("[Step 5] Creating token field.")
        local tokenField = viewFactory:edit_field {
            value = prefs.token or "",
            width = 500,
            min_width = 500,
            height = 80, -- allows approx. 2 lines
            wrap = true, -- force line breaks
            tooltip = LOC("$$$/iNat/TokenTooltip=Your iNaturalist API token")
        }

        -- Token comment below GitHub button
        local tokenComment = viewFactory:static_text {
            title = LOC("$$$/iNat/TokenReminder=Take care that Token validity is limited to 24 hours; it must be refreshed every day"),
            width = 500
        }

        -- Step 6: Refresh Token button
        logger.logMessage("[Step 6] Creating Refresh Token button.")
        local refreshTokenButton = viewFactory:push_button {
            title = LOC("$$$/iNat/RefreshToken=Refresh Token"),
            action = function()
                local tokenUpdater = require("TokenUpdater")
                tokenUpdater.runUpdateTokenScript()
            end
        }

        -- Step 7: Logging enable checkbox
        logger.logMessage("[Step 7] Creating logging checkbox.")
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNat/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false,
            checked_value = true,
            unchecked_value = false,
        }

        -- Step 8: Automatic update check and "Check now" button
        logger.logMessage("[Step 8] Creating update preferences rows.")
        local autoUpdateRow = viewFactory:row {
            spacing = viewFactory:control_spacing(),
            viewFactory:static_text {
                title = LOC("$$$/iNat/AutoUpdateCheck=Automatically check for updates"),
                alignment = "right",
                width = 200
            },
            viewFactory:checkbox {
                value = bind("checkForUpdates")
            }
        }

        local checkNowRow = viewFactory:row {
            spacing = viewFactory:control_spacing(),
            viewFactory:static_text {
                title = LOC("$$$/iNat/CheckUpdatesNow=Check for updates now"),
                alignment = "right",
                width = 200
            },
            viewFactory:push_button {
                title = LOC("$$$/iNat/Go=Go"),
                action = Updates.forceUpdate
            }
        }

        -- Step 9: Save button for preferences
        logger.logMessage("[Step 9] Creating save button.")
        local saveButton = viewFactory:push_button {
            title = LOC("$$$/iNat/Save=Save"),
            action = function()
                prefs.logEnabled = logCheck.value
                prefs.token = tokenField.value
                logger.logMessage("[Preferences] Logging saved, token updated.")
            end
        }

        -- Step 10: Return dialog UI layout
        logger.logMessage("[Step 10] Returning final UI layout.")
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

                -- GitHub download button row
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

                -- Logging checkbox row
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    logCheck
                },

                -- Automatic update check row
                autoUpdateRow,

                -- Check updates now row
                checkNowRow,

                -- Save button row
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    saveButton
                }
            }
        }
    end
}

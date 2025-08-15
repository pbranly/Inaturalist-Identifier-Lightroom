--[[============================================================================
PluginInfoProvider.lua
-------------------------------------------------------------------------------
Functional Description:
This script defines the user interface section for configuring the iNaturalist Publish Plugin
in Adobe Lightroom. It displays the current plugin version, checks for updates from GitHub,
allows downloading the latest version, and manages the iNaturalist API token and logging preferences.

Features:
1. Display current plugin version and latest GitHub version.
2. Check GitHub asynchronously for updates.
3. Prompt user to download new version if available.
4. Show and edit iNaturalist API token.
5. Refresh token via external script.
6. Enable/disable logging and save preferences.

Modules and Scripts Used:
- LrView         : UI layout and controls
- LrPrefs        : Plugin preferences
- LrDialogs      : Dialog prompts
- LrTasks        : Asynchronous execution
- LrHttp         : Open browser for download
- Logger.lua     : Logging internal steps and events
- Updates_from_github.lua : GitHub version check logic
- TokenUpdater.lua : Refresh token logic

Scripts That Use This Script:
- Lightroom plugin manifest (Info.lua) references this as the top-level dialog section

Execution Steps:
1. Initialize plugin preferences and UI fields
2. Create version display fields
3. Fetch GitHub version asynchronously
4. Create download button for latest GitHub version
5. Create token field and comment
6. Create refresh token button
7. Create logging checkbox
8. Create save button
9. Return final UI layout

============================================================================]]

-- Step 0: Import required modules
local LrView    = import "LrView"
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrTasks   = import "LrTasks"
local LrHttp    = import "LrHttp"

local logger = require("Logger")                    -- Logging utility
local githubUpdater = require("Updates_from_github") -- GitHub version checker

-- Return dialog section definition
return {
    sectionsForTopOfDialog = function(viewFactory)

        -- Step 1: Initialize preferences
        logger.logMessage("[Step 1] Initializing plugin preferences and UI fields.")
        local prefs = LrPrefs.prefsForPlugin()

        -- Step 2: Create version display fields
        logger.logMessage("[Step 2] Creating version fields.")
        local githubVersionField = viewFactory:static_text {
            title = LOC("$$$/iNat/LatestGitHubVersion=Latest GitHub version: ..."),
            width = 200
        }
        local localVersionField = viewFactory:static_text {
            title = LOC("$$$/iNat/CurrentVersion=Plugin current version: ..."),
            width = 200
        }

        -- Step 3: Fetch GitHub version asynchronously
        logger.logMessage("[Step 3] Fetching GitHub version asynchronously.")
        LrTasks.startAsyncTask(function()
            githubUpdater.getGitHubVersionInfoAsync(function(info)
                githubVersionField.title = LOC("$$$/iNat/LatestGitHubVersion=Latest GitHub version: ") .. info.latest
                localVersionField.title = LOC("$$$/iNat/CurrentVersion=Plugin current version: ") .. info.current
                logger.logMessage("[GitHub] Fetched version info: current=" .. info.current .. ", latest=" .. info.latest)
            end)
        end)

        -- Step 4: Create download button
        logger.logMessage("[Step 4] Creating Download latest GitHub version button.")
        local downloadButton = viewFactory:push_button {
            title = LOC("$$$/iNat/DownloadGitHub=Download latest GitHub version"),
            action = function()
                githubUpdater.getGitHubVersionInfoAsync(function(info)
                    logger.logMessage("[GitHub] Download button clicked. Current=" .. info.current .. ", Latest=" .. info.latest)

                    -- Normalize versions by removing leading "v"
                    local normalizedCurrent = info.current:gsub("^v", "")
                    local normalizedLatest = info.latest:gsub("^v", "")

                    if normalizedCurrent == normalizedLatest then
                        LrDialogs.message(LOC("$$$/iNat/VersionUpToDate=Version is up to date"))
                        logger.logMessage("[GitHub] Plugin is already up to date.")
                    else
                        local choice = LrDialogs.confirm(
                            LOC("$$$/iNat/NewVersion=New version available"),
                            LOC("$$$/iNat/DownloadPrompt=Do you want to download the new version?"),
                            LOC("$$$/iNat/OK=OK"),
                            LOC("$$$/iNat/Cancel=Cancel")
                        )
                        logger.logMessage("[GitHub] User choice on update prompt: " .. choice)
                        if choice == "ok" then
                            LrTasks.startAsyncTask(function()
                                logger.logMessage("[GitHub] Opening browser to download latest release.")
                                LrHttp.openUrlInBrowser("https://github.com/pbranly/Inaturalist-Identifier-Lightroom/releases/latest")
                            end)
                        end
                    end
                end)
            end
        }

        -- Step 5: Create token field and comment
        logger.logMessage("[Step 5] Creating token field.")
        local tokenField = viewFactory:edit_field {
            value = prefs.token or "",
            width = 500,
            min_width = 500,
            height = 80,
            wrap = true,
            tooltip = LOC("$$$/iNat/TokenTooltip=Your iNaturalist API token")
        }

        local tokenComment = viewFactory:static_text {
            title = LOC("$$$/iNat/TokenReminder=Token validity is limited to 24 hours; refresh daily."),
            width = 500
        }

        -- Step 6: Create refresh token button
        logger.logMessage("[Step 6] Creating Refresh Token button.")
        local refreshTokenButton = viewFactory:push_button {
            title = LOC("$$$/iNat/RefreshToken=Refresh Token"),
            action = function()
                logger.logMessage("[Token] Refresh button clicked.")
                local tokenUpdater = require("TokenUpdater")
                tokenUpdater.runUpdateTokenScript()
                logger.logMessage("[Token] Token refresh script executed.")
            end
        }

        -- Step 7: Create logging checkbox
        logger.logMessage("[Step 7] Creating logging checkbox.")
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNat/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false,
            checked_value = true,
            unchecked_value = false,
        }

        -- Step 8: Create save button
        logger.logMessage("[Step 8] Creating save button.")
        local saveButton = viewFactory:push_button {
            title = LOC("$$$/iNat/Save=Save"),
            action = function()
                prefs.logEnabled = logCheck.value
                prefs.token = tokenField.value
                logger.logMessage("[Preferences] Logging preference saved: " .. tostring(prefs.logEnabled))
                logger.logMessage("[Preferences] Token updated.")
            end
        }

        -- Step 9: Return final UI layout
        logger.logMessage("[Step 9] Returning final UI layout.")
        return {
            {
                title = LOC("$$$/iNat/DialogTitle=iNaturalist connection settings"),

                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    localVersionField,
                    viewFactory:static_text { title = LOC("$$$/iNat/VersionSeparator= | "), width = 20 },
                    githubVersionField
                },

                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    downloadButton
                },

                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    tokenComment
                },

                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    tokenField
                },

                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    refreshTokenButton
                },

                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    logCheck
                },

                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    saveButton
                }
            }
        }
    end
}
--[[============================================================================
PluginInfoProvider.lua
-------------------------------------------------------------------------------
Functional Description:
This script defines the user interface section for configuring the iNaturalist Publish Plugin
in Adobe Lightroom. It displays the current plugin version, checks for updates from GitHub,
allows downloading and installing the latest version, and manages the iNaturalist API token
and logging preferences.

============================================================================]]

local LrView    = import "LrView"
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrTasks   = import "LrTasks"

local logger = require("Logger")
local githubUpdater = require("Updates_from_github")

return {
    sectionsForTopOfDialog = function(viewFactory)
        logger.logMessage("[UI] Initializing plugin preferences and UI fields.")
        local prefs = LrPrefs.prefsForPlugin()

        -- Version display fields
        local githubVersionField = viewFactory:static_text {
            title = LOC("$$$/iNat/LatestGitHubVersion=Latest GitHub version: ..."),
            width = 200
        }
        local localVersionField = viewFactory:static_text {
            title = LOC("$$$/iNat/CurrentVersion=Plugin current version: ..."),
            width = 200
        }

        -- Fetch GitHub version asynchronously
        LrTasks.startAsyncTask(function()
            githubUpdater.getGitHubVersionInfoAsync(function(info)
                githubVersionField.title = LOC("$$$/iNat/LatestGitHubVersion=Latest GitHub version: ") .. info.latest
                localVersionField.title = LOC("$$$/iNat/CurrentVersion=Plugin current version: ") .. info.current
                logger.logMessage("[GitHub] Fetched version info: current=" .. info.current .. ", latest=" .. info.latest)
            end)
        end)

        -- Download and install button
        local downloadButton = viewFactory:push_button {
            title = LOC("$$$/iNat/DownloadGitHub=Download and install latest GitHub version"),
            action = function()
                githubUpdater.getGitHubVersionInfoAsync(function(info)
                    logger.logMessage("[GitHub] Download button clicked. Current=" .. info.current .. ", Latest=" .. info.latest)

                    local normalizedCurrent = info.current:gsub("^v", "")
                    local normalizedLatest = info.latest:gsub("^v", "")

                    if normalizedCurrent == normalizedLatest then
                        LrDialogs.message(LOC("$$$/iNat/VersionUpToDate=Version is up to date"))
                        logger.logMessage("[GitHub] Plugin is already up to date.")
                    else
                        local choice = LrDialogs.confirm(
                            LOC("$$$/iNat/NewVersion=New version available"),
                            LOC("$$$/iNat/DownloadPrompt=Do you want to download and install the new version?"),
                            LOC("$$$/iNat/OK=OK"),
                            LOC("$$$/iNat/Cancel=Cancel")
                        )
                        logger.logMessage("[GitHub] User choice on update prompt: " .. choice)
                        if choice == "ok" then
                            LrTasks.startAsyncTask(function()
                                logger.logMessage("[GitHub] Launching automatic update...")
                                githubUpdater.downloadAndInstall({
                                    tag_name = info.latest,
                                    assets = {
                                        {
                                            browser_download_url = "https://github.com/pbranly/Inaturalist-Identifier-Lightroom/releases/download/" .. info.latest .. "/Inaturalist-Identifier.lrplugin.tar.gz"
                                        }
                                    }
                                })
                            end)
                        end
                    end
                end)
            end
        }

        -- Token field
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

        -- Refresh token button
        local refreshTokenButton = viewFactory:push_button {
            title = LOC("$$$/iNat/RefreshToken=Refresh Token"),
            action = function()
                logger.logMessage("[Token] Refresh button clicked.")
                local tokenUpdater = require("TokenUpdater")
                tokenUpdater.runUpdateTokenScript()
                logger.logMessage("[Token] Token refresh script executed.")
            end
        }

        -- Logging checkbox
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNat/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false,
            checked_value = true,
            unchecked_value = false,
        }

        -- Save button
        local saveButton = viewFactory:push_button {
            title = LOC("$$$/iNat/Save=Save"),
            action = function()
                prefs.logEnabled = logCheck.value
                prefs.token = tokenField.value
                logger.logMessage("[Preferences] Logging preference saved: " .. tostring(prefs.logEnabled))
                logger.logMessage("[Preferences] Token updated.")
            end
        }

        -- Final UI layout
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

--[[
====================================================================
Functional Description
--------------------------------------------------------------------
This script (`PluginInfoProvider.lua`) manages the configuration dialog
for the iNaturalist Lightroom plugin. It provides a user interface to:

1. Display the current plugin version and the latest GitHub release version.
2. Allow the user to manually check for updates and download the latest version.
3. Display and manage the iNaturalist API token.
4. Refresh the API token using the `TokenUpdater.lua` helper.
5. Enable or disable detailed logging.
6. Save preferences for persistence across Lightroom sessions.

⚠️ Automatic update checks have been removed. Only manual update actions are possible.

--------------------------------------------------------------------
Modules and Scripts Used:
- Lightroom SDK:
  - LrView (UI elements)
  - LrPrefs (plugin preferences storage)
  - LrDialogs (dialogs and alerts)
  - LrTasks (asynchronous tasks)
  - LrHttp (HTTP requests)
- Logger.lua (custom logging wrapper)
- Update_plugin.lua (handles version management and manual update check)
- TokenUpdater.lua (handles API token refresh)

--------------------------------------------------------------------
Scripts Using This Script:
- Declared in `Info.lua` under:
    LrPluginInfoProvider = "PluginInfoProvider.lua"

--------------------------------------------------------------------
Execution Steps:
1. Initialize plugin preferences.
2. Display current plugin version.
3. Fetch the latest GitHub release version asynchronously.
4. Display button to open GitHub release page in browser.
5. Manual update check with confirmation dialog if update exists.
6. Display API token status and input field.
7. Provide button to refresh token.
8. Provide checkbox to enable/disable logging.
9. Save button to persist preferences.

====================================================================
--]]

local LrView    = import "LrView"
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrTasks   = import "LrTasks"
local LrHttp    = import "LrHttp"

local logger       = require("Logger")
local Updates      = require("Update_plugin")
local TokenUpdater = require("TokenUpdater")

local bind = LrView.bind

return {
    sectionsForTopOfDialog = function(viewFactory)
        local prefs = LrPrefs.prefsForPlugin()

        -- Step 1: Initialize preferences
        logger.logMessage("[PluginInfoProvider.lua] [Step 1] Preferences initialized.")

        -- Step 2: Current plugin version
        local localVersion = Updates.getCurrentVersion()
        logger.logMessage("[PluginInfoProvider.lua] [Step 2] Current plugin version: " .. tostring(localVersion))

        local localVersionField = viewFactory:static_text {
            title = LOC("$$$/iNat/CurrentVersion=Plugin current version: ") .. localVersion,
            width = 250
        }

        -- Step 3: Latest GitHub release version (initially unknown)
        local githubVersionField = viewFactory:static_text {
            title = LOC("$$$/iNat/LatestGitHubVersion=Latest GitHub version: ..."),
            width = 250
        }

        -- Step 4: Manual download button
        local downloadButton = viewFactory:push_button {
            title = LOC("$$$/iNat/DownloadGitHub=Download latest GitHub version"),
            action = function()
                logger.logMessage("[PluginInfoProvider.lua] [Step 4] User clicked 'Download latest GitHub version'.")
                LrTasks.startAsyncTask(function()
                    local url = "https://github.com/pbranly/Inaturalist-Identifier-Lightroom/releases/latest"
                    logger.logMessage("[PluginInfoProvider.lua] [Step 4] Opening browser at: " .. url)
                    LrHttp.openUrlInBrowser(url)
                end)
            end
        }

        -- Step 5: Manual update check with confirmation dialog
        local updateButton = viewFactory:push_button {
            title = LOC("$$$/iNat/Go=Go"),
            enabled = false, -- Will be enabled after fetching latest version
            action = function()
                logger.logMessage("[PluginInfoProvider.lua] [Step 5] User triggered manual update check.")
                LrTasks.startAsyncTask(function()
                    local current = Updates.getCurrentVersion()
                    local latest = Updates.getLatestGitHubVersion()
                    local function normalizeVersion(v) return (v or ""):gsub("^v", "") end

                    logger.logMessage("[PluginInfoProvider.lua] [Step 5] Comparing versions: local=" .. tostring(current) .. ", github=" .. tostring(latest))

                    if normalizeVersion(current) == normalizeVersion(latest) then
                        LrDialogs.message(
                            LOC("$$$/iNat/PluginName=iNaturalist Identification"),
                            "Your version is up to date (" .. current .. ")",
                            "info"
                        )
                        logger.logMessage("[PluginInfoProvider.lua] [Step 5] Plugin is up to date: " .. current)
                    else
                        local result = LrDialogs.confirm(
                            LOC("$$$/iNat/PluginName=iNaturalist Identification"),
                            "A new version is available (" .. latest .. "). Do you want to update?",
                            "Yes",
                            "No"
                        )
                        if result == "ok" then
                            logger.logMessage("[PluginInfoProvider.lua] [Step 5] User confirmed update.")
                            Updates.forceUpdate()
                        else
                            logger.logMessage("[PluginInfoProvider.lua] [Step 5] User declined update.")
                        end
                    end
                end)
            end
        }

        local checkNowRow = viewFactory:row {
            spacing = viewFactory:control_spacing(),
            viewFactory:static_text {
                title = LOC("$$$/iNat/CheckUpdatesNow=Check for updates now"),
                alignment = "right",
                width = 250
            },
            updateButton
        }

        -- Step 3 continued: Fetch latest GitHub version asynchronously
        LrTasks.startAsyncTask(function()
            logger.logMessage("[PluginInfoProvider.lua] [Step 3] Fetching latest GitHub release...")
            local latestTag = Updates.getLatestGitHubVersion() or "?"
            githubVersionField.title = LOC("$$$/iNat/LatestGitHubVersion=Latest GitHub version: ") .. latestTag
            logger.logMessage("[PluginInfoProvider.lua] [Step 3] Latest GitHub version fetched: " .. latestTag)
            updateButton.enabled = true
        end)

        -- Step 6: Token status and field
        local tokenStatus = TokenUpdater.getTokenStatusText()
        logger.logMessage("[PluginInfoProvider.lua] [Step 6] Token status: " .. tostring(tokenStatus))

        local tokenStatusText = viewFactory:static_text {
            title = tokenStatus,
            width = 500
        }

        local tokenField = viewFactory:edit_field {
            value = prefs.token or "",
            width = 500,
            height = 80,
            wrap = true,
            tooltip = LOC("$$$/iNat/TokenTooltip=Your iNaturalist API token")
        }

        -- Step 7: Refresh token button
        local refreshTokenButton = viewFactory:push_button {
            title = LOC("$$$/iNat/RefreshToken=Refresh Token"),
            action = function()
                logger.logMessage("[PluginInfoProvider.lua] [Step 7] User clicked 'Refresh Token'.")
                TokenUpdater.runUpdateTokenScript()
            end
        }

        -- Step 8: Logging checkbox
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNat/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false
        }

        -- Step 9: Save button
        local saveButton = viewFactory:push_button {
            title = LOC("$$$/iNat/Save=Save"),
            action = function()
                prefs.logEnabled = logCheck.value
                prefs.token = tokenField.value
                logger.logMessage("[PluginInfoProvider.lua] [Step 9] Preferences saved. Logging: "
                    .. tostring(prefs.logEnabled)
                    .. ", Token length: "
                    .. tostring(#(prefs.token or "")))
            end
        }

        -- Return final dialog layout
        return {
            {
                title = LOC("$$$/iNat/DialogTitle=iNaturalist connection settings"),
                viewFactory:row { localVersionField, viewFactory:static_text { title = " | ", width = 20 }, githubVersionField },
                viewFactory:row { downloadButton },
                checkNowRow,
                viewFactory:row { tokenStatusText },
                viewFactory:row { tokenField },
                viewFactory:row { refreshTokenButton },
                viewFactory:row { logCheck },
                viewFactory:row { saveButton }
            }
        }
    end
}

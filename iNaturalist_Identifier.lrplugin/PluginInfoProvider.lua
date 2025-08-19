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

⚠️ Note: Automatic update checks have been removed. Only manual update
actions are possible.

--------------------------------------------------------------------
Modules and Scripts Used:
- Lightroom SDK:
  - LrView (UI elements)
  - LrPrefs (plugin preferences storage)
  - LrDialogs (dialogs and alerts)
  - LrTasks (asynchronous tasks)
  - LrHttp (HTTP requests, e.g., to GitHub)
- Logger.lua (custom logging wrapper)
- Update_plugin.lua (handles version management and manual update check)
- TokenUpdater.lua (handles API token refresh)

--------------------------------------------------------------------
Scripts Using This Script:
- Declared in `Info.lua` under:
    LrPluginInfoProvider = "PluginInfoProvider.lua"

Thus, this script is used by Lightroom to render the plugin’s settings dialog.

--------------------------------------------------------------------
Execution Steps:
1. Initialize plugin preferences.
2. Display current plugin version.
3. Fetch the latest GitHub release version asynchronously.
4. Display button to open GitHub release page in browser.
5. Display button to manually check for updates.
6. Display API token status and input field.
7. Provide button to refresh token.
8. Provide checkbox to enable/disable logging.
9. Provide Save button to persist preferences.

--------------------------------------------------------------------
Step Descriptions:
1. Initialize preferences (ensures required prefs exist).
2. Read current plugin version from Update_plugin.lua.
3. Make an HTTP request to GitHub to get the latest release tag.
   - Log both the request URL and the response.
4. Display a button to open the GitHub release page in the user’s browser.
5. Display a "Check updates now" button that invokes Update_plugin.forceUpdate().
6. Display the stored iNaturalist API token and its status message.
7. Provide a button to refresh token via TokenUpdater.lua.
8. Allow the user to enable or disable detailed logging.
9. Save preferences (logging state and token value) when the Save button is clicked.

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
        logger.logMessage("[Step 1] Preferences initialized.")

        -- Step 2: Current plugin version
        local localVersion = Updates.getCurrentVersion()
        logger.logMessage("[Step 2] Current plugin version: " .. tostring(localVersion))

        local localVersionField = viewFactory:static_text {
            title = LOC("$$$/iNat/CurrentVersion=Plugin current version: ") .. localVersion,
            width = 250
        }

        -- Step 3: Latest GitHub release version
        local githubVersionField = viewFactory:static_text {
            title = LOC("$$$/iNat/LatestGitHubVersion=Latest GitHub version: ..."),
            width = 250
        }

        LrTasks.startAsyncTask(function()
            logger.logMessage("[Step 3] Starting async task to fetch latest GitHub release.")
            local url = "https://api.github.com/repos/pbranly/Inaturalist-Identifier-Lightroom/releases/latest"
            logger.logMessage("[Step 3] HTTP GET request: " .. url)

            local body, hdrs = LrHttp.get(url)
            logger.logMessage("[Step 3] HTTP Response headers: " .. tostring(hdrs))
            logger.logMessage("[Step 3] HTTP Response body: " .. tostring(body))

            local latestTag = Updates.getLatestGitHubVersion(body) or "?"
            githubVersionField.title = LOC("$$$/iNat/LatestGitHubVersion=Latest GitHub version: ") .. latestTag
            logger.logMessage("[Step 3] Latest GitHub version parsed: " .. tostring(latestTag))
        end)

        -- Step 4: Manual download button
        local downloadButton = viewFactory:push_button {
            title = LOC("$$$/iNat/DownloadGitHub=Download latest GitHub version"),
            action = function()
                logger.logMessage("[Step 4] User clicked 'Download latest GitHub version' button.")
                LrTasks.startAsyncTask(function()
                    local url = "https://github.com/pbranly/Inaturalist-Identifier-Lightroom/releases/latest"
                    logger.logMessage("[Step 4] Opening browser at: " .. url)
                    LrHttp.openUrlInBrowser(url)
                end)
            end
        }

        -- Step 5: Manual update check button
        local checkNowRow = viewFactory:row {
            spacing = viewFactory:control_spacing(),
            viewFactory:static_text {
                title = LOC("$$$/iNat/CheckUpdatesNow=Check for updates now"),
                alignment = "right",
                width = 250
            },
            viewFactory:push_button {
                title = LOC("$$$/iNat/Go=Go"),
                action = function()
                    logger.logMessage("[Step 5] User triggered manual update check.")
                    Updates.forceUpdate()
                end
            }
        }

        -- Step 6: Token status and field
        local tokenStatus = TokenUpdater.getTokenStatusText()
        logger.logMessage("[Step 6] Token status: " .. tostring(tokenStatus))

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
                logger.logMessage("[Step 7] User clicked 'Refresh Token'.")
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
                logger.logMessage("[Step 9] Preferences saved. Logging: "
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

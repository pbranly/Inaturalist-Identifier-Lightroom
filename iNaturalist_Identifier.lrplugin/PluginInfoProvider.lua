--[[
====================================================================
iNaturalist Lightroom Plugin Info Provider
--------------------------------------------------------------------
Functional Description (English):
This script manages the configuration dialog for the iNaturalist
Lightroom plugin. It provides a user interface to:

1. Display the current plugin version and the latest GitHub release version.
2. Automatically check for updates on GitHub and show update status.
3. Provide a button to update the plugin if a new version exists.
4. Display and manage the iNaturalist API token.
5. Refresh the API token using the TokenUpdater helper.
6. Enable or disable detailed logging.
7. Save preferences persistently.

No manual "Check for updates" button is required; the update status
is displayed immediately upon opening the dialog.

--------------------------------------------------------------------
Modules and Scripts Used:
- Lightroom SDK:
  - LrView (UI elements)
  - LrPrefs (plugin preferences storage)
  - LrDialogs (dialogs and alerts)
  - LrTasks (asynchronous tasks)
  - LrHttp (open browser)
- Logger.lua (custom logging)
- Update_plugin.lua (version management and updates)
- TokenUpdater.lua (API token management)

--------------------------------------------------------------------
Scripts Using This Script:
- Declared in Info.lua under:
    LrPluginInfoProvider = "PluginInfoProvider.lua"

--------------------------------------------------------------------
Execution Steps:
1. Initialize plugin preferences.
2. Display current plugin version.
3. Fetch latest GitHub release asynchronously.
4. Display update status text and Update button if needed.
5. Display API token status and input field.
6. Provide button to refresh token.
7. Provide checkbox to enable/disable logging.
8. Save preferences persistently.
====================================================================
--]]

local LrView      = import "LrView"
local LrPrefs     = import "LrPrefs"
--local LrDialogs   = import "LrDialogs" -- luacheck: ignore 512
local LrTasks     = import "LrTasks"
--local LrHttp      = import "LrHttp"    -- luacheck: ignore 512

local logger       = require("Logger")
local Updates      = require("Update_plugin")
local TokenUpdater = require("TokenUpdater")

--local bind = LrView.bind -- luacheck: ignore 512

return {
    sectionsForTopOfDialog = function(viewFactory)
        local prefs = LrPrefs.prefsForPlugin()
        logger.logMessage("[Step 1] Preferences initialized.")

        -- Step 2: Current plugin version
        local localVersion = Updates.getCurrentVersion()
        logger.logMessage("[Step 2] Current plugin version: " .. tostring(localVersion))

        local localVersionField = viewFactory:static_text {
            title = "Plugin current version: " .. localVersion,
            width = 250
        }

        -- Step 3: Latest GitHub release version placeholder
        local githubVersionField = viewFactory:static_text {
            title = "Latest GitHub version: ...",
            width = 250
        }

        -- Step 4: Update status text and optional button
        local updateStatusText = viewFactory:static_text {
            title = "Checking updates...",
            width = 400
        }

        local updateButton = viewFactory:push_button {
            title = "Update",
            enabled = false,
            action = function()
                logger.logMessage("[Step 4] User clicked Update button.")
                Updates.forceUpdate()
            end
        }

        -- Asynchronous fetch of latest GitHub version
        LrTasks.startAsyncTask(function()
            logger.logMessage("[Step 3] Fetching latest GitHub release...")
            local latest = Updates.getLatestGitHubVersion() or "?"
            githubVersionField.title = "Latest GitHub version: " .. latest
            logger.logMessage("[Step 3] Latest GitHub version fetched: " .. latest)

            local function normalizeVersion(v) return (v or ""):gsub("^v", "") end
            if normalizeVersion(localVersion) == normalizeVersion(latest) then
                updateStatusText.title = "Your version is up to date (" .. localVersion .. ")"
                updateButton.enabled = false
                logger.logMessage("[Step 4] Plugin is up to date: " .. localVersion)
            else
                updateStatusText.title = "A new version is available (" .. latest .. ")"
                updateButton.enabled = true
                logger.logMessage("[Step 4] New version available: " .. latest)
            end
        end)

        -- Step 5: Token status and input field
        local tokenStatus = TokenUpdater.getTokenStatusText()
        logger.logMessage("[Step 5] Token status: " .. tostring(tokenStatus))

        local tokenStatusText = viewFactory:static_text {
            title = tokenStatus,
            width = 500
        }

        local tokenField = viewFactory:edit_field {
            value = prefs.token or "",
            width = 500,
            height = 80,
            wrap = true,
            tooltip = "Your iNaturalist API token"
        }

        -- Step 6: Refresh token button
        local refreshTokenButton = viewFactory:push_button {
            title = "Refresh Token",
            action = function()
                logger.logMessage("[Step 6] User clicked Refresh Token button.")
                TokenUpdater.runUpdateTokenScript()
            end
        }

        -- Step 7: Logging checkbox
        local logCheck = viewFactory:checkbox {
            title = "Enable logging to log.txt",
            value = prefs.logEnabled or false
        }

        -- Step 8: Save preferences button
        local saveButton = viewFactory:push_button {
            title = "Save",
            action = function()
                prefs.logEnabled = logCheck.value
                prefs.token = tokenField.value
                logger.logMessage(
                    "[Step 8] Preferences saved. Logging: " .. tostring(prefs.logEnabled)
                    .. ", Token length: " .. tostring(#(prefs.token or ""))
                )
            end
        }

        -- Return dialog layout
        return {
            {
                title = "iNaturalist connection settings",
                viewFactory:row { localVersionField, viewFactory:static_text { title = " | ", width = 20 }, githubVersionField },
                viewFactory:row { updateStatusText, updateButton },
                viewFactory:row { tokenStatusText },
                viewFactory:row { tokenField },
                viewFactory:row { refreshTokenButton },
                viewFactory:row { logCheck },
                viewFactory:row { saveButton }
            }
        }
    end
}

--[[
====================================================================
Functional Description
--------------------------------------------------------------------
PluginInfoProvider.lua manages the user interface for iNaturalist
integration in Lightroom, using existing modules to handle token
management and plugin updates. It does NOT duplicate token logic.

Features:
1. Display plugin current version and latest GitHub version.
2. Download latest GitHub version if outdated.
3. Show token field (multiline) with status.
4. Refresh Token button to update token using TokenUpdater.lua.
5. Enable/disable logging.
6. Enable/disable automatic update checks.
7. Save preferences.

Modules and Scripts Used:
- LrView, LrPrefs, LrDialogs, LrTasks (Lightroom SDK)
- Logger.lua
- Update_plugin.lua
- TokenUpdater.lua

Execution Steps:
1. Initialize plugin preferences and UI fields.
2. Display current plugin version and latest GitHub version.
3. Fetch latest GitHub version asynchronously.
4. Create GitHub download button.
5. Show token field and status (via TokenUpdater).
6. Add Refresh Token button.
7. Enable logging checkbox.
8. Enable automatic update check checkbox and "Check now" button.
9. Save button to persist preferences.
10. Return dialog UI layout.
====================================================================
--]]

local LrView    = import "LrView"
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrTasks   = import "LrTasks"

local logger  = require("Logger")
local Updates = require("Update_plugin")
local TokenUpdater = require("TokenUpdater")

local bind = LrView.bind

return {
    sectionsForTopOfDialog = function(viewFactory)
        local prefs = LrPrefs.prefsForPlugin()
        if prefs.checkForUpdates == nil then
            prefs.checkForUpdates = true
        end

        -- Version fields
        local localVersionField = viewFactory:static_text {
            title = LOC("$$$/iNat/CurrentVersion=Plugin current version: ") .. Updates.getCurrentVersion(),
            width = 200
        }
        local githubVersionField = viewFactory:static_text {
            title = LOC("$$$/iNat/LatestGitHubVersion=Latest GitHub version: ..."),
            width = 200
        }

        -- Fetch latest GitHub version asynchronously
        LrTasks.startAsyncTask(function()
            local latestTag = Updates.getLatestGitHubVersion() or "?"
            githubVersionField.title = LOC("$$$/iNat/LatestGitHubVersion=Latest GitHub version: ") .. latestTag
            logger.logMessage("[GitHub] Latest version fetched: " .. tostring(latestTag))
        end)

        -- Download GitHub version button
        local downloadButton = viewFactory:push_button {
            title = LOC("$$$/iNat/DownloadGitHub=Download last GitHub version"),
            action = function()
                LrTasks.startAsyncTask(function()
                    LrHttp.openUrlInBrowser("https://github.com/pbranly/Inaturalist-Identifier-Lightroom/releases/latest")
                    logger.logMessage("[GitHub] Opened releases page in browser")
                end)
            end
        }

        -- Token field with status
        local tokenField = viewFactory:edit_field {
            value = prefs.token or "",
            width = 500,
            height = 80,
            wrap = true,
            tooltip = LOC("$$$/iNat/TokenTooltip=Your iNaturalist API token")
        }

        local tokenStatusText = viewFactory:static_text {
            title = TokenUpdater.getTokenStatusText(),
            width = 500
        }

        local refreshTokenButton = viewFactory:push_button {
            title = LOC("$$$/iNat/RefreshToken=Refresh Token"),
            action = function()
                TokenUpdater.runUpdateTokenScript()
            end
        }

        -- Logging checkbox
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNat/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false
        }

        -- Automatic update check row
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

        -- Save button
        local saveButton = viewFactory:push_button {
            title = LOC("$$$/iNat/Save=Save"),
            action = function()
                prefs.logEnabled = logCheck.value
                prefs.token = tokenField.value
                logger.logMessage("[Preferences] Logging saved, token updated.")
            end
        }

        -- Return final dialog layout
        return {
            {
                title = LOC("$$$/iNat/DialogTitle=iNaturalist connection settings"),
                viewFactory:row { localVersionField, viewFactory:static_text { title = " | ", width = 20 }, githubVersionField },
                viewFactory:row { downloadButton },
                autoUpdateRow,
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

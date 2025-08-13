--[[
============================================================
Functional Description
------------------------------------------------------------
This Lightroom plugin Preferences script manages the user
interface for the iNaturalist integration.

It now relies on Get_Version_GitHub.lua for:
- Retrieving the latest GitHub release tag.
- Calculating version status.
- Providing the correct icon + message for display.

This structure ensures that:
- UI code remains clean and focused on presentation.
- Version logic is centralized for easy maintenance.
- The "Refresh GitHub version" button updates both the displayed
  version number and the status indicator.

============================================================
Modules Used:
------------------------------------------------------------
1. LrPrefs            : Manages Lightroom plugin preferences.
2. LrView             : Provides UI component constructors.
3. LrDialogs          : Displays dialogs to the user.
4. TokenUpdater       : Script to update the iNaturalist token.
5. VerificationToken  : Checks if the token is valid.
6. Get_Version_GitHub : Retrieves GitHub version + status info.
7. Logger             : Writes messages to log.txt.
============================================================
--]]

local LrPrefs   = import "LrPrefs"
local LrView    = import "LrView"
local LrDialogs = import "LrDialogs"

local tokenUpdater   = require("TokenUpdater")
local tokenChecker   = require("VerificationToken")
local versionGitHub  = require("Get_Version_GitHub")
local logger         = require("Logger")

return {
    sectionsForTopOfDialog = function(viewFactory)
        local prefs = LrPrefs.prefsForPlugin()

        -- Logging preference checkbox
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNaturalist/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false,
            checked_value = true,
            unchecked_value = false,
        }

        -- Retrieve initial GitHub status info
        local statusInfo = versionGitHub.getVersionStatus()

        -- UI elements for version display
        local githubVersionStatic = viewFactory:static_text {
            title = LOC("$$$/iNaturalist/GitHubVersionLabel=Latest GitHub version: ") .. statusInfo.githubTag,
            width = 200,
        }

        local versionRow = viewFactory:row {
            spacing = viewFactory:control_spacing(),
            viewFactory:static_text {
                title = LOC("$$$/iNaturalist/CurrentVersionLabel=Plugin current version: ") .. statusInfo.currentVersion,
                width = 200,
            },
            githubVersionStatic,
            viewFactory:static_text {
                title = statusInfo.statusIcon .. " " .. statusInfo.statusText,
                width = 150,
            }
        }

        -- Action to refresh GitHub version info
        local function refreshGitHubVersion()
            local info = versionGitHub.getVersionStatus()
            githubVersionStatic.title = LOC("$$$/iNaturalist/GitHubVersionLabel=Latest GitHub version: ") .. info.githubTag
            versionRow[3].title = info.statusIcon .. " " .. info.statusText

            if info.githubTag and info.githubTag ~= "Unable to retrieve GitHub version" then
                LrDialogs.message(
                    LOC("$$$/iNat/GitHubVersionTitle=GitHub Version"),
                    LOC("$$$/iNat/GitHubVersionBody=Latest GitHub version: ") .. info.githubTag
                )
                logger.logMessage("User refreshed GitHub version: " .. info.githubTag)
            else
                LrDialogs.message(
                    LOC("$$$/iNat/GitHubVersionTitle=GitHub Version"),
                    LOC("$$$/iNat/GitHubVersionError=Unable to retrieve GitHub version.")
                )
                logger.logMessage("Failed to refresh GitHub version for user")
            end
        end

        return {
            {
                title = LOC("$$$/iNaturalist/ConnectionSettings=iNaturalist connection settings"),

                -- Token configuration note
                viewFactory:static_text {
                    title = LOC("$$$/iNaturalist/TokenNote=Click the button below to check and configure your iNaturalist token."),
                    width = 400,
                },

                -- Version display row
                versionRow,

                -- Refresh button
                viewFactory:push_button {
                    title = LOC("$$$/iNaturalist/GitHubVersionButton=Version GitHub"),
                    action = refreshGitHubVersion,
                },

                -- Spacer
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    viewFactory:static_text { title = " " }
                },

                -- Token configuration button
                viewFactory:push_button {
                    title = LOC("$$$/iNaturalist/ConfigureToken=Configure token"),
                    action = function()
                        if prefs.token and prefs.token ~= "" and tokenChecker.isTokenValid() then
                            logger.logMessage("Token is up-to-date.")
                            LrDialogs.message(
                                LOC("$$$/iNat/TokenDialog/UpToDateTitle=Token status"),
                                LOC("$$$/iNat/TokenDialog/UpToDate=Token up-to-date")
                            )
                            return
                        end

                        logger.logMessage("Token must be renewed.")
                        local choice = LrDialogs.confirm(
                            LOC("$$$/iNat/TokenDialog/MustRenewTitle=Token status"),
                            LOC("$$$/iNat/TokenDialog/MustRenew=Token must be renewed. Do you want to update it now?"),
                            LOC("$$$/iNat/TokenDialog/Ok=OK"),
                            LOC("$$$/iNat/TokenDialog/Cancel=Cancel")
                        )

                        if choice == "ok" then
                            logger.logMessage("User chose to update the token.")
                            tokenUpdater.runUpdateTokenScript()
                        else
                            logger.logMessage("User cancelled token update.")
                        end
                    end,
                },

                -- Logging checkbox
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    logCheck,
                },

                -- Save button
                viewFactory:push_button {
                    title = LOC("$$$/iNaturalist/SaveButton=Save"),
                    action = function()
                        prefs.logEnabled = logCheck.value
                        logger.logMessage("Logging preference saved: " .. tostring(logCheck.value))
                    end,
                },
            }
        }
    end
}

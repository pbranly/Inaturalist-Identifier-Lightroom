--[[
============================================================
Functional Description
------------------------------------------------------------
This Lightroom plugin preferences script manages the user 
interface for iNaturalist integration. It allows users to:

1. Configure and validate their iNaturalist API token.
2. Check and refresh the latest GitHub version (synchronously) and update status.
3. Enable or disable logging to "log.txt" for debugging.
4. Display a visual indicator if the local plugin is up-to-date.
============================================================
Modules Used:
------------------------------------------------------------
1. LrPrefs            : Lightroom preferences API
2. LrView             : Lightroom UI components
3. LrDialogs          : Lightroom dialogs
4. TokenUpdater       : Script to update iNaturalist token
5. VerificationToken  : Token validation logic
6. Get_Version_Github : Retrieves latest GitHub release synchronously
7. Get_Current_Version: Retrieves current plugin version
8. Logger             : Handles logging to log.txt
============================================================
--]]

local LrPrefs   = import "LrPrefs"
local LrView    = import "LrView"
local LrDialogs = import "LrDialogs"

local tokenUpdater   = require("TokenUpdater")
local tokenChecker   = require("VerificationToken")
local versionGitHub  = require("Get_Version_Github")
local logger         = require("Logger")
local currentVersion = require("Get_Current_Version").getCurrentVersion()

return {
    sectionsForTopOfDialog = function(viewFactory)
        local prefs = LrPrefs.prefsForPlugin()

        -- Logging checkbox
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNaturalist/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false,
            checked_value = true,
            unchecked_value = false,
        }

        -- Initial GitHub version
        local githubTag = versionGitHub.getLatestTag() or "Unable to retrieve GitHub version"

        -- Status indicator
        local statusIcon, statusText
        if githubTag ~= "Unable to retrieve GitHub version" then
            if versionGitHub.isNewerThanLocal(githubTag) then
                statusIcon = "⚠️"
                statusText = LOC("$$$/iNaturalist/VersionStatus/Outdated=Plugin outdated")
            elseif versionGitHub.isSameAsLocal(githubTag) then
                statusIcon = "✅"
                statusText = LOC("$$$/iNaturalist/VersionStatus/UpToDate=Plugin up-to-date")
            else
                statusIcon = "ℹ️"
                statusText = LOC("$$$/iNaturalist/VersionStatus/Newer=Plugin newer than GitHub")
            end
        else
            statusIcon = "❓"
            statusText = LOC("$$$/iNaturalist/VersionStatus/Unknown=GitHub version unknown")
        end

        -- Static text for versions
        local githubVersionStatic = viewFactory:static_text {
            title = LOC("$$$/iNaturalist/GitHubVersionLabel=Latest GitHub version: ") .. githubTag,
            width = 200,
        }

        local versionRow = viewFactory:row {
            spacing = viewFactory:control_spacing(),
            viewFactory:static_text {
                title = LOC("$$$/iNaturalist/CurrentVersionLabel=Plugin current version: ") .. currentVersion,
                width = 200,
            },
            githubVersionStatic,
            viewFactory:static_text {
                title = statusIcon .. " " .. statusText,
                width = 150,
            }
        }

        -- Function to refresh GitHub version and recalc status
        local function refreshGitHubVersion()
            local tag = versionGitHub.getLatestTag()
            if tag then
                githubVersionStatic.title = LOC("$$$/iNaturalist/GitHubVersionLabel=Latest GitHub version: ") .. tag

                -- Recalculate status
                if versionGitHub.isNewerThanLocal(tag) then
                    statusIcon = "⚠️"
                    statusText = LOC("$$$/iNaturalist/VersionStatus/Outdated=Plugin outdated")
                elseif versionGitHub.isSameAsLocal(tag) then
                    statusIcon = "✅"
                    statusText = LOC("$$$/iNaturalist/VersionStatus/UpToDate=Plugin up-to-date")
                else
                    statusIcon = "ℹ️"
                    statusText = LOC("$$$/iNaturalist/VersionStatus/Newer=Plugin newer than GitHub")
                end
                versionRow[3].title = statusIcon .. " " .. statusText

                LrDialogs.message(
                    LOC("$$$/iNat/GitHubVersionTitle=GitHub Version"),
                    LOC("$$$/iNat/GitHubVersionBody=Latest GitHub version: ") .. tag
                )
                logger.logMessage("User refreshed GitHub version: " .. tag)
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

                -- Token instruction
                viewFactory:static_text {
                    title = LOC("$$$/iNaturalist/TokenNote=Click the button below to check and configure your iNaturalist token."),
                    width = 400,
                },

                -- Versions row
                versionRow,

                -- Button to refresh GitHub version
                viewFactory:push_button {
                    title = LOC("$$$/iNaturalist/GitHubVersionButton=Version GitHub"),
                    action = refreshGitHubVersion,
                },

                -- Spacer
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    viewFactory:static_text { title = " " }
                },

                -- Button to check/configure token
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

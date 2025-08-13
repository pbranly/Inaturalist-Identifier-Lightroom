-- PluginInfoProvider.lua
-- This module defines the Lightroom plugin's preferences dialog.
-- It displays plugin version information, GitHub release version, and token configuration options.

-- [Step 1] Lightroom SDK module imports
local LrPrefs   = import "LrPrefs"
local LrView    = import "LrView"
local LrDialogs = import "LrDialogs"

-- [Step 2] Import custom modules
local tokenUpdater  = require("TokenUpdater")       -- Handles token renewal
local tokenChecker  = require("VerificationToken")  -- Validates token status
local versionGitHub = require("VersionGitHub")      -- Retrieves latest GitHub release tag
local pluginVersion = require("PluginVersion")      -- Local plugin version definition
local logger        = require("Logger")             -- Logging utility

-- [Step 3] Define plugin preferences dialog
return {
    sectionsForTopOfDialog = function(viewFactory)

        -- [Step 4] Retrieve plugin preferences
        local prefs = LrPrefs.prefsForPlugin()
        logger.logMessage("Preferences loaded.")

        -- [Step 5] Define logging checkbox
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNaturalist/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false,
            checked_value = true,
            unchecked_value = false,
        }
        logger.logMessage("Logging checkbox initialized. Current value: " .. tostring(logCheck.value))

        -- [Step 6] Construct current plugin version string
        local currentVersion = string.format(
            "%d.%d.%d",
            pluginVersion.major,
            pluginVersion.minor,
            pluginVersion.revision
        )
        logger.logMessage("Current plugin version constructed: " .. currentVersion)

        -- [Step 7] Retrieve latest GitHub release tag
        local latestTag, releaseUrl = versionGitHub.getLatestTag()
        local versionText = latestTag and latestTag or "Unavailable"
        logger.logMessage("GitHub version retrieval result: " .. versionText)

        -- [Step 8] Define GitHub version display function
        local function version_github()
            if latestTag then
                logger.logMessage("Displaying GitHub version dialog: " .. latestTag)
                LrDialogs.message(
                    LOC("$$$/iNat/GitHubVersionTitle=GitHub Version"),
                    LOC("$$$/iNat/GitHubVersionBody=Latest GitHub version: ") .. latestTag
                )
            else
                logger.logMessage("Failed to retrieve GitHub version. Displaying error dialog.")
                LrDialogs.message(
                    LOC("$$$/iNat/GitHubVersionTitle=GitHub Version"),
                    LOC("$$$/iNat/GitHubVersionError=Unable to retrieve GitHub version.")
                )
            end
        end

        -- [Step 9] Return dialog layout
        return {
            {
                title = LOC("$$$/iNaturalist/ConnectionSettings=iNaturalist connection settings"),

                -- [9.1] Row with instructional message and token configuration button
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    viewFactory:static_text {
                        title = LOC("$$$/iNaturalist/TokenNote=Check and configure your iNaturalist token."),
                        width = 300,
                    },
                    viewFactory:push_button {
                        title = LOC("$$$/iNaturalist/ConfigureToken=Configure token"),
                        action = function()
                            logger.logMessage("Configure token button clicked.")

                            if prefs.token and prefs.token ~= "" and tokenChecker.isTokenValid() then
                                logger.logMessage("Token is valid and up-to-date.")
                                LrDialogs.message(
                                    LOC("$$$/iNat/TokenDialog/UpToDateTitle=Token status"),
                                    LOC("$$$/iNat/TokenDialog/UpToDate=Token is up-to-date.")
                                )
                                return
                            end

                            logger.logMessage("Token is missing or invalid. Prompting user for renewal.")
                            local choice = LrDialogs.confirm(
                                LOC("$$$/iNat/TokenDialog/MustRenewTitle=Token status"),
                                LOC("$$$/iNat/TokenDialog/MustRenew=Token must be renewed. Do you want to update it now?"),
                                LOC("$$$/iNat/TokenDialog/Ok=OK"),
                                LOC("$$$/iNat/TokenDialog/Cancel=Cancel")
                            )

                            if choice == "ok" then
                                logger.logMessage("User confirmed token update.")
                                tokenUpdater.runUpdateTokenScript()
                            else
                                logger.logMessage("User cancelled token update.")
                            end
                        end,
                    },
                },

                -- [9.2] Row with version info and GitHub button
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    viewFactory:static_text {
                        title = LOC("$$$/iNaturalist/CurrentVersionLabel=Current version: ") .. currentVersion,
                        width = 200,
                    },
                    viewFactory:static_text {
                        title = LOC("$$$/iNaturalist/GitHubVersionLabel=Latest GitHub version: ") .. versionText,
                        width = 200,
                    },
                    viewFactory:push_button {
                        title = LOC("$$$/iNaturalist/GitHubVersionButton=Show GitHub Version"),
                        action = version_github,
                    },
                },

                -- [9.3] Logging checkbox row
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    logCheck,
                },

                -- [9.4] Save button
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
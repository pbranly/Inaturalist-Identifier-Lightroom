--[[
============================================================
Functional Description
------------------------------------------------------------
This Lightroom plugin preferences script manages the user 
interface for iNaturalist integration. It allows users to:

1. Configure and validate their iNaturalist API token.
2. Check the latest GitHub version of the plugin.
3. Enable or disable logging to "log.txt" for debugging 
   and tracking purposes.

All operations are logged if logging is enabled. User-facing
messages are internationalized using the LOC() function.
============================================================
Modules Used:
------------------------------------------------------------
1. LrPrefs           : Lightroom preferences API
2. LrView            : Lightroom UI components
3. LrDialogs         : Lightroom dialogs (message boxes, confirmations)
4. TokenUpdater      : Script to update iNaturalist token
5. VerificationToken : Token validation logic
6. VersionGitHub     : Retrieves latest plugin version from GitHub
7. Get_Current_Version: Retrieves current plugin version
8. Logger            : Handles logging to log.txt
============================================================
--]]

-- [Step 1] Lightroom module imports
local LrPrefs   = import "LrPrefs"
local LrView    = import "LrView"
local LrDialogs = import "LrDialogs"

-- [Step 2] Import TokenUpdater module
local tokenUpdater = require("TokenUpdater")

-- [Step 3] Import token validation module
local tokenChecker = require("VerificationToken")

-- [Step 4] Import GitHub version module
local versionGitHub = require("VersionGitHub")

-- [Step 5] Import Logger module
local logger = require("Logger")

-- [Step 6] Import current plugin version module
local currentVersion = require("Get_Current_Version").getCurrentVersion()

-- [Step 7] Define preferences dialog
return {
    sectionsForTopOfDialog = function(viewFactory)
        -- [7.1] Retrieve plugin preferences
        local prefs = LrPrefs.prefsForPlugin()

        -- [7.2] Checkbox to enable logging
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNaturalist/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false,
            checked_value = true,
            unchecked_value = false,
        }

        -- [7.3] Retrieve latest GitHub version
        local latestTag, releaseUrl = versionGitHub.getLatestTag()
        local githubVersionText = latestTag and latestTag or "Unable to retrieve GitHub version"

        -- Function to display GitHub version in dialog
        local function version_github()
            if latestTag then
                LrDialogs.message(
                    LOC("$$$/iNat/GitHubVersionTitle=GitHub Version"),
                    LOC("$$$/iNat/GitHubVersionBody=Latest GitHub version: ") .. latestTag
                )
                logger.logMessage("Displayed latest GitHub version: " .. latestTag)
            else
                LrDialogs.message(
                    LOC("$$$/iNat/GitHubVersionTitle=GitHub Version"),
                    LOC("$$$/iNat/GitHubVersionError=Unable to retrieve GitHub version.")
                )
                logger.logMessage("Failed to retrieve GitHub version.")
            end
        end

        -- [7.4] Build dialog layout
        return {
            {
                title = LOC("$$$/iNaturalist/ConnectionSettings=iNaturalist connection settings"),

                -- [7.4.1] Instructional message
                viewFactory:static_text {
                    title = LOC("$$$/iNaturalist/TokenNote=Click the button below to check and configure your iNaturalist token."),
                    width = 400,
                },

                -- [7.4.2] Display current plugin version and GitHub version side by side
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    viewFactory:static_text {
                        title = LOC("$$$/iNaturalist/CurrentVersionLabel=Plugin current version: ") .. currentVersion,
                        width = 200,
                    },
                    viewFactory:static_text {
                        title = LOC("$$$/iNaturalist/GitHubVersionLabel=Latest GitHub version: ") .. githubVersionText,
                        width = 200,
                    }
                },

                -- [7.4.3] Button to display GitHub version
                viewFactory:push_button {
                    title = LOC("$$$/iNaturalist/GitHubVersionButton=Version GitHub"),
                    action = version_github,
                },

                -- [7.4.4] Spacer row for better layout
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    viewFactory:static_text { title = " " }  -- simple empty space
                },

                -- [7.4.5] Button to check/configure token (below GitHub button)
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

                -- [7.4.6] Logging checkbox row
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    logCheck,
                },

                -- [7.4.7] Save button
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

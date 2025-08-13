--[[
PluginInfoProvider.lua

This module defines the preferences dialog for the iNaturalist Lightroom plugin.
It includes token management, GitHub version checking, and logging preferences.

📦 Required Lua modules:
- PluginVersion.lua         → Defines the local plugin version
- Get_Version_Github.lua    → Retrieves and compares the latest GitHub release
- TokenUpdater.lua          → Handles token renewal logic
- VerificationToken.lua     → Validates the current token
- Logger.lua                → Logs messages to log.txt

📋 Steps:
1. Import Lightroom SDK modules
2. Load token updater and validator
3. Load GitHub version checker
4. Define the preferences UI
5. Handle GitHub version comparison (in async task)
6. Handle token validation and renewal
7. Handle logging preference
]]

-- [Step 1] Import Lightroom SDK modules
local LrPrefs           = import "LrPrefs"
local LrView            = import "LrView"
local LrDialogs         = import "LrDialogs"
local LrBinding         = import "LrBinding"
local LrFunctionContext = import "LrFunctionContext"
local LrTasks           = import "LrTasks"

-- [Step 2] Load token updater module
local tokenUpdater = require("TokenUpdater")

-- [Step 3] Load token validation module
local tokenChecker = require("VerificationToken")

-- [Step 4] Load GitHub version checker
local versionGitHub = require("Get_Version_Github")

-- [Step 5] Define PluginInfoProvider module
local PluginInfoProvider = {}

-- [Step 6] Define preferences dialog
function PluginInfoProvider.sectionsForTopOfDialog(viewFactory)
    local prefs = LrPrefs.prefsForPlugin()

    -- UI checkbox for enabling logging
    local logCheck = viewFactory:checkbox {
        title = LOC("$$$/iNaturalist/EnableLogging=Enable logging to log.txt"),
        value = prefs.logEnabled or false,
        checked_value = true,
        unchecked_value = false,
    }

    -- Create binding context for dynamic UI updates
    local bind
    LrFunctionContext.callWithContext("GitHubVersionContext", function(context)
        bind = LrBinding.makePropertyTable(context)
    end)

    -- [Step 7] GitHub version check and comparison (must run in async task)
    local function updateGitHubVersion()
        LrTasks.startAsyncTask(function()
            local logger = require("Logger")
            logger.logMessage("Checking latest GitHub version...")

            local tag, url = versionGitHub.getLatestTag()
            if tag then
                bind.githubVersion = LOC("$$$/iNaturalist/GitHubVersionLabel=Latest GitHub version: ") .. tag
                logger.logMessage("GitHub version retrieved: " .. tag)

                if versionGitHub.isNewerThanLocal(tag) then
                    logger.logMessage("A newer version is available on GitHub.")
                    LrDialogs.message(
                        LOC("$$$/iNat/GitHubUpdateTitle=Update Available"),
                        LOC("$$$/iNat/GitHubUpdateBody=A newer version (" .. tag .. ") is available on GitHub."),
                        LOC("$$$/iNat/GitHubUpdateButton=OK")
                    )
                else
                    logger.logMessage("Local version is up to date.")
                    LrDialogs.message(
                        LOC("$$$/iNat/GitHubUpdateTitle=Up to Date"),
                        LOC("$$$/iNat/GitHubUpdateBody=Your plugin is up to date (" .. versionGitHub.getLocalVersionString() .. ")."),
                        LOC("$$$/iNat/GitHubUpdateButton=OK")
                    )
                end
            else
                bind.githubVersion = LOC("$$$/iNaturalist/GitHubVersionError=Unable to retrieve GitHub version")
                logger.logMessage("Failed to retrieve GitHub version.")
                LrDialogs.message(
                    LOC("$$$/iNat/GitHubErrorTitle=GitHub Error"),
                    LOC("$$$/iNat/GitHubErrorBody=Could not retrieve the latest version from GitHub."),
                    LOC("$$$/iNat/GitHubErrorButton=OK")
                )
            end
        end)
    end

    -- Initial GitHub version check on dialog load
    updateGitHubVersion()

    -- [Step 8] Return UI layout
    return {
        {
            title = LOC("$$$/iNaturalist/ConnectionSettings=iNaturalist connection settings"),

            viewFactory:static_text {
                title = LOC("$$$/iNaturalist/TokenNote=Click the button below to check and configure your iNaturalist token."),
                width = 400,
            },

            viewFactory:static_text {
                title = LrView.bind("githubVersion"),
                width = 400,
                bind_to_object = bind,
            },

            viewFactory:push_button {
                title = LOC("$$$/iNaturalist/ConfigureToken=Configure token"),
                action = function()
                    local logger = require("Logger")
                    logger.logMessage("Token configuration requested.")

                    if prefs.token and prefs.token ~= "" and tokenChecker.isTokenValid() then
                        logger.logMessage("Token is valid and up to date.")
                        LrDialogs.message(
                            LOC("$$$/iNat/TokenDialog/UpToDateTitle=Token status"),
                            LOC("$$$/iNat/TokenDialog/UpToDate=Token up-to-date"),
                            LOC("$$$/iNat/TokenDialog/Ok=OK")
                        )
                        return
                    end

                    logger.logMessage("Token is missing or invalid.")
                    local choice = LrDialogs.confirm(
                        LOC("$$$/iNat/TokenDialog/MustRenewTitle=Token status"),
                        LOC("$$$/iNat/TokenDialog/MustRenew=Token must be renewed. Do you want to update it now?"),
                        LOC("$$$/iNat/TokenDialog/Ok=Update"),
                        LOC("$$$/iNat/TokenDialog/Cancel=Cancel")
                    )

                    if choice == "ok" then
                        logger.logMessage("User accepted token renewal.")
                        tokenUpdater.runUpdateTokenScript()
                    else
                        logger.logMessage("User cancelled token renewal.")
                    end
                end,
            },

            viewFactory:push_button {
                title = LOC("$$$/iNaturalist/GitHubVersionButton=Check GitHub version"),
                action = updateGitHubVersion,
            },

            viewFactory:row {
                spacing = viewFactory:control_spacing(),
                logCheck,
            },

            viewFactory:push_button {
                title = LOC("$$$/iNaturalist/SaveButton=Save"),
                action = function()
                    prefs.logEnabled = logCheck.value
                    require("Logger").logMessage("Logging preference saved: " .. tostring(logCheck.value))
                end,
            },
        }
    }
end

return PluginInfoProvider
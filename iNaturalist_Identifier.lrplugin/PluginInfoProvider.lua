-- [Step 1] Lightroom module imports
local LrPrefs   = import "LrPrefs"
local LrView    = import "LrView"
local LrDialogs = import "LrDialogs"

-- [Step 2] Import TokenUpdater module
local tokenUpdater = require("TokenUpdater")

-- [Step 3] Import token validation module
local tokenChecker = require("VerificationToken")

-- ✅ Import GitHub version module
local versionGitHub = require("VersionGitHub")

-- [Step 6] Preferences dialog definition
return {
    sectionsForTopOfDialog = function(viewFactory)
        -- [Step 4] Retrieve plugin preferences
        local prefs = LrPrefs.prefsForPlugin()

        -- [Step 5] Checkbox to enable logging
        local logCheck = viewFactory:checkbox {
            title = LOC("$$$/iNaturalist/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false,
            checked_value = true,
            unchecked_value = false,
        }

        -- ✅ Récupération de la version GitHub
        local latestTag, releaseUrl = versionGitHub.getLatestTag()
        local versionText = latestTag and ("Latest GitHub version: " .. latestTag) or "Unable to retrieve GitHub version"

        -- Fonction pour afficher la version GitHub dans une boîte de dialogue
        local function version_github()
            if latestTag then
                LrDialogs.message(
                    LOC("$$$/iNat/GitHubVersionTitle=GitHub Version"),
                    LOC("$$$/iNat/GitHubVersionBody=Latest GitHub version: ") .. latestTag
                )
            else
                LrDialogs.message(
                    LOC("$$$/iNat/GitHubVersionTitle=GitHub Version"),
                    LOC("$$$/iNat/GitHubVersionError=Unable to retrieve GitHub version.")
                )
            end
        end

        -- [Step 6] Return dialog layout
        return {
            {
                title = LOC("$$$/iNaturalist/ConnectionSettings=iNaturalist connection settings"),

                -- [6.1] Instructional message
                viewFactory:static_text {
                    title = LOC("$$$/iNaturalist/TokenNote=Click the button below to check and configure your iNaturalist token."),
                    width = 400,
                },

                -- ✅ Affichage automatique de la version GitHub
                viewFactory:static_text {
                    title = LOC("$$$/iNaturalist/GitHubVersionLabel=" .. versionText),
                    width = 400,
                },

                -- [6.2] Button to check token status
                viewFactory:push_button {
                    title = LOC("$$$/iNaturalist/ConfigureToken=Configure token"),
                    action = function()
                        local logger = require("Logger")

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

                -- ✅ Bouton pour afficher la version GitHub
                viewFactory:push_button {
                    title = LOC("$$$/iNaturalist/GitHubVersionButton=Version GitHub"),
                    action = version_github,
                },

                -- [6.3] Logging checkbox row
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    logCheck,
                },

                -- [6.4] Save button
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
}
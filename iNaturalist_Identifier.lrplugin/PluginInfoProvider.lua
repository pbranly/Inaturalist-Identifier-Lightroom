local LrView    = import "LrView"
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrTasks   = import "LrTasks"

local logger        = require("Logger")
local versionGitHub = require("Get_Version_Github")
local currentVersion = require("Get_Current_Version").getCurrentVersion

return {
    sectionsForTopOfDialog = function(viewFactory)
        local prefs = LrPrefs.prefsForPlugin()

        -- Champ texte GitHub version (sera mis à jour asynchrone)
        local githubVersionField = viewFactory:static_text { title = "Latest GitHub version: ...", width = 400 }

        -- Champ texte version locale
        local localVersionField = viewFactory:static_text { title = "Plugin current version: " .. currentVersion(), width = 400 }

        -- Checkbox pour activer le logging
        local logCheck = viewFactory:checkbox {
            title = "Enable logging to log.txt",
            value = prefs.logEnabled or false,
            checked_value = true,
            unchecked_value = false,
        }

        -- Lancer la récupération GitHub dès l'ouverture du dialogue
        LrTasks.startAsyncTask(function()
            versionGitHub.getVersionStatusAsync(function(status)
                githubVersionField.title = "Latest GitHub version: " .. status.githubTag
            end)
        end)

        -- Bouton pour rafraîchir la version GitHub et afficher le statut
        local refreshButton = viewFactory:push_button {
            title = "Version GitHub",
            action = function()
                versionGitHub.getVersionStatusAsync(function(status)
                    githubVersionField.title = "Latest GitHub version: " .. status.githubTag
                    LrDialogs.message(
                        "Version status",
                        status.statusIcon .. " " .. status.statusText
                    )
                end)
            end
        }

        -- Bouton pour vérifier et mettre à jour le token
        local configureTokenButton = viewFactory:push_button {
            title = "Configure token",
            action = function()
                local tokenChecker = require("VerificationToken")
                local tokenUpdater = require("TokenUpdater")

                if prefs.token and prefs.token ~= "" and tokenChecker.isTokenValid() then
                    logger.logMessage("Token is up-to-date.")
                    LrDialogs.message("Token status", "Token up-to-date")
                    return
                end

                logger.logMessage("Token must be renewed.")
                local choice = LrDialogs.confirm(
                    "Token status",
                    "Token must be renewed. Do you want to update it now?",
                    "OK",
                    "Cancel"
                )

                if choice == "ok" then
                    logger.logMessage("User chose to update the token.")
                    tokenUpdater.runUpdateTokenScript()
                else
                    logger.logMessage("User cancelled token update.")
                end
            end
        }

        -- Bouton pour sauvegarder le choix du logging
        local saveButton = viewFactory:push_button {
            title = "Save",
            action = function()
                prefs.logEnabled = logCheck.value
                logger.logMessage("Logging preference saved: " .. tostring(logCheck.value))
            end
        }

        -- Retour de la structure de la boîte de dialogue
        return {
            {
                title = "iNaturalist connection settings",

                -- Ligne version GitHub
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    githubVersionField
                },

                -- Ligne version locale
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    localVersionField
                },

                -- Ligne boutons Version GitHub et Configure token
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    refreshButton,
                    configureTokenButton
                },

                -- Ligne checkbox logging
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    logCheck
                },

                -- Ligne bouton Save
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    saveButton
                }
            }
        }
    end
}

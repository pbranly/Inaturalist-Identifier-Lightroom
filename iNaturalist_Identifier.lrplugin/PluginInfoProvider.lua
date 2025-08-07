--[[
=====================================================================================
 Script   : PluginInfoProvider.lua
 Purpose  : Define a custom preferences panel for the iNaturalist Lightroom plugin
 Author   : Philippe Branly

 Description :
 ------------
 This script provides a custom preferences section in Lightroom's Plugin Manager.
 It allows users to configure authentication and logging settings for the 
 iNaturalist integration and check for plugin updates via GitHub.

=====================================================================================
--]]

local LrPrefs = import "LrPrefs"
local LrView = import "LrView"
local LrTasks = import "LrTasks"
local LrHttp = import "LrHttp"
local LrDialogs = import "LrDialogs"

return {
    sectionsForTopOfDialog = function(viewFactory)
        local prefs = LrPrefs.prefsForPlugin()
        local f = viewFactory

        local tokenField = f:edit_field {
            value = prefs.token or "",
            width_in_chars = 50,
        }

        local logCheck = f:checkbox {
            title = LOC("$$$/iNaturalist/EnableLogging=Enable logging to log.txt"),
            value = prefs.logEnabled or false,
            checked_value = true,
            unchecked_value = false,
        }

        local function openTokenPage()
            local url = "https://www.inaturalist.org/users/api_token"
            LrTasks.startAsyncTask(function()
                local openCommand
                if WIN_ENV then
                    openCommand = 'start "" "' .. url .. '"'
                elseif MAC_ENV then
                    openCommand = 'open "' .. url .. '"'
                else
                    openCommand = 'xdg-open "' .. url .. '"'
                end
                LrTasks.execute(openCommand)
            end)
        end

        local sections = {
            {
                title = LOC("$$$/iNaturalist/ConnectionSettings=iNaturalist connection settings"),

                f:row {
                    spacing = f:control_spacing(),
                    f:static_text {
                        title = LOC("$$$/iNaturalist/TokenNote=The token is valid for 24 hours; after that, you must regenerate it at the following address:"),
                        width = 400,
                        alignment = 'left',
                    },
                },

                f:row {
                    spacing = f:control_spacing(),
                    f:push_button {
                        title = LOC("$$$/iNaturalist/OpenTokenPage=Open token generation page"),
                        action = openTokenPage,
                    },
                },

                f:row {
                    spacing = f:control_spacing(),
                    f:static_text {
                        title = LOC("$$$/iNaturalist/TokenLabel=Token:"),
                        alignment = 'right',
                        width = 100,
                    },
                    tokenField,
                },

                f:row {
                    spacing = f:control_spacing(),
                    logCheck,
                },

                f:push_button {
                    title = LOC("$$$/iNaturalist/SaveButton=Save"),
                    action = function()
                        prefs.token = tokenField.value
                        prefs.logEnabled = logCheck.value
                    end,
                },

                -- Section de vérification de mise à jour via GitHub
                f:row {
                    spacing = f:control_spacing(),
                    f:push_button {
                        title = LOC("$$$/iNaturalist/CheckUpdate=Vérifier les mises à jour"),
                        action = function()
                            local currentVersion = "0.0.1"  -- 🔁 À synchroniser manuellement
                            local githubApiUrl = "https://api.github.com/repos/[utilisateur]/[repo]/releases/latest" -- 🔁 À adapter

                            LrHttp.get(githubApiUrl, nil, function(body, headers)
                                local remoteVersion = body and body:match('\\"tag_name\\"%s*:%s*\\"([^\\"\\n]+)\\"')
                                if remoteVersion and remoteVersion ~= currentVersion then
                                    local clicked = LrDialogs.confirm(
                                        "Mise à jour disponible : " .. remoteVersion,
                                        "Souhaitez-vous télécharger la nouvelle version ?"
                                    )
                                    if clicked == "ok" then
                                        LrHttp.openUrlInBrowser("https://github.com/[utilisateur]/[repo]/releases/latest")
                                    end
                                else
                                    LrDialogs.message("Votre plugin est à jour.")
                                end
                            end)
                        end,
                    },
                },
            }
        }

        return sections
    end
}

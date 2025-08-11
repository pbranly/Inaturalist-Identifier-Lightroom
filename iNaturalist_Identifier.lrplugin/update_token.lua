--[[
============================================================
Description fonctionnelle
------------------------------------------------------------
Ce script fournit une interface utilisateur modale dans Lightroom 
pour permettre à l’utilisateur de saisir et sauvegarder un token 
d’authentification iNaturalist (valide 24 heures) dans les préférences 
du plugin.

Fonctionnalités principales :
1. Afficher une boîte de dialogue modale contenant :
   - Un champ de saisie pour coller le token iNaturalist.
   - Un bouton pour ouvrir la page web officielle de génération de token.
   - Un bouton pour sauvegarder le token dans les préférences du plugin.
2. Ouvrir la page web dans le navigateur par défaut, avec une commande 
   adaptée au système d’exploitation (Windows, macOS, Linux).
3. Sauvegarder le token dans les préférences Lightroom, accessible par 
   les autres modules du plugin.

------------------------------------------------------------
Étapes détaillées
1. Importer les modules Lightroom nécessaires (prefs, dialogues, vue, tâches).
2. Créer un objet factory pour construire l’interface utilisateur.
3. Récupérer la valeur actuelle du token dans les préférences du plugin.
4. Définir la fonction `openTokenPage` qui ouvre la page officielle 
   iNaturalist du token via une commande shell selon l’OS.
5. Construire l’interface utilisateur modale avec :
   - Un texte d’instruction.
   - Un champ texte lié à la variable `token`.
   - Un bouton pour ouvrir la page de génération du token.
   - Un bouton pour sauvegarder le token dans les prefs et informer l’utilisateur.
6. Afficher la boîte de dialogue modale.

------------------------------------------------------------
Modules appelés
- Lightroom SDK (LrPrefs, LrDialogs, LrView, LrTasks)

------------------------------------------------------------
Scripts appelant
- TokenUpdater.lua (lance ce script pour mise à jour du token)

============================================================
]]

-- 1. Importer les modules Lightroom nécessaires
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrView    = import "LrView"
local LrTasks   = import "LrTasks"

-- 2. Créer un objet factory pour construire l’interface utilisateur
local f = LrView.osFactory()

-- 3. Récupérer la valeur actuelle du token dans les préférences du plugin
local prefs = LrPrefs.prefsForPlugin()
local props = { token = prefs.token or "" }

-- 4. Définir la fonction `openTokenPage` qui ouvre la page officielle iNaturalist
local function openTokenPage()
    local url = "https://www.inaturalist.org/users/api_token"
    LrTasks.startAsyncTask(function()
        local openCommand
        if WIN_ENV then
            -- Commande pour Windows
            openCommand = 'start "" "' .. url .. '"'
        elseif MAC_ENV then
            -- Commande pour macOS
            openCommand = 'open "' .. url .. '"'
        else
            -- Commande pour Linux ou autres
            openCommand = 'xdg-open "' .. url .. '"'
        end
        -- Exécution de la commande pour ouvrir le navigateur
        LrTasks.execute(openCommand)
    end)
end

-- 5. Construire l’interface utilisateur modale
local contents = f:column {
    bind_to_object = props,
    spacing = f:control_spacing(),

    -- 5.a Texte d’instruction
    f:static_text {
        title = LOC("$$$/iNat/TokenDialog/Instruction=Please paste your iNaturalist token (valid for 24 hours):"),
        width = 400,
    },

    -- 5.b Champ texte lié à la variable token
    f:edit_field {
        value = LrView.bind("token"),
        width_in_chars = 50
    },

    -- 5.c Bouton pour ouvrir la page de génération du token
    f:push_button {
        title = LOC("$$$/iNat/TokenDialog/OpenPage=Open token generation page"),
        action = openTokenPage
    },

    -- 5.d Bouton pour sauvegarder le token dans les préférences et informer l’utilisateur
    f:push_button {
        title = LOC("$$$/iNat/TokenDialog/Save=Save token"),
        action = function()
            prefs.token = props.token
            LrDialogs.message(LOC("$$$/iNat/TokenDialog/Saved=Token successfully saved."))
        end
    }
}

-- 6. Afficher la boîte de dialogue modale
LrDialogs.presentModalDialog {
    title = LOC("$$$/iNat/TokenDialog/Title=iNaturalist Token Setup"),
    contents = contents
}

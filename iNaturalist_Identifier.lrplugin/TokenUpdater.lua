--[[
============================================================
Description fonctionnelle
------------------------------------------------------------
Ce module `TokenUpdater.lua` gère le lancement du script 
`update_token.lua` qui permet de mettre à jour le token 
d’authentification iNaturalist.

Fonctionnalités principales :
1. Vérifier la présence du script `update_token.lua`.
2. Exécuter ce script de mise à jour dans une tâche asynchrone 
   Lightroom pour ne pas bloquer l’interface.
3. Afficher un message d’erreur si le script est absent.

------------------------------------------------------------
Étapes numérotées
1. Importer les modules Lightroom nécessaires (chemins, fichiers, tâches, dialogues).
2. Définir la fonction `runUpdateTokenScript` qui :
    2.1. Construit le chemin complet du script `update_token.lua`.
    2.2. Vérifie si le script existe.
    2.3. Lance l’exécution du script dans une tâche asynchrone si présent.
    2.4. Affiche un message d’erreur sinon.
3. Exporter la fonction pour utilisation externe.

------------------------------------------------------------
Scripts appelés
- `update_token.lua` (script de mise à jour du token)

------------------------------------------------------------
Script appelant
- AnimalIdentifier.lua (notamment lors d’un token manquant ou invalide)
============================================================
]]

-- [Étape 1] Lightroom SDK imports
local LrPathUtils = import "LrPathUtils"
local LrFileUtils = import "LrFileUtils"
local LrTasks     = import "LrTasks"
local LrDialogs   = import "LrDialogs"

-- [Étape 2] Function to run the update_token.lua script asynchronously
local function runUpdateTokenScript()
    -- [2.1] Construct the full path of update_token.lua
    local updateScriptPath = LrPathUtils.child(_PLUGIN.path, "update_token.lua")

    -- [2.2] Check if the script exists
    if LrFileUtils.exists(updateScriptPath) then
        -- [2.3] Execute the script in a background async task
        LrTasks.startAsyncTask(function()
            dofile(updateScriptPath)
        end)
    else
        -- [2.4] Show an error message if the script is missing
        LrDialogs.message(LOC("$$$/iNat/Error/MissingUpdateScript=Token update script missing: update_token.lua"))
    end
end

-- [Étape 3] Export the function
return {
    runUpdateTokenScript = runUpdateTokenScript
}

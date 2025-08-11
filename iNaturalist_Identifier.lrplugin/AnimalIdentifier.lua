--[[
============================================================
Description fonctionnelle
------------------------------------------------------------
Ce script définit la fonction `identifyAnimal()` qui constitue 
le cœur du processus d’identification d’animaux dans Lightroom.
Lorsqu’il est appelé (depuis main.lua), il exécute les actions 
suivantes :

1. Lance une tâche asynchrone Lightroom.
2. Initialise le journal (log) et affiche un message de démarrage.
3. Récupère et vérifie le jeton d’accès (token) dans les préférences.
4. Valide le token via un module de vérification.
5. Récupère la photo sélectionnée dans le catalogue Lightroom.
6. Affiche et journalise le nom de la photo sélectionnée.
7. Nettoie les JPEG temporaires existants dans le dossier du plugin.
8. Configure les paramètres d’exportation (format, taille, qualité).
9. Exporte la photo sélectionnée dans le dossier du plugin.
10. Renomme le fichier exporté en `tempo.jpg`.
11. Lance le script Python d’identification.
12. Affiche et journalise les résultats d’identification.
13. Propose à l’utilisateur d’ajouter les identifications comme mots-clés.
14. Si accepté, lance le module de sélection et de marquage.
15. Affiche un message de fin d’analyse.

------------------------------------------------------------
Étapes numérotées
1. Importer les modules Lightroom requis.
2. Importer les modules personnalisés du plugin.
3. Définir la fonction principale `identifyAnimal`.
4. Lancer une tâche asynchrone Lightroom.
5. Initialiser le log et notifier le démarrage.
6. Récupérer le token depuis les préférences.
7. Si le token est vide ou absent, lancer le script de mise à jour.
8. Vérifier la validité du token.
9. Si invalide, lancer le script de mise à jour.
10. Récupérer la photo sélectionnée.
11. Si aucune photo, journaliser et arrêter.
12. Afficher le nom du fichier sélectionné.
13. Supprimer les JPEG existants dans le dossier du plugin.
14. Définir les paramètres d’exportation.
15. Lancer l’export de la photo.
16. Vérifier que l’export a réussi.
17. Renommer l’image exportée en `tempo.jpg`.
18. Lancer le script Python d’identification.
19. Vérifier le résultat du script Python.
20. Afficher les résultats et demander à l’utilisateur s’il veut taguer.
21. Si oui, appeler le module de sélection et marquage.
22. Si non, journaliser que le marquage est ignoré.
23. Si aucun résultat, afficher un message d’absence de résultat.
24. Journaliser et notifier la fin du processus.

------------------------------------------------------------
Scripts appelés
- Logger.lua
- ImageUtils.lua
- PythonRunner.lua
- TokenUpdater.lua
- VerificationToken.lua
- SelectAndTagResults.lua
- identifier_animal.py (script Python)

------------------------------------------------------------
Script appelant
- main.lua → appelé depuis Lightroom via Info.lua
============================================================
]]

-- [Étape 1] Import required Lightroom modules
local LrTasks = import "LrTasks"
local LrDialogs = import "LrDialogs"
local LrApplication = import "LrApplication"
local LrPathUtils = import "LrPathUtils"
local LrFileUtils = import "LrFileUtils"
local LrExportSession = import "LrExportSession"
local LrPrefs = import "LrPrefs"

-- [Étape 2] Custom modules
local logger = require("Logger")
local imageUtils = require("ImageUtils")
local pythonRunner = require("PythonRunner")
local tokenUpdater = require("TokenUpdater")
local tokenChecker = require("VerificationToken")

-- [Étape 3] Main function: exports selected photo, runs Python script, and handles result
local function identifyAnimal()
    -- [Étape 4] Launch asynchronous Lightroom task
    LrTasks.startAsyncTask(function()
        -- [Étape 5] Initialization
        logger.initializeLogFile()
        logger.logMessage("Plugin started")
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/PluginStarted=Plugin started"), 3)

        -- [Étape 6] Retrieve token from preferences
        local prefs = LrPrefs.prefsForPlugin()
        local token = prefs.token

        -- [Étape 7] Check if token is missing
        if not token or token == "" then
            logger.notify(LOC("$$$/iNat/Error/MissingToken=Token is missing. Please enter it in Preferences."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- [Étape 8] Validate token
        local isValid, msg = tokenChecker.isTokenValid()
        -- [Étape 9] If token invalid, prompt update
        if not isValid then
            logger.notify(LOC("$$$/iNat/Error/InvalidToken=Invalid or expired token."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- [Étape 10] Get the selected photo
        local catalog = LrApplication.activeCatalog()
        local photo = catalog:getTargetPhoto()
        -- [Étape 11] Stop if no photo selected
        if not photo then
            logger.logMessage("No photo selected.")
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoPhoto=No photo selected."), 3)
            return
        end

        -- [Étape 12] Display selected photo filename
        local filename = photo:getFormattedMetadata("fileName") or "unknown"
        logger.logMessage("Selected photo: " .. filename)
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/PhotoName=Selected photo: ") .. filename, 3)

        -- [Étape 13] Prepare export folder and cleanup
        local pluginFolder = _PLUGIN.path
        imageUtils.clearJPEGs(pluginFolder)
        logger.logMessage("Previous JPEGs deleted.")
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Cleared=Previous image removed."), 3)

        -- [Étape 14] Export settings
        local exportSettings = {
            LR_export_destinationType = "specificFolder",
            LR_export_destinationPathPrefix = pluginFolder,
            LR_export_useSubfolder = false,
            LR_format = "JPEG",
            LR_jpeg_quality = 0.8,
            LR_size_resizeType = "wh",
            LR_size_maxWidth = 1024,
            LR_size_maxHeight = 1024,
            LR_size_doNotEnlarge = true,
            LR_renamingTokensOn = true,
            LR_renamingTokens = "{{image_name}}",
        }

        -- [Étape 15] Perform export
        local exportSession = LrExportSession({
            photosToExport = { photo },
            exportSettings = exportSettings
        })

        local success = LrTasks.pcall(function()
            exportSession:doExportOnCurrentTask()
        end)

        -- [Étape 16] Check if export succeeded
        local exportedPath = imageUtils.findSingleJPEG(pluginFolder)
        if not exportedPath then
            logger.logMessage("Failed to export temporary image.")
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/ExportFailed=Temporary export failed."), 3)
            return
        end

        -- [Étape 17] Rename the exported file to tempo.jpg
        local finalPath = LrPathUtils.child(pluginFolder, "tempo.jpg")
        local ok, err = LrFileUtils.move(exportedPath, finalPath)
        if not ok then
            local msg = string.format("Error renaming file: %s", err or "unknown")
            logger.logMessage(msg)
            LrDialogs.showBezel(msg, 3)
            return
        end

        logger.logMessage("Image exported as tempo.jpg")
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Exported=Image exported to tempo.jpg"), 3)

        -- [Étape 18] Run Python identification script
        local result = pythonRunner.runPythonIdentifier(
            LrPathUtils.child(pluginFolder, "identifier_animal.py"),
            finalPath,
            token
        )

        -- [Étape 19] Check and display result
        if result:match("🕊️") then
            -- [Étape 20] Display results and ask user if tagging is desired
            local titre = LOC("$$$/iNat/Title/Result=Identification results:")
            logger.logMessage(titre .. "\n" .. result)
            LrDialogs.message(titre, result)

            local choix = LrDialogs.confirm(
                LOC("$$$/iNat/Confirm/Ask=Do you want to add one or more identifications as keywords?"),
                LOC("$$$/iNat/Confirm/Hint=Click 'Continue' to select species."),
                LOC("$$$/iNat/Confirm/Continue=Continue"),
                LOC("$$$/iNat/Confirm/Cancel=Cancel")
            )

            -- [Étape 21] If yes, run selection and tagging module
            if choix == "ok" then
                local selector = require("SelectAndTagResults")
                selector.showSelection(result)
            else
                -- [Étape 22] If no, log skipping
                logger.logMessage("Keyword tagging skipped by user.")
            end
        else
            -- [Étape 23] No results from Python script
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/ResultNone=No identification results ❌"), 3)
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoneFound=No results found."), 3)
        end

        -- [Étape 24] Final log and notification
        logger.logMessage("Analysis completed.")
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/AnalysisDone=Analysis completed."), 3)
    end)
end

return {
    identify = identifyAnimal
}

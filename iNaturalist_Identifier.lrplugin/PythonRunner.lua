--[[
============================================================
Description fonctionnelle
------------------------------------------------------------
Ce module `PythonRunner.lua` permet d'exécuter un script Python
externe pour identifier un animal à partir d'une image exportée.

Fonctionnalités principales :
1. Construire une commande shell pour lancer le script Python
   avec les arguments requis (chemin du script, chemin de l'image,
   et token d'authentification).
2. Exécuter la commande et récupérer la sortie standard.
3. Retourner le résultat (output du script Python) pour traitement
   ultérieur dans le plugin.

------------------------------------------------------------
Étapes numérotées
1. Importer le module Lightroom pour la gestion des chemins.
2. Importer le module personnalisé de journalisation.
3. Définir la fonction runPythonIdentifier qui :
    3.1. Construit la commande shell.
    3.2. Logge la commande.
    3.3. Exécute la commande en capturant la sortie.
    3.4. Retourne le résultat ou une chaîne vide.
4. Exporter la fonction pour usage externe.

------------------------------------------------------------
Scripts appelés
- Logger.lua (pour journaliser la commande exécutée)

------------------------------------------------------------
Script appelant
- AnimalIdentifier.lua via le module principal (main.lua)
============================================================
]]

-- [Étape 1] Lightroom SDK import for path utilities
local LrPathUtils = import "LrPathUtils"

-- [Étape 2] Custom logger module
local logger = require("Logger")

-- [Étape 3] Runs a Python script that performs identification
-- Parameters:
--   pythonScript: full path to the Python script
--   imagePath: full path to the exported image
--   token: iNaturalist authentication token
-- Returns:
--   result: output from the Python script (string)
local function runPythonIdentifier(pythonScript, imagePath, token)
    -- [3.1] Construct the command string to run the script with arguments
    local command = string.format('python "%s" "%s" "%s"', pythonScript, imagePath, token)
    -- [3.2] Log the command
    logger.logMessage("Command: " .. command)

    -- [3.3] Execute the command and capture its output
    local handle = io.popen(command, "r")
    local result = handle:read("*a")
    handle:close()

    -- [3.4] Return the output or an empty string if nil
    return result or ""
end

-- [Étape 4] Export the function for external use
return {
    runPythonIdentifier = runPythonIdentifier
}

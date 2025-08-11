--[[
============================================================
Description fonctionnelle
------------------------------------------------------------
Ce module `ImageUtils.lua` fournit des utilitaires pour gérer
les fichiers JPEG dans un répertoire donné.

Fonctionnalités principales :
1. Supprimer tous les fichiers JPEG (.jpg) dans un dossier.
2. Trouver et retourner le premier fichier JPEG présent dans un dossier.

Ces fonctions sont utilisées notamment pour gérer les images
temporaires exportées par le plugin.

------------------------------------------------------------
Étapes numérotées
1. Importer les modules Lightroom nécessaires à la gestion des fichiers.
2. Importer le module personnalisé de journalisation.
3. Définir la fonction clearJPEGs pour supprimer tous les fichiers .jpg dans un dossier.
4. Définir la fonction findSingleJPEG pour retrouver un fichier JPEG dans un dossier.
5. Exporter les fonctions pour utilisation externe.

------------------------------------------------------------
Scripts appelés
- Logger.lua (pour enregistrer la suppression de fichiers)

------------------------------------------------------------
Script appelant
- AnimalIdentifier.lua (notamment pour nettoyage avant export)
============================================================
]]

-- [Étape 1] Import Lightroom utilities for file and path handling
local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"

-- [Étape 2] Import custom logger
local logger = require("Logger")

-- [Étape 3] Deletes all JPEG (.jpg) files in the given directory
local function clearJPEGs(directory)
    for file in LrFileUtils.files(directory) do
        if string.lower(LrPathUtils.extension(file)) == "jpg" then
            LrFileUtils.delete(file)
            logger.logMessage(LOC("$$$/iNat/Log/JPGDeleted=JPG file deleted: ") .. file)
        end
    end
end

-- [Étape 4] Returns the first JPEG file found in the directory
local function findSingleJPEG(directory)
    for file in LrFileUtils.files(directory) do
        if string.lower(LrPathUtils.extension(file)) == "jpg" then
            return file
        end
    end
    return nil
end

-- [Étape 5] Export functions
return {
    clearJPEGs = clearJPEGs,
    findSingleJPEG = findSingleJPEG
}

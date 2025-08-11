--[[
============================================================
Description fonctionnelle
------------------------------------------------------------
Ce module `logger.lua` gère la journalisation (logging) du plugin.
Il permet :
1. De déterminer l’emplacement du fichier de log.
2. D’initialiser le fichier de log au démarrage du plugin.
3. D’ajouter des messages horodatés dans le fichier.
4. D’afficher des messages à l’utilisateur tout en les enregistrant.

L’activation du logging est contrôlée par une préférence `logEnabled`.

------------------------------------------------------------
Étapes numérotées
1. Importer les modules Lightroom nécessaires.
2. Accéder aux préférences spécifiques au plugin.
3. Définir la fonction pour obtenir le chemin du fichier de log.
4. Définir la fonction d’initialisation du fichier de log.
5. Définir la fonction d’écriture de message dans le log.
6. Définir la fonction d’affichage d’un message et enregistrement dans le log.
7. Exporter les fonctions du module.

------------------------------------------------------------
Scripts appelés
- Aucun script Lua externe (uniquement API Lightroom).

------------------------------------------------------------
Script appelant
- Appelé par `AnimalIdentifier.lua` et potentiellement par d’autres modules pour journaliser.
============================================================
]]

-- [Étape 1] Lightroom API imports
local LrPathUtils = import "LrPathUtils"
local LrDialogs  = import "LrDialogs"
local LrPrefs    = import "LrPrefs"

-- [Étape 2] Access plugin-specific preferences
local prefs = LrPrefs.prefsForPlugin()

-- [Étape 3] Returns the absolute path to the log file
local function getLogFilePath()
    return LrPathUtils.child(_PLUGIN.path, "log.txt")
end

-- [Étape 4] Initializes the log file (if logging is enabled in preferences)
local function initializeLogFile()
    if prefs.logEnabled then
        local f = io.open(getLogFilePath(), "w") -- overwrite at each launch
        if f then
            local timestamp = os.date("[%Y-%m-%d %H:%M:%S] ")
            f:write(timestamp .. LOC("$$$/iNat/Log/PluginStarted=== Plugin launched ===") .. "\n")
            f:close()
        end
    end
end

-- [Étape 5] Writes a message to the log (if logging is enabled)
local function logMessage(message)
    if prefs.logEnabled then
        local f = io.open(getLogFilePath(), "a") -- append mode
        if f then
            local timestamp = os.date("[%Y-%m-%d %H:%M:%S] ")
            f:write(timestamp .. message .. "\n")
            f:close()
        end
    end
end

-- [Étape 6] Shows a message to the user and logs it if enabled
local function notify(message)
    logMessage(message)
    LrDialogs.message(message)
end

-- [Étape 7] Exported functions
return {
    initializeLogFile = initializeLogFile,
    logMessage         = logMessage,
    notify             = notify
}

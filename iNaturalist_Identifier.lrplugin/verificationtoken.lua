--[[
============================================================
Description fonctionnelle
------------------------------------------------------------
Ce module `VerificationToken.lua` vérifie la validité du token 
d’authentification iNaturalist stocké dans les préférences du plugin.

Fonctionnalités principales :
1. Lire le token depuis les préférences Lightroom.
2. Exécuter une requête HTTP (via curl) à l’API iNaturalist pour 
   vérifier la validité du token.
3. Analyser le code de réponse HTTP pour déterminer si le token 
   est valide, expiré, ou si une erreur est survenue.
4. Journaliser chaque étape et résultat pour faciliter le debug.
5. Retourner un booléen et un message décrivant l’état du token.

------------------------------------------------------------
Étapes numérotées
1. Importer les modules Lightroom nécessaires et le module de log.
2. Charger les préférences du plugin.
3. Loguer le chargement du module.
4. Définir la fonction `isTokenValid` qui :
    4.1. Loguer le début de la vérification.
    4.2. Récupérer le token dans les préférences.
    4.3. Vérifier si le token est absent ou vide.
    4.4. Construire la commande curl pour interroger l’API iNaturalist.
    4.5. Exécuter la commande et récupérer le code HTTP.
    4.6. Loguer le code HTTP reçu.
    4.7. Retourner vrai si le code est 200, sinon faux avec message d’erreur.
5. Exporter la fonction pour usage externe.

------------------------------------------------------------
Scripts appelés
- Logger.lua (pour journaliser les événements)

------------------------------------------------------------
Script appelant
- AnimalIdentifier.lua (pour valider le token avant identification)
============================================================
]]

-- [Étape 1] Lightroom module imports
local LrPrefs     = import "LrPrefs"
local LrPathUtils = import "LrPathUtils"
local LrFileUtils = import "LrFileUtils"
local LrDialogs   = import "LrDialogs"

-- [Étape 1] Custom logging module
local logger = require("Logger")

-- [Étape 2] Load plugin preferences
local prefs = LrPrefs.prefsForPlugin()

-- [Étape 3] Log module load
logger.logMessage(LOC("$$$/iNat/Log/VerificationModuleLoaded===== Loaded VerificationToken.lua module ====="))

-- [Étape 4] Validates the iNaturalist token using the API
local function isTokenValid()
    -- [4.1] Log start of validation
    logger.logMessage(LOC("$$$/iNat/Log/TokenCheckStart=== Start of isTokenValid() ==="))

    -- [4.2] Retrieve token
    local token = prefs.token
    -- [4.3] Check for missing or empty token
    if not token or token == "" then
        local msg = LOC("$$$/iNat/Log/TokenMissing=⛔ No token found in Lightroom preferences.")
        logger.logMessage(msg)
        return false, msg
    end

    -- Log token length (for info only)
    logger.logMessage(LOC("$$$/iNat/Log/TokenDetected=🔑 Token detected (length: ") .. tostring(#token) .. LOC("$$$/iNat/Log/Chars= characters)"))

    -- [4.4] Build curl command to verify token validity
    local url = "https://api.inaturalist.org/v1/users/me"
    local command = string.format(
        'curl -s -o /dev/null -w "%%{http_code}" -H "Authorization: Bearer %s" "%s"',
        token,
        url
    )

    -- Log curl command
    logger.logMessage(LOC("$$$/iNat/Log/CurlCommand=📎 Executing curl command: ") .. command)

    -- [4.5] Execute the command and read HTTP response code
    local handle = io.popen(command)
    local httpCode = handle:read("*l")
    handle:close()

    -- [4.6] Log HTTP code
    logger.logMessage(LOC("$$$/iNat/Log/HttpCode=➡️ HTTP response code from iNaturalist: ") .. tostring(httpCode))

    local msg
    -- [4.7] Analyze HTTP code and return result accordingly
    if httpCode == "200" then
        msg = LOC("$$$/iNat/Log/TokenValid=✅ Success: token is valid.")
        logger.logMessage(msg)
        return true, msg
    elseif httpCode == "401" then
        msg = LOC("$$$/iNat/Log/TokenInvalid=❌ Failure: token is invalid or expired (401 Unauthorized).")
    elseif httpCode == "500" then
        msg = LOC("$$$/iNat/Log/ServerError=💥 iNaturalist server error (500).")
    elseif httpCode == "000" or not httpCode then
        msg = LOC("$$$/iNat/Log/NoHttpCode=⚠️ No HTTP code received. Check internet or curl installation.")
    else
        msg = LOC("$$$/iNat/Log/UnexpectedCode=⚠️ Unexpected response (code ") .. tostring(httpCode) .. ")."
    end

    logger.logMessage(msg)
    return false, msg
end

-- [Étape 5] Export function
return {
    isTokenValid = isTokenValid
}

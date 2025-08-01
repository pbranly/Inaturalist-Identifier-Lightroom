-- Lightroom module imports
local LrPrefs     = import "LrPrefs"
local LrPathUtils = import "LrPathUtils"
local LrFileUtils = import "LrFileUtils"
local LrDialogs   = import "LrDialogs"

-- Custom logging module
local logger = require("Logger")

-- Load plugin preferences
local prefs = LrPrefs.prefsForPlugin()

-- Log module load
logger.logMessage(LOC("$$$/iNat/Log/VerificationModuleLoaded===== Loaded VerificationToken.lua module ====="))

-- Validates the iNaturalist token using the API
local function isTokenValid()
    logger.logMessage(LOC("$$$/iNat/Log/TokenCheckStart=== Start of isTokenValid() ==="))

    local token = prefs.token
    if not token or token == "" then
        local msg = LOC("$$$/iNat/Log/TokenMissing=⛔ No token found in Lightroom preferences.")
        logger.logMessage(msg)
        return false, msg
    end

    logger.logMessage(LOC("$$$/iNat/Log/TokenDetected=🔑 Token detected (length: ") .. tostring(#token) .. LOC("$$$/iNat/Log/Chars= characters)"))

    local url = "https://api.inaturalist.org/v1/users/me"
    local command = string.format(
        'curl -s -o /dev/null -w "%%{http_code}" -H "Authorization: Bearer %s" "%s"',
        token,
        url
    )

    logger.logMessage(LOC("$$$/iNat/Log/CurlCommand=📎 Executing curl command: ") .. command)

    local handle = io.popen(command)
    local httpCode = handle:read("*l")
    handle:close()

    logger.logMessage(LOC("$$$/iNat/Log/HttpCode=➡️ HTTP response code from iNaturalist: ") .. tostring(httpCode))

    local msg
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

-- Export function
return {
    isTokenValid = isTokenValid
}

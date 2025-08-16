--[[
============================================================
VerificationToken.lua
------------------------------------------------------------
This module verifies the validity of the iNaturalist token
using Lightroom's native HTTP API (LrHttp) instead of curl.
============================================================
]]

-- [Step 1] Lightroom module imports
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrHttp    = import "LrHttp"

-- [Step 1] Custom logging module
local logger = require("Logger")

-- [Step 2] Load plugin preferences
local prefs = LrPrefs.prefsForPlugin()

-- [Step 3] Log module load
logger.logMessage("===== Loaded VerificationToken.lua module =====")

-- [Step 4] Validate the iNaturalist token using the API
local function isTokenValid()
    -- [4.1] Log start of validation
    logger.logMessage("=== Start of isTokenValid() ===")

    -- [4.2] Retrieve token
    local token = prefs.token

    -- [4.3] Check for missing or empty token
    if not token or token == "" then
        local msg = "⛔ No token found in Lightroom preferences."
        logger.logMessage(msg)
        return false, msg
    end

    logger.logMessage("🔑 Token detected (length: " .. tostring(#token) .. " characters)")

    -- [4.4] Call iNaturalist API using LrHttp
    local url = "https://api.inaturalist.org/v1/users/me"
    logger.logMessage("📎 Sending request to " .. url)

    -- Add Authorization header
    local headers = { Authorization = "Bearer " .. token }

    -- [4.5] Perform HTTP GET
    local result, headersTable = LrHttp.get(url, headers)

    -- [4.6] Extract HTTP status code
    local httpCode
    if headersTable and headersTable.status then
        httpCode = tostring(headersTable.status)
    else
        httpCode = "000"
    end

    logger.logMessage("➡️ HTTP response code from iNaturalist: " .. httpCode)

    local msg
    -- [4.7] Analyze HTTP code
    if httpCode == "200" then
        msg = "✅ Success: token is valid."
        logger.logMessage(msg)
        return true, msg
    elseif httpCode == "401" then
        msg = "❌ Failure: token is invalid or expired (401 Unauthorized)."
    elseif httpCode == "500" then
        msg = "💥 iNaturalist server error (500)."
    elseif httpCode == "000" then
        msg = "⚠️ No HTTP code received. Check internet connection."
    else
        msg = "⚠️ Unexpected response (code " .. httpCode .. ")."
    end

    logger.logMessage(msg)
    return false, msg
end

-- [Step 5] Export function
return {
    isTokenValid = isTokenValid
}

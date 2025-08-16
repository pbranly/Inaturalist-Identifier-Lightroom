--[[
============================================================
VerificationToken.lua
------------------------------------------------------------
Functional Description:
This module `VerificationToken.lua` verifies the validity of the 
iNaturalist authentication token stored in the Lightroom plugin 
preferences. It uses Lightroom's native HTTP API (LrHttp) to 
perform the validation without relying on external curl commands.

Main Features:
1. Read the authentication token from plugin preferences.
2. Use LrHttp to send a GET request to the iNaturalist API to 
   verify the token.
3. Log all steps and HTTP response details for debugging.
4. Display messages in an internationalized format using LOC().
5. Return a boolean and a descriptive message regarding token status.

Modules and scripts used:
- LrPrefs
- LrHttp
- LrDialogs
- Logger.lua (custom logging module)

Scripts calling this module:
- AnimalIdentifier.lua (to validate token before identification)

Numbered Steps:
1. Import necessary Lightroom modules and Logger.
2. Load the plugin preferences.
3. Log module load event.
4. Define function `isTokenValid` to:
    4.1 Log the start of validation.
    4.2 Retrieve token from preferences.
    4.3 Check if the token is missing or empty.
    4.4 Build and log the HTTP GET request.
    4.5 Send the request using LrHttp.
    4.6 Log the HTTP response code and body.
    4.7 Analyze the response and return status.
5. Export the function for external use.
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
logger.logMessage("VerificationToken.lua module loaded.")

-- [Step 4] Validate the iNaturalist token using the API
local function isTokenValid()
    -- [4.1] Log start of validation
    logger.logMessage("Starting token validation process.")

    -- [4.2] Retrieve token
    local token = prefs.token

    -- [4.3] Check for missing or empty token
    if not token or token == "" then
        local msg = "No token found in Lightroom preferences."
        logger.logMessage(msg)
        LrDialogs.message(LOC("$$$/iNat/PluginName=iNaturalist Identification"), msg, "critical")
        return false, msg
    end

    logger.logMessage("Token detected (length: " .. tostring(#token) .. " characters).")

    -- [4.4] Build and log the HTTP GET request
    local url = "https://api.inaturalist.org/v1/users/me"
    local headers = { Authorization = "Bearer " .. token }
    logger.logMessage("Preparing HTTP GET request to URL: " .. url)
    logger.logMessage("Request headers: Authorization: Bearer <token>")

    -- [4.5] Send the request using LrHttp
    local result, headersTable = LrHttp.get(url, headers)

    -- [4.6] Log HTTP response
    local httpCode = "000"
    if headersTable and headersTable.status then
        httpCode = tostring(headersTable.status)
    end

    logger.logMessage("HTTP response code: " .. httpCode)
    logger.logMessage("HTTP response body: " .. (result or "<empty>"))

    -- [4.7] Analyze HTTP response
    local msg
    if httpCode == "200" then
        msg = "Success: token is valid."
        logger.logMessage(msg)
    elseif httpCode == "401" then
        msg = "Failure: token is invalid or expired (401 Unauthorized)."
        logger.logMessage(msg)
    elseif httpCode == "500" then
        msg = "iNaturalist server error (500)."
        logger.logMessage(msg)
    elseif httpCode == "000" then
        msg = "No HTTP code received. Check internet connection."
        logger.logMessage(msg)
    else
        msg = "Unexpected response (code " .. httpCode .. ")."
        logger.logMessage(msg)
    end

    -- Display message on screen in internationalized form
    LrDialogs.message(LOC("$$$/iNat/PluginName=iNaturalist Identification"), msg, (httpCode=="200") and "info" or "critical")

    return httpCode == "200", msg
end

-- [Step 5] Export function
return {
    isTokenValid = isTokenValid
}

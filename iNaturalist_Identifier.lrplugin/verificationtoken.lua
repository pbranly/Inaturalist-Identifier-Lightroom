--[[
============================================================
Functional Description
------------------------------------------------------------
This module `VerificationToken.lua` verifies the validity of the 
iNaturalist authentication token stored in the plugin preferences.

Main features:
1. Read the token from Lightroom preferences.
2. Perform an HTTP request (using curl) to the iNaturalist API to 
   verify the token's validity.
3. Analyze the HTTP response code to determine if the token is valid, 
   expired, or if an error occurred.
4. Log each step and result to aid debugging.
5. Return a boolean and a message describing the token status.

------------------------------------------------------------
Numbered Steps
1. Import necessary Lightroom modules and the logging module.
2. Load the plugin preferences.
3. Log the module loading event.
4. Define the function `isTokenValid` which:
    4.1. Logs the start of validation.
    4.2. Retrieves the token from preferences.
    4.3. Checks if the token is missing or empty.
    4.4. Builds the curl command to query the iNaturalist API.
    4.5. Executes the command and retrieves the HTTP code.
    4.6. Logs the HTTP response code.
    4.7. Returns true if code is 200, otherwise false with an error message.
5. Export the function for external use.

------------------------------------------------------------
Called Scripts
- Logger.lua (for logging events)

------------------------------------------------------------
Calling Scripts
- AnimalIdentifier.lua (to validate the token before identification)
============================================================
]]

-- [Step 1] Lightroom module imports
local LrPrefs     = import "LrPrefs"
local LrPathUtils = import "LrPathUtils"
local LrFileUtils = import "LrFileUtils"
local LrDialogs   = import "LrDialogs"

-- [Step 1] Custom logging module
local logger = require("Logger")

-- [Step 2] Load plugin preferences
local prefs = LrPrefs.prefsForPlugin()

-- [Step 3] Log module load
logger.logMessage(LOC("$$$/iNat/Log/VerificationModuleLoaded===== Loaded VerificationToken.lua module ====="))

-- [Step 4] Validate the iNaturalist token using the API
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

    -- Log token length (info only)
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
        msg = LOC("$$$/iNat/Log/NoHttpCode=⚠️ No HTTP code received. Check internet connection or curl installation.")
    else
        msg = LOC("$$$/iNat/Log/UnexpectedCode=⚠️ Unexpected response (code ") .. tostring(httpCode) .. ")."
    end

    logger.logMessage(msg)
    return false, msg
end

-- [Step 5] Export function
return {
    isTokenValid = isTokenValid
}

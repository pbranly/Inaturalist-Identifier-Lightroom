--[[
============================================================
VerificationToken.lua
------------------------------------------------------------
Functional Description:
This module verifies the iNaturalist authentication token stored in 
Lightroom plugin preferences by checking its timestamp. No HTTP request 
is performed; token validity is determined by its age (must not exceed 24 hours).

Main Features:
1. Read the token and its timestamp from plugin preferences.
2. Compare the token age to a 24-hour threshold.
3. Log all steps using Logger.lua.
4. Display messages in an internationalized format using LOC().
5. Return a boolean and a descriptive message regarding token status.

Modules and scripts used:
- LrPrefs
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
    4.2 Retrieve token and timestamp from preferences.
    4.3 Check if token exists and has a timestamp.
    4.4 Compare timestamp with current time.
    4.5 Log and display validation result.
5. Export the function for external use.
============================================================
]]

-- [Step 1] Lightroom module imports
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"

-- [Step 1] Custom logging module
local logger = require("Logger")

-- [Step 2] Load plugin preferences
local prefs = LrPrefs.prefsForPlugin()

-- [Step 3] Log module load
logger.logMessage("VerificationToken.lua module loaded (timestamp-based check).")

-- [Step 4] Token validation based on timestamp
local function isTokenValid()
    -- [4.1] Log start of validation
    logger.logMessage("Starting token validation based on timestamp.")

    local token = prefs.token
    local tokenTimestamp = prefs.tokenTimestamp -- should be a UNIX timestamp

    -- [4.3] Check token existence and timestamp
    if not token or token == "" then
        local msg = "No token found in Lightroom preferences."
        logger.logMessage(msg)
        LrDialogs.message(LOC("$$$/iNat/PluginName=iNaturalist Identification"), msg, "critical")
        return false, msg
    end

    if not tokenTimestamp then
        local msg = "Token timestamp not found; token considered invalid."
        logger.logMessage(msg)
        LrDialogs.message(LOC("$$$/iNat/PluginName=iNaturalist Identification"), msg, "critical")
        return false, msg
    end

    -- [4.4] Compare timestamp with current time
    local currentTime = os.time()
    local ageSeconds = currentTime - tokenTimestamp
    local ageHours = ageSeconds / 3600

    logger.logMessage(string.format("Token age: %.2f hours.", ageHours))

    local msg
    if ageHours <= 24 then
        msg = "Success: token is considered valid based on timestamp."
        logger.logMessage(msg)
        LrDialogs.message(LOC("$$$/iNat/PluginName=iNaturalist Identification"), msg, "info")
        return true, msg
    else
        msg = "Failure: token is older than 24 hours; please refresh."
        logger.logMessage(msg)
        LrDialogs.message(LOC("$$$/iNat/PluginName=iNaturalist Identification"), msg, "critical")
        return false, msg
    end
end

-- [Step 5] Export function
return {
    isTokenValid = isTokenValid
}

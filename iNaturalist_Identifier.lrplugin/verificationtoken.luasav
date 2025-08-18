--[[============================================================
Functional Description
------------------------------------------------------------
This module `VerificationToken.lua` no longer uses curl or HTTP requests.
Token validity is checked locally based on the saved timestamp.

Main Features:
1. Read token and its timestamp from plugin preferences.
2. Determine if the token is valid (less than 24 hours old).
3. Log all actions via Logger.lua.
4. Display token status to the user in internationalized form.

Modules and Scripts Used:
- LrPrefs
- LrDialogs
- Logger.lua

Calling Scripts:
- AnimalIdentifier.lua
- PluginInfoProvider.lua
============================================================]]

-- Step 1: Imports
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local logger    = require("Logger")

-- Step 2: Check token freshness (<24h)
local function isTokenValid()
    local prefs = LrPrefs.prefsForPlugin()
    local token = prefs.token
    local timestamp = prefs.tokenTimestamp or 0

    if not token or token == "" then
        local msg = LOC("$$$/iNat/Log/TokenMissing=⛔ No token found in Lightroom preferences.")
        logger.logMessage("[VerificationToken] " .. msg)
        LrDialogs.message(LOC("$$$/iNat/PluginName=iNaturalist Identification"), msg, "critical")
        return false, msg
    end

    local age = os.time() - timestamp
    logger.logMessage("[VerificationToken] Token age (seconds): " .. tostring(age))

    local msg
    if age <= 24*3600 then
        msg = LOC("$$$/iNat/Log/TokenValid=✅ Token is fresh and valid (less than 24 hours old).")
        logger.logMessage("[VerificationToken] " .. msg)
        LrDialogs.message(LOC("$$$/iNat/PluginName=iNaturalist Identification"), msg, "info")
        return true, msg
    else
        msg = LOC("$$$/iNat/Log/TokenExpired=❌ Token expired or older than 24 hours. Please refresh.")
        logger.logMessage("[VerificationToken] " .. msg)
        LrDialogs.message(LOC("$$$/iNat/PluginName=iNaturalist Identification"), msg, "critical")
        return false, msg
    end
end

-- Step 3: Export function
return {
    isTokenValid = isTokenValid
}

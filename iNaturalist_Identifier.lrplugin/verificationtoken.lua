--[[
============================================================
Functional Description
------------------------------------------------------------
This module `VerificationToken.lua` verifies the validity of the 
iNaturalist authentication token stored in the plugin preferences.

Main features:
1. Read the token from Lightroom preferences.
2. Perform an HTTP request (using LrHttp) to the iNaturalist API.
3. Analyze the HTTP response code and body to determine token status.
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
    4.4. Builds the HTTP request to query the iNaturalist API.
    4.4.1 Logs the full "https" command equivalent (with masked token by default).
    4.5. Executes the request and retrieves the HTTP code and body.
    4.6. Logs the HTTP response code and body.
    4.7. Decodes the JSON response and logs user info.
    4.8. Returns true if code is 200, otherwise false with an error message.
5. Export the function for external use.
============================================================
]]

-- [Step 1] Lightroom module imports
local LrPrefs   = import "LrPrefs"
local LrHttp    = import "LrHttp"
local LrDialogs = import "LrDialogs"

-- [Step 1] Custom logging and JSON modules
local logger = require("Logger")
local json   = require("json")

-- [Step 2] Load plugin preferences
local prefs = LrPrefs.prefsForPlugin()

-- Helper: mask or show token in logs
local function formatTokenForLog(tok, showFull)
    if not tok or tok == "" then return "<empty>" end
    if showFull then return tok end
    local len = #tok
    if len <= 12 then
        return tok:sub(1, math.min(4, len)) .. "…"
    end
    return tok:sub(1, 8) .. "…" .. tok:sub(len - 6, len)
end

-- Helper: build a human-readable "https" command line for logs
local function buildHttpsCommand(url, headers, showFullToken)
    -- Represent headers as HTTPie-style arguments: Header:"Value"
    local parts = { "https", "GET", url }
    if type(headers) == "table" then
        for _, h in ipairs(headers) do
            local field = tostring(h.field or "")
            local value = tostring(h.value or "")
            if field:lower() == "authorization" then
                -- Try to mask only the token part after "Bearer "
                local bearer, token = value:match("^(%s*Bearer%s+)(.+)$")
                if bearer and token then
                    value = bearer .. formatTokenForLog(token, showFullToken)
                else
                    -- Fallback: mask entire value
                    value = formatTokenForLog(value, showFullToken)
                end
            end
            table.insert(parts, string.format('%s:"%s"', field, value))
        end
    end
    return table.concat(parts, " ")
end

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
        return false, LOC("$$$/iNat/Log/TokenMissing=" .. msg)
    end

    logger.logMessage("🔑 Token detected (length: " .. tostring(#token) .. " characters)")

    -- [4.4] Build HTTP request
    local url = "https://api.inaturalist.org/v1/users/me"
    local headers = {
        { field = "Authorization", value = "Bearer " .. token }
    }

    -- [4.4.1] Log the full "https" command (mask token by default).
    -- Set prefs.logFullToken=true to log the full token (use with caution).
    Set prefs.logFullToken=true
    local showFullToken = (prefs and prefs.logFullToken == true)
    local httpsCmd = buildHttpsCommand(url, headers, showFullToken)
    logger.logMessage("🧪 HTTPS command (for reference): " .. httpsCmd)

    logger.logMessage("🌐 Sending HTTP request to: " .. url)

    -- [4.5] Execute request
    local responseBody, metadata = LrHttp.get(url, headers)

    -- Handle metadata/status
    local statusCode = (metadata and tonumber(metadata.status)) or 0
    logger.logMessage("➡️ HTTP response code from iNaturalist: " .. tostring(statusCode))

    -- [4.6] Log response body
    if responseBody and responseBody ~= "" then
        logger.logMessage("📦 Raw response body: " .. responseBody)
    else
        logger.logMessage("⚠️ No response body received.")
    end

    -- [4.7] Decode JSON and log user info if available
    local decoded
    if responseBody and responseBody ~= "" then
        local ok, res = pcall(function() return json.decode(responseBody) end)
        if ok and res then
            decoded = res
            logger.logMessage("✅ JSON decoded successfully.")
            if decoded.results and decoded.results[1] then
                local user = decoded.results[1]
                logger.logMessage("👤 Authenticated user: " .. (user.login or "unknown"))
            else
                logger.logMessage("⚠️ JSON structure does not contain expected 'results[1]'.")
            end
        else
            logger.logMessage("⚠️ JSON decoding failed.")
        end
    end

    -- [4.8] Analyze status code
    local msg
    if statusCode == 200 then
        msg = "✅ Success: token is valid."
        logger.logMessage(msg)
        return true, LOC("$$$/iNat/Log/TokenValid=" .. msg)
    elseif statusCode == 401 then
        msg = "❌ Failure: token is invalid or expired (401 Unauthorized)."
    elseif statusCode == 500 then
        msg = "💥 iNaturalist server error (500)."
    elseif statusCode == 0 then
        msg = "⚠️ No HTTP code received. Check internet connection or firewall."
    else
        msg = "⚠️ Unexpected response (code " .. tostring(statusCode) .. ")."
    end

    logger.logMessage(msg)
    return false, LOC("$$$/iNat/Log/TokenError=" .. msg)
end

-- [Step 5] Export function
return {
    isTokenValid = isTokenValid
}

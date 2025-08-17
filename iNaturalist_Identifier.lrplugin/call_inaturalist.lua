--[[
============================================================
Functional Description
------------------------------------------------------------
This module `call_inaturalist.lua` queries the iNaturalist API
with an image identification request and returns a structured
table of results containing species names, scientific names, 
and confidence percentages.

Main responsibilities:
1. Build the HTTP request with token and image.
2. Send the request to iNaturalist API.
3. Parse the JSON response.
4. Transform the response into a Lua table of results.
5. Truncate the results to the top 10 species (highest score).
6. Return this structured table to the caller.

This script does not display UI or perform keyword tagging.
It is called by other modules (e.g., `selectAndTagResults.lua`)
that will filter, display, and apply keywords in Lightroom.

------------------------------------------------------------
Modules and scripts used:
- Lightroom SDK:
  * `LrHttp`         (HTTP requests)
  * `LrDialogs`      (for error messages)
  * `LrTasks`        (asynchronous execution)
  * `LrStringUtils`  (string processing)
- External scripts:
  * `Logger.lua`     (logging system)
  * `TokenUpdater.lua` (token management, provides access token)

Scripts that use this module:
- `selectAndTagResults.lua`
- `iNaturalist_Identifier.lua`

------------------------------------------------------------
Numbered Steps
1. Import required modules and logger.
2. Define main function `callInaturalist`.
3. Retrieve stored access token.
4. Build HTTP request to iNaturalist API.
5. Log full HTTP request before sending.
6. Send request via `LrHttp.get` or `LrHttp.post`.
7. Log raw HTTP response body.
8. Parse JSON response.
9. Extract species results (French, Latin, percentage).
10. Sort results by percentage descending.
11. Truncate to 10 species maximum.
12. Return structured table of results.
13. Handle errors and log failures.

------------------------------------------------------------
Detailed description of each step:
1. Load all required SDK modules and the logger.
2. Create the main function callable by other scripts.
3. Use `TokenUpdater` to get a valid bearer token.
4. Prepare the request URL and headers.
5. Log headers, URL, and request body for debugging.
6. Send request using Lightroom’s HTTP library.
7. Log the raw response (JSON text).
8. Decode JSON to Lua table.
9. Iterate over results, build Lua items with fields:
   - fr (French name or "Unknown")
   - latin (scientific name)
   - percent (score percentage)
10. Sort table by descending percent.
11. Cut list to 10 items max.
12. Return this final table.
13. If any step fails, log error and show LOC-based message.

============================================================
]]

-- [Step 1] Import required modules
local LrHttp        = import "LrHttp"
local LrDialogs     = import "LrDialogs"
local LrTasks       = import "LrTasks"
local LrStringUtils = import "LrStringUtils"

local json          = require "dkjson"       -- JSON parser
local logger        = require "Logger"
local TokenUpdater  = require "TokenUpdater"

-- Localization function
local LOC = LOC

-- [Step 2] Main function
local function callInaturalist(imagePath)
    logger.logMessage("[Step 2] Starting callInaturalist for image: " .. tostring(imagePath))

    -- [Step 3] Get stored token
    logger.logMessage("[Step 3] Retrieving stored access token from TokenUpdater.")
    local token = TokenUpdater.getToken()
    if not token then
        logger.logMessage("[Step 3] ERROR: No access token available.")
        LrDialogs.message(
            LOC("$$$/iNat/Error/NoToken=Authentication error"),
            LOC("$$$/iNat/Error/PleaseRefreshToken=No valid token found. Please refresh your iNaturalist token.")
        )
        return nil
    end
    logger.logMessage("[Step 3] Access token retrieved successfully.")

    -- [Step 4] Build HTTP request
    local url = "https://api.inaturalist.org/v1/computervision/score_image"
    logger.logMessage("[Step 4] Preparing HTTP POST request to URL: " .. url)

    local headers = {
        { field = "Authorization", value = "Bearer " .. token },
    }

    local body = {
        image = imagePath
    }

    -- [Step 5] Log request details
    logger.logMessage("[Step 5] HTTP Request headers:")
    for _, h in ipairs(headers) do
        logger.logMessage("  " .. h.field .. ": " .. h.value)
    end
    logger.logMessage("[Step 5] HTTP Request body content: image=" .. tostring(imagePath))

    -- [Step 6] Send HTTP request
    logger.logMessage("[Step 6] Sending HTTP POST request to iNaturalist API.")
    local result, hdrs = LrHttp.post(url, body, headers)

    -- [Step 7] Log HTTP response
    logger.logMessage("[Step 7] Raw HTTP response received.")
    logger.logMessage("Response headers:")
    for _, h in ipairs(hdrs or {}) do
        logger.logMessage("  " .. tostring(h))
    end
    logger.logMessage("Response body: " .. tostring(result))

    if not result or result == "" then
        logger.logMessage("[Step 7] ERROR: Empty response from API.")
        LrDialogs.message(
            LOC("$$$/iNat/Error/EmptyResponse=Empty response"),
            LOC("$$$/iNat/Error/NoData=No data returned from iNaturalist API.")
        )
        return nil
    end

    -- [Step 8] Parse JSON response
    logger.logMessage("[Step 8] Decoding JSON response.")
    local data, pos, err = json.decode(result, 1, nil)
    if err then
        logger.logMessage("[Step 8] ERROR: JSON decode failed: " .. tostring(err))
        LrDialogs.message(
            LOC("$$$/iNat/Error/InvalidJSON=Invalid response"),
            LOC("$$$/iNat/Error/CannotParse=Unable to parse iNaturalist response.")
        )
        return nil
    end

    -- [Step 9] Extract species results
    logger.logMessage("[Step 9] Extracting species results from JSON.")
    local results = {}
    if data.results then
        for _, item in ipairs(data.results) do
            local frName = item.taxon.preferred_common_name or "Unknown"
            local latin  = item.taxon.name or "Unknown"
            local score  = (item.score or 0) * 100

            logger.logMessage(string.format(
                "[Step 9] Extracted: fr='%s', latin='%s', percent=%.2f",
                frName, latin, score
            ))

            table.insert(results, {
                fr = frName,
                latin = latin,
                percent = score
            })
        end
    else
        logger.logMessage("[Step 9] ERROR: No results field in JSON response.")
        return nil
    end

    -- [Step 10] Sort by percentage descending
    logger.logMessage("[Step 10] Sorting results by descending percentage.")
    table.sort(results, function(a, b) return a.percent > b.percent end)

    -- [Step 11] Truncate to top 10
    if #results > 10 then
        logger.logMessage("[Step 11] Truncating results from " .. #results .. " to 10.")
        while #results > 10 do
            table.remove(results)
        end
    else
        logger.logMessage("[Step 11] Results count <= 10, no truncation needed.")
    end

    -- [Step 12] Return structured table
    logger.logMessage("[Step 12] Returning final results table with " .. #results .. " entries.")
    return results
end

-- [Step 13] Export
return {
    callInaturalist = callInaturalist
}

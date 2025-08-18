--[[
=====================================================================================
Script       : call_inaturalist.lua
Author       : Philippe
Purpose      : Identify species from a JPEG image using iNaturalist's AI API
               and let the user add selected species as Lightroom keywords.
Dependencies : Lightroom SDK (LrFileUtils, LrHttp, LrTasks, LrDialogs, LrApplication)
               json decoding library, logger.lua, selectAndTagResults.lua
Used by      : Lightroom plugin workflow
=====================================================================================

Functional Description (English):
1. Read JPEG image exported from Lightroom.
2. Construct a multipart/form-data HTTP request for iNaturalist AI scoring.
3. Log full request details (URL, headers, body length).
4. Send POST request to iNaturalist API.
5. Log full response content.
6. Decode JSON and extract species predictions.
7. Pass results table to selectAndTagResults.showSelection for user selection
   and keyword addition in Lightroom.
8. Handle all errors with detailed logs and messages to the user.
=====================================================================================
]]

-- Step 1: Import required modules
local LrFileUtils     = import "LrFileUtils"
local LrHttp          = import "LrHttp"
local LrTasks         = import "LrTasks"
local LrDialogs       = import "LrDialogs"
local LrApplication   = import "LrApplication"

local json            = require("json")
local logger          = require("logger")
local selectAndTagResults = require("selectAndTagResults")

-- Utility: Normalize accents for keyword compatibility
local function normalizeAccents(str)
    str = str:gsub("à","a"):gsub("â","a"):gsub("é","e"):gsub("è","e")
             :gsub("ê","e"):gsub("ô","o"):gsub("ù","u"):gsub("û","u")
             :gsub("ç","c"):gsub("ï","i"):gsub("ë","e")
    return str
end

-- Step 2: Main async identification function
local function identifyAsync(imagePath, token, callback)
    LrTasks.startAsyncTask(function()
        logger.logMessage("[Step 1] Reading image file: " .. tostring(imagePath))
        local imageData = LrFileUtils.readFile(imagePath)
        if not imageData then
            logger.logMessage("[Step 1] ERROR: Unable to read image file.")
            callback(nil, LOC("$$$/iNat/Error/ReadImage=Unable to read image file."))
            return
        end
        logger.logMessage("[Step 1] Image read successfully (" .. #imageData .. " bytes)")

        -- Step 2: Construct multipart/form-data body
        local boundary = "----LightroomBoundary" .. tostring(math.random(1000000))
        local body = table.concat({
            "--" .. boundary,
            'Content-Disposition: form-data; name="image"; filename="tempo.jpg"',
            "Content-Type: image/jpeg",
            "",
            imageData,
            "--" .. boundary .. "--",
            ""
        }, "\r\n")

        -- Step 3: Prepare HTTP headers
        local headers = {
            { field = "Authorization", value = "Bearer " .. token },
            { field = "User-Agent", value = "LightroomBirdIdentifier/1.0" },
            { field = "Content-Type", value = "multipart/form-data; boundary=" .. boundary },
            { field = "Accept", value = "application/json" }
        }

        logger.logMessage("[Step 3] Preparing HTTP POST request to iNaturalist API")
        logger.logMessage("URL: https://api.inaturalist.org/v1/computervision/score_image")
        logger.logMessage("Headers: " .. table.concat({
            "Authorization: Bearer " .. token,
            "User-Agent: LightroomBirdIdentifier/1.0",
            "Content-Type: multipart/form-data; boundary=" .. boundary,
            "Accept: application/json"
        }, ", "))
        logger.logMessage("Body length: " .. #body .. " bytes")

        -- Step 4: Send POST request
        local result, hdrs = LrHttp.post("https://api.inaturalist.org/v1/computervision/score_image", body, headers)
        if not result then
            logger.logMessage("[Step 4] ERROR: No response from iNaturalist API.")
            callback(nil, LOC("$$$/iNat/Error/NoResponse=No response from iNaturalist API."))
            return
        end
        logger.logMessage("[Step 4] API response received (" .. tostring(#result) .. " bytes)")
        logger.logMessage("Response content: " .. result)

        -- Step 5: Decode JSON response
        local success, parsed = pcall(json.decode, result)
        if not success or not parsed then
            logger.logMessage("[Step 5] ERROR: Failed to decode JSON response.")
            callback(nil, LOC("$$$/iNat/Error/InvalidJSON=Invalid response format from iNaturalist API."))
            return
        end
        logger.logMessage("[Step 5] JSON decoded successfully.")

        local results = parsed.results or {}
        if #results == 0 then
            logger.logMessage("[Step 6] No species recognized.")
            callback(nil, LOC("$$$/iNat/NoSpecies=No species recognized."))
            return
        end

        -- Step 6: Log species predictions
        logger.logMessage("[Step 6] Species predictions received:")
        for i, r in ipairs(results) do
            local taxon = r.taxon or {}
            local name_fr = normalizeAccents(taxon.preferred_common_name or "Unknown")
            local name_latin = taxon.name or "Unknown"
            local score = tonumber(r.combined_score) or 0
            local displayScore = string.format("%.0f%%", score)
            logger.logMessage(string.format("  Species #%d: FR='%s', Latin='%s', Score=%s", i, name_fr, name_latin, displayScore))
        end

        -- Step 7: Pass results to selection UI
        logger.logMessage("[Step 7] Passing results to selection module.")
        selectAndTagResults.showSelection(results)

        -- Step 8: Final callback
        if callback then
            callback(LOC("$$$/iNat/Success=Species identification completed."))
        end
    end)
end

-- Export module
return {
    identifyAsync = identifyAsync
}
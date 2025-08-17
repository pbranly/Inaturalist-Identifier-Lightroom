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

local LrFileUtils = import "LrFileUtils"
local LrHttp      = import "LrHttp"
local LrTasks     = import "LrTasks"
local LrDialogs   = import "LrDialogs"
local LrApplication = import "LrApplication"

local json = require("json")
local logger = require("Logger")
local selectAndTagResults = require("selectAndTagResults")

local function normalizeAccents(str)
    str = str:gsub("à","a"):gsub("â","a"):gsub("é","e"):gsub("è","e")
           :gsub("ê","e"):gsub("ô","o"):gsub("ù","u"):gsub("û","u")
           :gsub("ç","c"):gsub("ï","i"):gsub("ë","e")
    return str
end

local function identifyAsync(imagePath, token, callback)
    LrTasks.startAsyncTask(function()
        logger.logMessage("[Step 1] Reading image: " .. tostring(imagePath))
        local imageData = LrFileUtils.readFile(imagePath)
        if not imageData then
            logger.logMessage("[Step 1] Failed to read image: " .. tostring(imagePath))
            callback(nil, "Unable to read image: " .. imagePath)
            return
        end
        logger.logMessage("[Step 1] Image read successfully (" .. #imageData .. " bytes)")

        -- Step 2: Construct multipart/form-data
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

        -- Step 3: HTTP headers
        local headers = {
            { field = "Authorization", value = "Bearer " .. token },
            { field = "User-Agent", value = "LightroomBirdIdentifier/1.0" },
            { field = "Content-Type", value = "multipart/form-data; boundary=" .. boundary },
            { field = "Accept", value = "application/json" }
        }

        -- Log HTTP request details
        logger.logMessage("[Step 4] Sending POST request to iNaturalist API:")
        logger.logMessage("URL: https://api.inaturalist.org/v1/computervision/score_image")
        logger.logMessage("Headers: " .. table.concat({
            "Authorization: Bearer " .. token,
            "User-Agent: LightroomBirdIdentifier/1.0",
            "Content-Type: multipart/form-data; boundary=" .. boundary,
            "Accept: application/json"
        }, ", "))
        logger.logMessage("Body length: " .. #body .. " bytes")

        -- Step 4: POST request
        local result, hdrs = LrHttp.post("https://api.inaturalist.org/v1/computervision/score_image", body, headers)
        if not result then
            logger.logMessage("[Step 5] API call failed: no response")
            callback(nil, "API error: No response")
            return
        end
        logger.logMessage("[Step 5] API response received (" .. tostring(#result) .. " bytes)")
        logger.logMessage("Response content: " .. result)

        -- Step 6: Decode JSON
        local success, parsed = pcall(json.decode, result)
        if not success or not parsed then
            logger.logMessage("[Step 6] Failed to decode JSON: " .. tostring(result))
            callback(nil, "API error: Invalid JSON")
            return
        end
        logger.logMessage("[Step 6] JSON decoded successfully")

        local results = parsed.results or {}
        if #results == 0 then
            logger.logMessage("[Step 7] No species recognized by iNaturalist")
            callback("🕊️ No species recognized.")
            return
        end

        -- Log each recognized species
        logger.logMessage("[Step 7] iNaturalist species predictions:")
        for i, r in ipairs(results) do
            local taxon = r.taxon or {}
            local name_fr = normalizeAccents(taxon.preferred_common_name or "Unknown")
            local name_latin = taxon.name or "Unknown"
            local score = tonumber(r.combined_score) or 0
            logger.logMessage(string.format("  Species #%d: FR='%s', Latin='%s', Score=%.3f", i, name_fr, name_latin, score))
        end

        -- Step 8: Pass results to selection module
        selectAndTagResults.showSelection(results)

        -- Optional: callback with raw formatted text
        if callback then
            callback(table.concat({ "🕊️ Recognized species:" }, "\n"))
        end
    end)
end

-- Export module
return {
    identifyAsync = identifyAsync
}

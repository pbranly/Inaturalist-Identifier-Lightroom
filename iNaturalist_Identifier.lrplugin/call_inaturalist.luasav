--[[
=====================================================================================
 Script       : call_inaturalist.lua
 Purpose      : Identify species from a JPEG image using iNaturalist's AI API
 Author       : Philippe

 Functional Overview:
 1. Reads JPEG image from disk (exported from Lightroom).
 2. Constructs multipart/form-data HTTP body containing the image.
 3. Builds HTTP headers with authorization and content type.
 4. Sends POST request to iNaturalist's AI scoring endpoint.
 5. Handles network or API errors gracefully.
 6. Parses JSON response returned by the API.
 7. Extracts species prediction results from the parsed response.
 8. Formats species names and raw confidence scores into a readable string for Lightroom.
 9. Returns the final formatted result string for display or logging.

 Dependencies:
 - Lightroom SDK: LrFileUtils, LrHttp, LrTasks
 - JSON decoding library (json)
 - Token must be valid iNaturalist API token (Bearer format)
=====================================================================================
--]]

local LrFileUtils = import "LrFileUtils"
local LrHttp      = import "LrHttp"
local LrTasks     = import "LrTasks"
local json        = require("json")  -- ou selon ton fichier JSON
local logger      = require("Logger")

local function normalizeAccents(str)
    -- Normalize accented characters to basic ASCII for Lightroom parser
    str = str:gsub("à","a"):gsub("â","a"):gsub("é","e"):gsub("è","e")
           :gsub("ê","e"):gsub("ô","o"):gsub("ù","u"):gsub("û","u")
           :gsub("ç","c"):gsub("ï","i"):gsub("ë","e")
    return str
end

local function identifyAsync(imagePath, token, callback)
    LrTasks.startAsyncTask(function()
        -- Step 1: Read image
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
        logger.logMessage("[Step 2] Multipart/form-data body constructed, boundary: " .. boundary)

        -- Step 3: HTTP headers
        local headers = {
            { field = "Authorization", value = "Bearer " .. token },
            { field = "User-Agent", value = "LightroomBirdIdentifier/1.0" },
            { field = "Content-Type", value = "multipart/form-data; boundary=" .. boundary },
            { field = "Accept", value = "application/json" }
        }
        logger.logMessage("[Step 3] HTTP headers prepared.")

        -- Step 4: POST to iNaturalist API
        logger.logMessage("[Step 4] Sending POST request to iNaturalist API.")
        local result, hdrs = LrHttp.post("https://api.inaturalist.org/v1/computervision/score_image", body, headers)
        if not result then
            logger.logMessage("[Step 5] API call failed: no response.")
            callback(nil, "API error: No response")
            return
        end
        logger.logMessage("[Step 5] API response received (" .. tostring(#result) .. " bytes)")

        -- Step 6: Decode JSON
        local success, parsed = pcall(json.decode, result)
        if not success or not parsed then
            logger.logMessage("[Step 6] Failed to decode JSON: " .. tostring(result))
            callback(nil, "API error: Invalid JSON")
            return
        end
        logger.logMessage("[Step 6] JSON decoded successfully.")

        -- Step 7: Extract species predictions
        local results = parsed.results or {}
        if #results == 0 then
            logger.logMessage("[Step 7] No species recognized.")
            callback("🕊️ No species recognized.")
            return
        end
        logger.logMessage("[Step 7] Number of predictions received: " .. #results)

        -- Step 8: Format results with raw scores (Lightroom-compatible)
        local output = { "🕊️ Recognized species:" }
        table.insert(output, "")

        for _, r in ipairs(results) do
            local taxon = r.taxon or {}
            local name_fr = normalizeAccents(taxon.preferred_common_name or "Unknown")
            local name_latin = taxon.name or "Unknown"
            local raw_score = tonumber(r.combined_score) or 0
            local line = string.format("- %s (%s) : %.3f", name_fr, name_latin, raw_score)
            table.insert(output, line)
            logger.logMessage("[Step 8] Recognized: " .. line)
        end

        logger.logMessage("[Step 9] Returning final formatted species recognition results.")
        callback(table.concat(output, "\n"))
    end)
end

-- Export module
return {
    identifyAsync = identifyAsync
}

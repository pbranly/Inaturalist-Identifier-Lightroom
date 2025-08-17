--[[
=====================================================================================
 Script       : call_inaturalist.lua
 Purpose      : Identify species from a JPEG image using iNaturalist's AI API
 Author       : Philippe

 Functional Overview:
 -------------------------------------------------------------------------------------
 This module performs automatic species identification for images exported from 
 Lightroom using iNaturalist's computer vision API. The workflow is as follows:

 1. Read JPEG image from disk.
 2. Construct multipart/form-data HTTP body containing the image.
 3. Build HTTP headers including Authorization and Content-Type.
 4. Send POST request to iNaturalist's AI scoring endpoint.
 5. Handle network or API errors gracefully.
 6. Decode JSON response from API.
 7. Extract species prediction results from the parsed response.
 8. Format species names and raw confidence scores into a readable string.
 9. Return the final formatted result string to the calling script.

 Dependencies:
 - Lightroom SDK: LrFileUtils, LrHttp, LrTasks
 - JSON library (json)
 - Logger.lua (for detailed step-by-step logging)
 - Requires a valid iNaturalist API token (Bearer format)

 Called By:
 - Inaturalist_Identifier.lua

 Steps:
 -------------------------------------------------------------------------------------
 1. Read image from disk and verify content.
 2. Construct multipart/form-data for the POST request.
 3. Prepare HTTP headers including Authorization with token.
 4. Send HTTP POST request to iNaturalist API endpoint.
 5. Handle API errors or network issues.
 6. Decode JSON response from API.
 7. Extract species predictions from decoded JSON.
 8. Format species names and scores into Lightroom-readable string.
 9. Return the final formatted string to caller.

 All logging is in English. All messages displayed to user are in basic English
 using LOC() for potential internationalization.
=====================================================================================
--]]

-- Lightroom SDK imports
local LrFileUtils = import "LrFileUtils"
local LrHttp      = import "LrHttp"
local LrTasks     = import "LrTasks"

-- JSON decoding library
local json        = require("json")  -- or your preferred JSON library

-- Logger module
local logger      = require("Logger")

-- Function to normalize accented characters
local function normalizeAccents(str)
    str = str:gsub("à","a"):gsub("â","a"):gsub("é","e"):gsub("è","e")
           :gsub("ê","e"):gsub("ô","o"):gsub("ù","u"):gsub("û","u")
           :gsub("ç","c"):gsub("ï","i"):gsub("ë","e")
    return str
end

--[[
=====================================================================================
 Function: identifyAsync
 Purpose : Perform asynchronous species identification for a given image
 Params  : 
    imagePath (string) : Path to JPEG image exported from Lightroom
    token (string)     : iNaturalist API token (Bearer)
    callback (function): Function to call with result string or error message
=====================================================================================
--]]
local function identifyAsync(imagePath, token, callback)
    LrTasks.startAsyncTask(function()
        -- Step 1: Read image from disk
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

        -- Step 3: Prepare HTTP headers
        local headers = {
            { field = "Authorization", value = "Bearer " .. token },
            { field = "User-Agent", value = "LightroomBirdIdentifier/1.0" },
            { field = "Content-Type", value = "multipart/form-data; boundary=" .. boundary },
            { field = "Accept", value = "application/json" }
        }
        logger.logMessage("[Step 3] HTTP headers prepared with token and content type.")

        -- Step 4: Send POST request to iNaturalist API
        logger.logMessage("[Step 4] Sending POST request to iNaturalist API endpoint.")
        local result, hdrs = LrHttp.post("https://api.inaturalist.org/v1/computervision/score_image", body, headers)
        if not result then
            logger.logMessage("[Step 5] API call failed: no response received.")
            callback(nil, "API error: No response from iNaturalist API")
            return
        end
        logger.logMessage("[Step 5] API response received (" .. tostring(#result) .. " bytes)")

        -- Step 6: Decode JSON response
        local success, parsed = pcall(json.decode, result)
        if not success or not parsed then
            logger.logMessage("[Step 6] Failed to decode JSON response: " .. tostring(result))
            callback(nil, "API error: Invalid JSON response")
            return
        end
        logger.logMessage("[Step 6] JSON decoded successfully.")

        -- Step 7: Extract species predictions
        local results = parsed.results or {}
        if #results == 0 then
            logger.logMessage("[Step 7] No species recognized in response.")
            callback("🕊️ No species recognized.")
            return
        end
        logger.logMessage("[Step 7] Number of species predictions received: " .. #results)

        -- Step 8: Format species names and raw scores
        local output = { "🕊️ Recognized species:" }
        table.insert(output, "")

        for _, r in ipairs(results) do
            local taxon = r.taxon or {}
            local name_fr = normalizeAccents(taxon.preferred_common_name or "Unknown")
            local name_latin = taxon.name or "Unknown"
            local raw_score = tonumber(r.combined_score) or 0
            local line = string.format("- %s (%s) : %.3f", name_fr, name_latin, raw_score)
            table.insert(output, line)
            logger.logMessage("[Step 8] Recognized species: " .. line)
        end

        -- Step 9: Return final formatted string
        logger.logMessage("[Step 9] Returning formatted species recognition results.")
        callback(table.concat(output, "\n"))
    end)
end

-- Export module
return {
    identifyAsync = identifyAsync
}

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
 5. Detect invalid/expired token and handle it.
 6. Handle network or API errors gracefully.
 7. Decode JSON response from API.
 8. Extract species prediction results from the parsed response.
 9. Format species names and raw confidence scores into a readable string.
10. Return the final formatted result string to the calling script.

 Dependencies:
 - Lightroom SDK: LrFileUtils, LrHttp, LrTasks, LrDialogs, LrPrefs
 - JSON library (json)
 - Logger.lua (for detailed step-by-step logging)
 - TokenUpdater.lua (for refreshing the token)
 - Requires a valid iNaturalist API token (Bearer format)

 Called By:
 - Inaturalist_Identifier.lua

 Steps:
 -------------------------------------------------------------------------------------
 1. Read image from disk and verify content.
 2. Construct multipart/form-data for the POST request.
 3. Prepare HTTP headers including Authorization with token.
 4. Send HTTP POST request to iNaturalist API endpoint.
 5. Detect invalid token from HTTP code or error in JSON.
 6. Handle API errors or network issues.
 7. Decode JSON response from API.
 8. Extract species predictions from decoded JSON.
 9. Format species names and scores into Lightroom-readable string.
10. Return the final formatted string to caller.
=====================================================================================
--]]

local LrFileUtils = import "LrFileUtils"
local LrHttp      = import "LrHttp"
local LrTasks     = import "LrTasks"
local LrDialogs   = import "LrDialogs"
local LrPrefs     = import "LrPrefs"

local json        = require("json")
local logger      = require("Logger")
local tokenUpdater = require("TokenUpdater")

-- Normalize accented characters
local function normalizeAccents(str)
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

        -- Step 3: Prepare HTTP headers
        local headers = {
            { field = "Authorization", value = "Bearer " .. token },
            { field = "User-Agent", value = "LightroomBirdIdentifier/1.0" },
            { field = "Content-Type", value = "multipart/form-data; boundary=" .. boundary },
            { field = "Accept", value = "application/json" }
        }
        logger.logMessage("[Step 3] HTTP headers prepared with token and content type.")

        -- Step 4: Send POST request
        logger.logMessage("[Step 4] Sending POST request to iNaturalist API.")
        local result, hdrs = LrHttp.post("https://api.inaturalist.org/v1/computervision/score_image", body, headers)

        -- Step 5: Detect invalid token
        local httpCode = (hdrs and hdrs.status) or "unknown"
        if httpCode == 401 then
            logger.logMessage("[Step 5] Unauthorized access detected (HTTP 401) - Token invalid or expired")
            LrDialogs.message(
                LOC("$$$/iNat/Error/InvalidToken=Token is not valid, please refresh it"),
                LOC("$$$/iNat/Error/InvalidTokenDesc=Your iNaturalist token is invalid or expired. Please enter a new token."),
                "ok"
            )
            tokenUpdater.runUpdateTokenScript()
            callback(nil, "Token invalid or expired")
            return
        end

        if not result then
            logger.logMessage("[Step 5] API call failed: no response received.")
            callback(nil, "API error: No response from iNaturalist API")
            return
        end
        logger.logMessage("[Step 5] API response received (" .. tostring(#result) .. " bytes)")

        -- Step 6: Decode JSON
        local success, parsed = pcall(json.decode, result)
        if not success or not parsed then
            logger.logMessage("[Step 6] Failed to decode JSON response: " .. tostring(result))
            callback(nil, "API error: Invalid JSON response")
            return
        end
        logger.logMessage("[Step 6] JSON decoded successfully.")

        -- Step 5b: Detect token error in JSON
        if parsed.error then
            logger.logMessage("[Step 5b] API returned error: " .. tostring(parsed.error))
            LrDialogs.message(
                LOC("$$$/iNat/Error/InvalidToken=Token is not valid, please refresh it"),
                LOC("$$$/iNat/Error/InvalidTokenDesc=Your iNaturalist token is invalid or expired. Please enter a new token."),
                "ok"
            )
            tokenUpdater.runUpdateTokenScript()
            callback(nil, "Token invalid or expired")
            return
        end

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

        -- Step 9: Return formatted result
        logger.logMessage("[Step 9] Returning formatted species recognition results.")
        callback(table.concat(output, "\n"))
    end)
end

return {
    identifyAsync = identifyAsync
}

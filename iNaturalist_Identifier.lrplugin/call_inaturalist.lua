--[[
=====================================================================================
 Script       : call_inaturalist.lua
 Purpose      : Identify animal species from a JPEG image using iNaturalist's AI API
 Author       : Philippe

 Functional Overview:
 This script sends a JPEG image to iNaturalist's computer vision API and returns
 a formatted list of species predictions with confidence scores.

 Workflow Steps:
 1. Reads the JPEG image from disk using Lightroom's file utilities.
 2. Constructs a multipart/form-data HTTP body containing the image.
 3. Builds appropriate HTTP headers including authorization and content type.
 4. Sends a POST request to iNaturalist's AI scoring endpoint.
 5. Handles network or API errors gracefully.
 6. Parses the JSON response returned by the API.
 7. Extracts species prediction results from the parsed response.
 8. Normalizes confidence scores relative to the highest score.
 9. Formats the species names and confidence percentages into a readable string.
10. Returns the final formatted result string for display or logging.

 Dependencies:
 - Lightroom SDK: LrFileUtils, LrHttp, LrTasks
 - JSON decoding library (assumed available as `json`)
 - Token must be a valid iNaturalist API token (Bearer format)
=====================================================================================
--]]

-- Lightroom SDK modules
local LrFileUtils = import "LrFileUtils"
local LrHttp      = import "LrHttp"
local LrTasks     = import "LrTasks"
local json = require("json")  -- ou selon le nom de ton fichier JSON

-- Localization
local LOC = LOC

-- Logger utility (customizable)
local logger = require("Logger")

-- Main identification function (asynchronous)
-- Parameters:
--   imagePath : string - path to the JPEG image
--   token     : string - iNaturalist API token
--   callback  : function(result, errorMessage) - called when identification is complete
local function identifyAsync(imagePath, token, callback)
    LrTasks.startAsyncTask(function()

        -- Step 1: Read image from disk
        logger.logMessage("[Step 1] Reading image from path: " .. tostring(imagePath))
        local imageData = LrFileUtils.readFile(imagePath)
        if not imageData then
            logger.logMessage("[Step 1] Failed to read image: " .. tostring(imagePath))
            callback(nil, LOC("$$$/iNat/Error/ImageRead=Unable to read image: ") .. imagePath)
            return
        end
        logger.logMessage("[Step 1] Image read successfully (" .. #imageData .. " bytes)")

        -- Step 2: Construct multipart/form-data body
        logger.logMessage("[Step 2] Constructing multipart/form-data body for image upload.")
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

        -- Step 3: Build HTTP headers
        local headers = {
            { field = "Authorization", value = "Bearer " .. token },
            { field = "User-Agent", value = "LightroomBirdIdentifier/1.0" },
            { field = "Content-Type", value = "multipart/form-data; boundary=" .. boundary },
            { field = "Accept", value = "application/json" }
        }
        logger.logMessage("[Step 3] HTTP headers prepared with Authorization and Content-Type.")

        -- Step 4: Send POST request to iNaturalist API
        logger.logMessage("[Step 4] Sending POST request to iNaturalist API endpoint.")
        local result, hdrs = LrHttp.post("https://api.inaturalist.org/v1/computervision/score_image", body, headers)

        -- Step 5: Handle network or API errors
        if not result then
            logger.logMessage("[Step 5] API call failed: no response received.")
            callback(nil, LOC("$$$/iNat/Error/NoAPIResponse=API error: No response"))
            return
        end
        logger.logMessage("[Step 5] API call succeeded, response received (" .. tostring(#result) .. " bytes)")

        -- Step 6: Parse JSON response
        logger.logMessage("[Step 6] Decoding JSON response from API.")
        local success, parsed = pcall(json.decode, result)
        if not success or not parsed then
            logger.logMessage("[Step 6] Failed to decode JSON response: " .. tostring(result))
            callback(nil, LOC("$$$/iNat/Error/InvalidJSON=API error: Failed to decode JSON response: ") .. tostring(result))
            return
        end
        logger.logMessage("[Step 6] JSON decoded successfully.")

        -- Step 7: Extract species prediction results
        local results = parsed.results or {}
        if #results == 0 then
            logger.logMessage("[Step 7] No species recognized in API response.")
            callback(LOC("$$$/iNat/Result/None=🕊️ No species recognized."))
            return
        end
        logger.logMessage("[Step 7] Number of species recognized: " .. #results)

        -- Step 8: Normalize confidence scores
        logger.logMessage("[Step 8] Normalizing confidence scores for recognized species.")
        local max_score = 0
        for _, r in ipairs(results) do
            local s = tonumber(r.combined_score) or 0
            if s > max_score then max_score = s end
        end
        if max_score == 0 then
            max_score = 1  -- Prevent division by zero
            logger.logMessage("[Step 8] Max score was zero, adjusted to 1 to avoid division by zero.")
        end

        -- Step 9: Format species names and confidence percentages
        logger.logMessage("[Step 9] Formatting results for output.")
--        local output = { LOC("$$$/iNat/Result/Header=🕊️ Recognized species:") }
        local output = { "🕊️ Recognized species:" }

        table.insert(output, "")  -- Add spacing line

        for _, result in ipairs(results) do
            local taxon = result.taxon or {}
            local name_fr = taxon.preferred_common_name or LOC("$$$/iNat/Result/UnknownName=Unknown")
            local name_latin = taxon.name or LOC("$$$/iNat/Result/UnknownName=Unknown")
            local raw_score = tonumber(result.combined_score) or 0
            local normalized = math.floor((raw_score / max_score) * 1000 + 0.5) / 10  -- Round to 1 decimal
            local line = string.format("- %s (%s) : %.1f%%", name_fr, name_latin, normalized)
            table.insert(output, line)
            logger.logMessage("[Step 9] Recognized: " .. line)
        end
		-- Log full formatted result
        logger.logMessage("[Step 9] Full formatted output:\n" .. table.concat(output, "\n"))

        -- Step 10: Return final formatted result string
        logger.logMessage("[Step 10] Returning formatted species recognition results.")
        callback(table.concat(output, "\n"))
    end)
end

-- Export module
return {
    identifyAsync = identifyAsync
}

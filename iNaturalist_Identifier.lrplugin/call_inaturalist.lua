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

        -- Step 1: Read image
        logger.logMessage("[Step 1] Reading JPEG image from disk: " .. tostring(imagePath))
        local imageData = LrFileUtils.readFile(imagePath)
        if not imageData then
            logger.logMessage("[Step 1] Failed to read image file.")
            callback(nil, LOC("$$$/iNat/Error/ReadImage=Unable to read image file."))
            return
        end
        logger.logMessage("[Step 1] Image read successfully (" .. #imageData .. " bytes)")

        -- Step 2: Construct multipart/form-data body
        logger.logMessage("[Step 2] Constructing multipart/form-data body")
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
        logger.logMessage("[Step 2] Body constructed (" .. #body .. " bytes)")

        -- Step 3: Prepare HTTP headers
        logger.logMessage("[Step 3] Preparing HTTP headers")
        local headers = {
            { field = "Authorization", value = "Bearer " .. token },
            { field = "User-Agent", value = "LightroomBirdIdentifier/1.0" },
            { field = "Content-Type", value = "multipart/form-data; boundary=" .. boundary },
            { field = "Accept", value = "application/json" }
        }

        -- Step 4: Log full request details
        logger.logMessage("[Step 4] Preparing to send POST request to iNaturalist API")
        logger.logMessage("URL: https://api.inaturalist.org/v1/computervision/score_image")
        logger.logMessage("Headers: " .. json.encode(headers))
        logger.logMessage("Body preview (first 500 chars): " .. string.sub(body, 1, 500))

        local curlCommand = string.format(
            'curl -X POST "https://api.inaturalist.org/v1/computervision/score_image" -H "Authorization: Bearer %s" -H "Content-Type: multipart/form-data" -F "image=@%s"',
            token,
            imagePath
        )
        logger.logMessage("[Step 4] Equivalent curl command: " .. curlCommand)

        -- Step 5: Send POST request
        logger.logMessage("[Step 5] Sending POST request to iNaturalist API")
        local result, hdrs = LrHttp.post("https://api.inaturalist.org/v1/computervision/score_image", body, headers)
        if not result then
            logger.logMessage("[Step 5] API call failed: No response received.")
            callback(nil, LOC("$$$/iNat/Error/NoResponse=No response from iNaturalist API."))
            return
        end
        logger.logMessage("[Step 5] API response received (" .. tostring(#result) .. " bytes)")
        logger.logMessage("Response headers: " .. json.encode(hdrs or {}))
        logger.logMessage("Response body: " .. result)

        -- Step 6: Decode JSON response
        logger.logMessage("[Step 6] Decoding JSON response")
        local success, parsed = pcall(json.decode, result)
        if not success or not parsed then
            logger.logMessage("[Step 6] Failed to decode JSON response")
            callback(nil, LOC("$$$/iNat/Error/InvalidJSON=Invalid response format from iNaturalist API."))
            return
        end
        logger.logMessage("[Step 6] JSON decoded successfully")
        logger.logMessage("Parsed results: " .. json.encode(parsed.results or {}))

        -- Step 7: Extract species predictions
        local results = parsed.results or {}
        if #results == 0 then
            logger.logMessage("[Step 7] No species recognized in image")
            callback(nil, LOC("$$$/iNat/Result/NoSpecies=No species recognized in the image."))
            return
        end

        logger.logMessage("[Step 7] Species predictions received:")
        for i, r in ipairs(results) do
            local taxon = r.taxon or {}
            local name_fr = normalizeAccents(taxon.preferred_common_name or "Unknown")
            local name_latin = taxon.name or "Unknown"
            local score = tonumber(r.combined_score) or 0
            logger.logMessage(string.format("  Species #%d: Common='%s', Latin='%s', Score=%.3f", i, name_fr, name_latin, score))
            logger.logMessage("  Full result: " .. json.encode(r))
        end

        -- Step 8: Display species selection UI
        logger.logMessage("[Step 8] Displaying species selection UI")
        selectAndTagResults.showSelection(results)

        -- Step 9: Final callback
        if callback then
            callback(LOC("$$$/iNat/Result/Success=Species identification completed."))
        end
    end)
end

-- Export module
return {
    identifyAsync = identifyAsync
}

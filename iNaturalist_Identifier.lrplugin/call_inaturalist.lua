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

-- Import Lightroom SDK modules
local LrHttp = import 'LrHttp'
local LrLogger = import 'LrLogger'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'

-- Initialize logger
local logger = LrLogger('inaturalistLogger')
logger:enable('logfile')
logger:info('--- Starting iNaturalist call ---')

-- Main function to call iNaturalist API with an image
local function call_inaturalist(imagePath, token)
    logger:logMessage("[Step 1] Preparing request to iNaturalist API")

    -- Check if image file exists
    if not LrFileUtils.exists(imagePath) then
        logger:logMessage("[Error] Image file does not exist: " .. imagePath)
        return nil
    end

    -- Generate a unique boundary for multipart/form-data
    local boundary = "----LightroomBoundary" .. tostring(math.random(1000000,9999999))

    -- Prepare HTTP headers
    local headers = {
        { field = 'Authorization', value = 'Bearer ' .. token },
        { field = 'Content-Type', value = 'multipart/form-data; boundary=' .. boundary }
    }

    -- Log headers for debugging
    logger:logMessage("[Step 2] Headers prepared:")
    for _, h in ipairs(headers) do
        logger:logMessage("  " .. h.field .. ": " .. h.value)
    end

    -- Read image file content
    local imageData = LrFileUtils.readFile(imagePath)
    if not imageData then
        logger:logMessage("[Error] Failed to read image file: " .. imagePath)
        return nil
    end

    -- Extract filename from path
    local filename = LrPathUtils.leafName(imagePath)

    -- Construct multipart/form-data body
    local body = "--" .. boundary .. "\r\n" ..
                 "Content-Disposition: form-data; name=\"image\"; filename=\"" .. filename .. "\"\r\n" ..
                 "Content-Type: image/jpeg\r\n\r\n" ..
                 imageData .. "\r\n" ..
                 "--" .. boundary .. "--\r\n"

    -- Log body details
    logger:logMessage("[Step 3] Body constructed")
    logger:logMessage("[Step 3] Body length: " .. #body .. " bytes")
    logger:logMessage("[Step 3] Content-Type: multipart/form-data; boundary=" .. boundary)

    -- Generate equivalent curl command for manual testing
    local curlCommand = string.format(
        'curl -X POST "https://api.inaturalist.org/v1/computervision/score_image" ' ..
        '-H "Authorization: Bearer %s" ' ..
        '-H "Content-Type: multipart/form-data; boundary=%s" ' ..
        '-F "image=@%s"',
        token,
        boundary,
        imagePath
    )
    logger:logMessage("[Step 3] Equivalent curl command:")
    logger:logMessage(curlCommand)

    -- Send HTTP POST request to iNaturalist API
    logger:logMessage("[Step 4] Sending HTTP POST request to iNaturalist")
    local result, headersOut = LrHttp.post(
        "https://api.inaturalist.org/v1/computervision/score_image",
        body,
        headers,
        "application/json"
    )

    -- Check if response was received
    if not result then
        logger:logMessage("[Error] No response received from iNaturalist")
        return nil
    end

    -- Log response headers and body
    logger:logMessage("[Step 5] Response received")
    logger:logMessage("[Step 5] Response headers:")
    for k, v in pairs(headersOut) do
        logger:logMessage("  " .. k .. ": " .. tostring(v))
    end

    logger:logMessage("[Step 5] Response body:")
    logger:logMessage(result)

    -- Return raw response body
    return result
end

-- Return function as module
return call_inaturalist

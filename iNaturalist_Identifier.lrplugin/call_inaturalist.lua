--[[
=====================================================================================
 Module : call_inaturalist.lua
 Purpose : Handles communication with the iNaturalist API for species identification
           and delegates observation submission to UploadObservation.lua
 Author  : Philippe Branly
 Description :
 This module is used by the Lightroom plugin to:
   1. Upload a JPEG photo to iNaturalist’s AI recognition endpoint and receive 
      a list of candidate species with confidence scores.
   2. Delegate confirmed species observation submission to UploadObservation.lua

 Functions:
   - identify(imagePath, token):  
       → Calls the /v1/computervision/score_image API with an image file  
       → Returns formatted species predictions and confidence levels  

   - submitObservation(photo, keywords, token):  
       → Delegates to UploadObservation.submitObservation()  

 Requirements:
   - A valid API token (24-hour lifetime)
   - A JPEG image file exported as `tempo.jpg`
   - Valid EXIF GPS and capture date metadata in the selected photo

 Dependencies:
   - Lightroom SDK modules: LrHttp, LrFileUtils, LrPathUtils
   - External JSON parser: json.lua (must be present in plugin directory)
   - UploadObservation.lua for observation upload
=====================================================================================
--]]

-- Lightroom SDK modules
local LrHttp      = import("LrHttp")
local LrFileUtils = import("LrFileUtils")
local LrPathUtils = import("LrPathUtils")

-- JSON parser
local json = require("json")

-- External module for observation upload
local UploadObservation = require("UploadObservation")

-- Declare module table
local M = {}

-----------------------------------------------------------------------
-- IDENTIFICATION FUNCTION
-----------------------------------------------------------------------
function M.identify(imagePath, token)
    local boundary = "----LightroomFormBoundary123456"

    -- Read JPEG image content from disk
    local imageData = LrFileUtils.readFile(imagePath)
    if not imageData then
        return nil, LOC("$$$/iNat/Error/ImageRead=Unable to read image: ") .. imagePath
    end

    -- Construct a multipart/form-data HTTP body with the image
    local body = table.concat({
        "--" .. boundary,
        'Content-Disposition: form-data; name="image"; filename="tempo.jpg"',
        "Content-Type: image/jpeg",
        "",
        imageData,
        "--" .. boundary .. "--",
        ""
    }, "\r\n")

    -- Build HTTP headers
    local headers = {
        { field = "Authorization", value = "Bearer " .. token },
        { field = "User-Agent", value = "LightroomBirdIdentifier/1.0" },
        { field = "Content-Type", value = "multipart/form-data; boundary=" .. boundary },
        { field = "Accept", value = "application/json" }
    }

    -- Send POST request
    local result, hdrs = LrHttp.post("https://api.inaturalist.org/v1/computervision/score_image", body, headers)

    -- Handle HTTP/network error
    if not result then
        return nil, LOC("$$$/iNat/Error/NoAPIResponse=API error: No response")
    end

    -- Decode JSON response
    local success, parsed = pcall(json.decode, result)
    if not success or not parsed then
        return nil, LOC("$$$/iNat/Error/InvalidJSON=API error: Failed to decode JSON response: ") .. tostring(result)
    end

    -- Extract and format results
    local results = parsed.results or {}
    if #results == 0 then
        return LOC("$$$/iNat/Result/None=🕊️ No specie recognized.")
    end

    -- Normalize scores
    local max_score = 0
    for _, r in ipairs(results) do
        local s = tonumber(r.combined_score) or 0
        if s > max_score then max_score = s end
    end
    if max_score == 0 then max_score = 1 end

    -- Build output
    local output = { LOC("$$$/iNat/Result/Header=🕊️ Recognized species:") }
    table.insert(output, "")
    for _, result in ipairs(results) do
        local taxon = result.taxon or {}
        local name_fr = taxon.preferred_common_name or LOC("$$$/iNat/Result/UnknownName=Unknown")
        local name_latin = taxon.name or LOC("$$$/iNat/Result/UnknownName=Unknown")
        local raw_score = tonumber(result.combined_score) or 0
        local normalized = math.floor((raw_score / max_score) * 1000 + 0.5) / 10
        table.insert(output, string.format("- %s (%s) : %.1f%%", name_fr, name_latin, normalized))
    end

    return table.concat(output, "\n")
end

-----------------------------------------------------------------------
-- OBSERVATION SUBMISSION FUNCTION (delegation only)
-----------------------------------------------------------------------
function M.submitObservation(photo, keywords, token)
    return UploadObservation.submitObservation(photo, keywords, token)
end

-- Return the module
return M

--[[
=====================================================================================
 Script    : UploadObservation.lua
 Purpose   : Upload a tagged photo as an observation to iNaturalist via their API

 Description :
 This module takes a Lightroom photo and uploads it to iNaturalist as an observation,
 using metadata such as species name (from keywords), GPS coordinates, and capture time.

 Workflow:
   1. Exports the current Lightroom photo as a temporary JPEG file.
   2. Extracts metadata:
       - Species name (from first keyword containing a Latin name in parentheses)
       - GPS location (latitude & longitude)
       - Date/time the photo was taken
   3. Constructs a multipart/form-data HTTP request.
   4. Sends the request using the iNaturalist v1 API with OAuth2 authentication.
   5. Returns success or failure with a message.

 Dependencies:
   - Lightroom SDK: 
       • LrHttp        → For HTTP requests
       • LrPathUtils   → For temp file paths
       • LrFileUtils   → For reading file data
       • LrApplication → For accessing photo metadata
   - export_to_tempo.lua → Exports a temporary JPEG file
   - Logger.lua          → Logs steps and results

 Author    : Philippe
=====================================================================================
--]]

-- Lightroom SDK modules
local LrHttp = import "LrHttp"
local LrPathUtils = import "LrPathUtils"
local LrFileUtils = import "LrFileUtils"
local LrApplication = import "LrApplication"

-- External modules
local export_to_tempo = require("export_to_tempo")
local logger = require("Logger")

--- Uploads a Lightroom photo as an observation to iNaturalist
-- @param photo (LrPhoto) : The Lightroom photo object
-- @param token (string)  : OAuth2 bearer token for API authentication
-- @return true if success, or false and error message
local function upload(photo, token)
    logger.logMessage("[UploadObservation] Starting upload to iNaturalist...")

    -- Step 1: Export photo as temporary JPEG
    local imagePath, err = export_to_tempo.exportToTempo(photo)
    if not imagePath then
        return false, "Image export failed: " .. (err or "unknown error")
    end

    -- Step 2: Extract species name from keywords (look for Latin name in parentheses)
    local speciesName = nil
    for _, kw in ipairs(photo:getRawMetadata("keywords")) do
        local name = kw:getName()
        local latin = name:match("%((.-)%)")
        if latin then
            speciesName = latin
            break
        end
    end
    if not speciesName then
        return false, "No species name (Latin) found in keywords."
    end

    -- Step 3: Get date/time and GPS location
    local takenAt = photo:getRawMetadata("dateTimeOriginal") or os.date("!%Y-%m-%dT%H:%M:%SZ")
    local lat = photo:getRawMetadata("gpsLatitude")
    local lon = photo:getRawMetadata("gpsLongitude")

    -- Step 4: Build multipart/form-data HTTP POST body
    local boundary = "----iNatFormBoundary" .. tostring(math.random(1000000, 9999999))
    local function formField(name, value)
        return "--" .. boundary .. "\r\n"
            .. 'Content-Disposition: form-data; name="' .. name .. '"\r\n\r\n'
            .. value .. "\r\n"
    end

    local bodyParts = {}
    table.insert(bodyParts, formField("observation[species_guess]", speciesName))
    table.insert(bodyParts, formField("observation[observed_on_string]", takenAt))
    if lat and lon then
        table.insert(bodyParts, formField("observation[latitude]", tostring(lat)))
        table.insert(bodyParts, formField("observation[longitude]", tostring(lon)))
    end

    -- Photo data
    table.insert(bodyParts, "--" .. boundary)
    table.insert(bodyParts, 'Content-Disposition: form-data; name="observation[photo]"; filename="photo.jpg"\r\n'
        .. 'Content-Type: image/jpeg\r\n\r\n')
    local imageData = LrFileUtils.readFile(imagePath)
    table.insert(bodyParts, imageData)
    table.insert(bodyParts, "\r\n--" .. boundary .. "--\r\n")

    local requestBody = table.concat(bodyParts)

    -- Step 5: Set headers
    local headers = {
        { field = "Authorization", value = "Bearer " .. token },
        { field = "Content-Type", value = "multipart/form-data; boundary=" .. boundary },
    }

    -- Step 6: Send POST request to iNaturalist API
    local result, hdrs = LrHttp.post("https://api.inaturalist.org/v1/observations", requestBody, headers)

    -- Step 7: Handle response
    if not result or result == "" then
        logger.logMessage("[UploadObservation] No response from iNaturalist API.")
        return false, "No response from iNaturalist API."
    end

    if hdrs and hdrs.status and hdrs.status >= 200 and hdrs.status < 300 then
        logger.logMessage("[UploadObservation] Upload successful. Status: " .. tostring(hdrs.status))
        return true
    else
        local status = hdrs and hdrs.status or "unknown"
        logger.logMessage("[UploadObservation] Upload failed. Status: " .. tostring(status))
        return false, "iNaturalist upload failed with status: " .. tostring(status)
    end
end

-- Export module
return {
    upload = upload
}

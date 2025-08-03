-- Required Lightroom modules
local LrHttp = import("LrHttp")
local LrFileUtils = import("LrFileUtils")
local LrPathUtils = import("LrPathUtils")
local LrDate = import("LrDate")

-- JSON parser (make sure json.lua is present in your plugin folder)
local json = require("json")

local M = {}

-----------------------------------------------------------------------
-- IDENTIFICATION FUNCTION
-- Uses iNaturalist's /v1/computervision/score_image endpoint
-- to identify species in the given photo file (JPEG).
-- Returns a formatted string with the top matches or an error.
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

    -- Build HTTP headers for authentication and format
    local headers = {
        { field = "Authorization", value = "Bearer " .. token },
        { field = "User-Agent", value = "LightroomBirdIdentifier/1.0" },
        { field = "Content-Type", value = "multipart/form-data; boundary=" .. boundary },
        { field = "Accept", value = "application/json" }
    }

    -- Send POST request to the iNaturalist API for species scoring
    local result, hdrs = LrHttp.post("https://api.inaturalist.org/v1/computervision/score_image", body, headers)

    -- Handle HTTP/network error
    if not result then
        return nil, LOC("$$$/iNat/Error/NoAPIResponse=API error: No response")
    end

    -- Parse the JSON response body
    local success, parsed = pcall(json.decode, result)
    if not success or not parsed then
        return nil, LOC("$$$/iNat/Error/InvalidJSON=API error: Failed to decode JSON response: ") .. tostring(result)
    end

    -- Extract results array
    local results = parsed.results or {}
    if #results == 0 then
        return LOC("$$$/iNat/Result/None=🕊️ No specie recognized.")
    end

    -- Normalize the combined scores for percentage representation
    local max_score = 0
    for _, r in ipairs(results) do
        local s = tonumber(r.combined_score) or 0
        if s > max_score then max_score = s end
    end
    if max_score == 0 then max_score = 1 end

    -- Build formatted output string for display
    local output = { LOC("$$$/iNat/Result/Header=🕊️ Recognized species:") }
    table.insert(output, "") -- Add blank line

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
-- OBSERVATION SUBMISSION FUNCTION
-- Submits the photo metadata and selected species to iNaturalist
-- using /v1/observations followed by /v1/observation_photos
-----------------------------------------------------------------------
function M.submitObservation(photo, keywords, token)
    -- Extract geolocation and capture time from the photo
    local latitude = photo:getRawMetadata("gpsLatitude")
    local longitude = photo:getRawMetadata("gpsLongitude")
    local captureTime = photo:getRawMetadata("dateTimeOriginal") or photo:getRawMetadata("dateTime")

    -- Use the first keyword as the species name
    local speciesName = nil
    if keywords and #keywords > 0 then
        speciesName = keywords[1]:getName()
    else
        return false, LOC("$$$/iNat/Error/NoKeyword=No species keyword found.")
    end

    -- Ensure required GPS metadata is present
    if not latitude or not longitude then
        return false, LOC("$$$/iNat/Error/NoGPS=Missing GPS coordinates.")
    end

    -- Ensure a valid timestamp
    if not captureTime then
        captureTime = os.date("!%Y-%m-%dT%H:%M:%SZ") -- fallback: current UTC time
    else
        captureTime = LrDate.timeToIsoDate(captureTime)
    end

    -- Prepare the observation data payload
    local payload = {
        observation = {
            species_guess = speciesName,
            observed_on_string = captureTime,
            time_zone = "UTC",
            latitude = latitude,
            longitude = longitude,
            positional_accuracy = 50,
            captive_flag = false,
            geoprivacy = "open"
        }
    }

    local body = json.encode(payload)

    -- Submit the observation metadata
    local headers = {
        { field = "Authorization", value = "Bearer " .. token },
        { field = "Content-Type", value = "application/json" },
        { field = "Accept", value = "application/json" }
    }

    local responseBody, responseCode = LrHttp.post(
        "https://api.inaturalist.org/v1/observations",
        body,
        headers
    )

    -- Check for failure in the initial submission
    if responseCode ~= 200 and responseCode ~= 201 then
        return false, LOC("$$$/iNat/Error/ObservationFailed=Observation submission failed. Code: ") .. tostring(responseCode)
    end

    -- Parse the returned observation ID
    local parsed = json.decode(responseBody)
    local observationId = parsed.results and parsed.results[1] and parsed.results[1].id

    if not observationId then
        return false, LOC("$$$/iNat/Error/NoObservationID=Unable to retrieve observation ID.")
    end

    -- Path to image to be uploaded with observation
    local imagePath = LrPathUtils.child(_PLUGIN.path, "tempo.jpg")
    if not LrFileUtils.exists(imagePath) then
        return false, LOC("$$$/iNat/Error/NoImage=tempo.jpg not found.")
    end

    -- Build multipart body for photo upload
    local uploadBody = {
        { name = "observation_photo[observation_id]", value = tostring(observationId) },
        { name = "observation_photo[photo]", filePath = imagePath, fileName = "tempo.jpg", contentType = "image/jpeg" }
    }

    -- Upload the photo to the newly created observation
    local uploadRespBody, uploadRespCode = LrHttp.postMultipart(
        "https://api.inaturalist.org/v1/observation_photos",
        uploadBody,
        {
            { field = "Authorization", value = "Bearer " .. token }
        }
    )

    -- Check for upload failure
    if uploadRespCode ~= 200 and uploadRespCode ~= 201 then
        return false, LOC("$$$/iNat/Error/PhotoUploadFailed=Photo upload failed. Code: ") .. tostring(uploadRespCode)
    end

    return true
end

return M

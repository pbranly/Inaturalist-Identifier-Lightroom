--[[
=====================================================================================
 Script    : UploadObservation.lua
 Purpose   : Upload a tagged photo as an observation to iNaturalist via their API,
             after user confirmation.

 Description :
 This module takes a Lightroom photo and uploads it to iNaturalist as an observation,
 using metadata such as species name (from keywords), GPS coordinates, and capture time.

 Workflow:
   1. Prompts the user with a Yes/No confirmation dialog.
   2. If confirmed:
      - Exports photo temporarily.
      - Extracts species name (from keywords), GPS location, and timestamp.
      - Sends a multipart/form-data POST request to iNaturalist.
      - Shows success/failure message.
   3. If declined: logs cancellation and does nothing.

 Dependencies:
   - Lightroom SDK: LrHttp, LrPathUtils, LrFileUtils, LrApplication, LrDialogs, LrTasks
   - export_to_tempo.lua → To export JPEG temporarily
   - Logger.lua

 Author    : Philippe
=====================================================================================
--]]

local LrHttp = import "LrHttp"
local LrPathUtils = import "LrPathUtils"
local LrFileUtils = import "LrFileUtils"
local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"
local LrTasks = import "LrTasks"

local export_to_tempo = require("export_to_tempo")
local logger = require("Logger")

--- Uploads an observation for the given photo to iNaturalist
-- @param photo (LrPhoto) Lightroom photo object
-- @param token (string) OAuth2 token for iNaturalist
-- @return true on success, or (false, errorMessage)
local function upload(photo, token)
    -- Ask the user for confirmation before uploading
    local response = LrDialogs.confirm(
        LOC("$$$/iNat/Dialog/AskObservation=Do you want to submit this photo as an observation to iNaturalist?"),
        LOC("$$$/iNat/Dialog/AskObservationDetails=The selected species will be submitted with the photo."),
        LOC("$$$/iNat/Dialog/Submit=Submit"),
        LOC("$$$/iNat/Dialog/Cancel=Cancel")
    )

    if response ~= "ok" then
        logger.logMessage("[UploadObservation] User cancelled observation upload.")
        return false, "User cancelled"
    end

    -- Run the upload in a background task to keep UI responsive
    LrTasks.startAsyncTask(function()
        logger.logMessage("Starting upload to iNaturalist...")

        -- Export JPEG to temporary path
        local imagePath, err = export_to_tempo.exportToTempo(photo)
        if not imagePath then
            LrDialogs.message("Export failed", err or "Unknown error", "critical")
            return
        end

        -- Extract species name from keywords (looks for Latin name inside parentheses)
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
            LrDialogs.message(
                LOC("$$$/iNat/Dialog/NoSpecies=No species name found in keywords."),
                LOC("$$$/iNat/Dialog/CheckKeywords=Please tag the photo with a species name before submitting."),
                "critical"
            )
            return
        end

        -- Get capture time and GPS coordinates
        local takenAt = photo:getRawMetadata("dateTimeOriginal") or os.date("!%Y-%m-%dT%H:%M:%SZ")
        local lat = photo:getRawMetadata("gpsLatitude")
        local lon = photo:getRawMetadata("gpsLongitude")

        -- Prepare POST body as multipart/form-data
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
        table.insert(bodyParts, "--" .. boundary)
        table.insert(bodyParts, 'Content-Disposition: form-data; name="observation[photo]"; filename="photo.jpg"\r\n'
            .. 'Content-Type: image/jpeg\r\n\r\n')
        local imageData = LrFileUtils.readFile(imagePath)
        table.insert(bodyParts, imageData)
        table.insert(bodyParts, "\r\n--" .. boundary .. "--\r\n")

        local requestBody = table.concat(bodyParts)
        local headers = {
            { field = "Authorization", value = "Bearer " .. token },
            { field = "Content-Type", value = "multipart/form-data; boundary=" .. boundary },
        }

        local result, hdrs = LrHttp.post("https://api.inaturalist.org/v1/observations", requestBody, headers)

        if hdrs and hdrs.status and hdrs.status >= 200 and hdrs.status < 300 then
            logger.logMessage("Upload successful. Status: " .. tostring(hdrs.status))
            LrDialogs.message(
                LOC("$$$/iNat/Dialog/ObservationSubmitted=Observation submitted successfully."),
                LOC("$$$/iNat/Dialog/Thanks=Thank you for contributing to science!")
            )
        else
            local status = hdrs and hdrs.status or "unknown"
            logger.logMessage("Upload failed. Status: " .. tostring(status))
            LrDialogs.message(
                LOC("$$$/iNat/Dialog/ObservationFailed=Failed to submit observation."),
                LOC("$$$/iNat/Dialog/Status=Status: ") .. tostring(status),
                "critical"
            )
        end
    end)

    return true
end

-- Return the module
return {
    upload = upload
}

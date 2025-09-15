--[[
    observation_selection.lua
    -------------------------
    Part of the Lightroom plugin "iNaturalist Identifier".

    Purpose:
      - Take the exported photo (tempo.jpg)
      - Attach the keywords chosen in Lightroom (e.g. "Common Kestrel (Falco tinnunculus)")
      - Use the stored OAuth2 token from plugin preferences
      - Build a proper multipart/form-data request for the iNaturalist API
      - Submit an observation via POST https://api.inaturalist.org/v1/observations
      - Log all details (request, headers, raw response)
      - Handle user confirmation dialogs inside Lightroom

    Recent changes:
      - Wrapped everything in LrTasks.startAsyncTask to fix
        "Yielding is not allowed within a C or metamethod call".
      - Added full HTTP request logging (URL, headers, multipart parameters).
      - Clear Lightroom dialog messages showing API feedback.

    Author : Philippe + ChatGPT
    Date   : 2025-09-15
--]]

local LrDialogs = import 'LrDialogs'
local LrHttp    = import 'LrHttp'
local LrTasks   = import 'LrTasks'
local LrLogger  = import 'LrLogger'

-- Initialize logger
local logger = LrLogger('observation_selection')
logger:enable("logfile")

local observation = {}

-----------------------------------------------------------------------
-- Internal function: build and send multipart request
-----------------------------------------------------------------------
local function submitObservation(photoPath, keyword, token)
    logger.logMessage("[observation_selection] Preparing multipart parameters:")

    -- Prepare multipart parts
    local params = {
        {
            name = "observation[species_guess]",
            value = keyword,
        },
        {
            name = "observation[observed_on]",
            value = os.date("%Y-%m-%d"),
        },
        {
            name = "observation[observation_photos_attributes][0][photo]",
            filePath = photoPath,
            fileName = "tempo.jpg",
            contentType = "image/jpeg",
        }
    }

    for i, part in ipairs(params) do
        if part.value then
            logger.logMessage(string.format("  part %d: %s = %s", i, part.name, tostring(part.value)))
        else
            logger.logMessage(string.format("  part %d: %s (fileName=%s, filePath=%s)", i, part.name, part.fileName, part.filePath))
        end
    end

    -- Prepare headers
    local headers = {
        { field = "Authorization", value = "Bearer " .. token }
    }

    logger.logMessage("[observation_selection] HTTP Request:")
    logger.logMessage("POST https://api.inaturalist.org/v1/observations")
    logger.logMessage("Headers:")
    for _, h in ipairs(headers) do
        logger.logMessage("  " .. h.field .. ": " .. h.value)
    end

    logger.logMessage("Multipart Parameters:")
    for i, part in ipairs(params) do
        if part.value then
            logger.logMessage(string.format("  part %d: %s = %s", i, part.name, tostring(part.value)))
        else
            logger.logMessage(string.format("  part %d: %s (fileName=%s, filePath=%s)", i, part.name, part.fileName, part.filePath))
        end
    end

    -- Perform HTTP request
    local result, headersOut = LrHttp.postMultipart("https://api.inaturalist.org/v1/observations", params, headers)

    -- Log raw response
    logger.logMessage("[observation_selection] API response body: " .. tostring(result))
    if headersOut then
        for k, v in pairs(headersOut) do
            logger.logMessage("[observation_selection] Header: " .. tostring(k) .. " = " .. tostring(v))
        end
    end

    -- Return success/failure
    if result and result:find("id") then
        return true, result
    else
        return false, result
    end
end

-----------------------------------------------------------------------
-- Public function: called from SelectAndTagResults.lua
-----------------------------------------------------------------------
function observation.askSubmit(photoPath, keyword, token)
    -- Run inside an async task to avoid coroutine errors
    LrTasks.startAsyncTask(function()
        local response = LrDialogs.confirm(
            LOC("$$$/iNat/Dialog/AskObservation=Do you want to submit this photo as an observation to iNaturalist?"),
            LOC("$$$/iNat/Dialog/AskObservationDetails=The selected species will be submitted with the photo."),
            LOC("$$$/iNat/Dialog/Submit=Submit"),
            LOC("$$$/iNat/Dialog/Cancel=Cancel")
        )

        if response == "ok" then
            logger.logMessage("[observation_selection] Submitting observation...")

            local success, msg = submitObservation(photoPath, keyword, token)

            -- Always display raw API response
            LrDialogs.message(
                "iNaturalist API response",
                msg or "No message returned.",
                "info"
            )

            if success then
                LrDialogs.message(
                    LOC("$$$/iNat/Dialog/ObservationSubmitted=Observation submitted successfully."),
                    LOC("$$$/iNat/Dialog/Thanks=Thank you for contributing to science!")
                )
            else
                LrDialogs.message(
                    LOC("$$$/iNat/Dialog/ObservationFailed=Failed to submit observation."),
                    msg or LOC("$$$/iNat/Dialog/UnknownError=Unknown error occurred.")
                )
            end
        else
            logger.logMessage("[observation_selection] User cancelled observation submission.")
        end
    end)
end

-----------------------------------------------------------------------
-- Return module
-----------------------------------------------------------------------
return observation

--[[
    Script: observation_selection.lua
    ---------------------------------
    This script handles user interaction for submitting an exported photo 
    (tempo.jpg) as an observation to the iNaturalist platform from within Lightroom.

    Purpose:
    --------
    Displays a confirmation dialog asking the user whether they want to submit 
    the exported photo as an observation (with species information) to iNaturalist.

    How It Works:
    -------------
    1. Prompts the user with a Yes/No dialog using `LrDialogs.confirm`.
    2. If the user confirms, starts an asynchronous task to:
       - Log the intent.
       - Call the `submitObservation()` internal function,
         using the path of the already-exported JPEG (tempo.jpg), 
         the species keywords, and the authentication token.
       - Show the raw JSON response from iNaturalist (for debugging).
       - Show a success or error message based on the result.
    3. If the user cancels, it logs that the action was aborted.

    Dependencies:
    -------------
    - Logger.lua              : Logs success, failure, or cancellation messages.
    - Lightroom SDK           : Used for dialogs, background tasks, and HTTP requests.
    - Translated LOC strings  : Used for multi-language support in UI prompts and messages.

    Notes:
    ------
    - The photo to submit must already have been exported via `export_photo_to_tempo.lua`.
    - This script is autonomous and calls the iNaturalist API directly.
    - Required parameters: 
        * photoPath (string) : full path to the exported file (tempo.jpg).
        * keyword  (string or table) : selected species keywords.
        * token    (string) : iNaturalist authentication token (OAuth2 Bearer).
]]

-- observation_selection.lua

-- Import Lightroom SDK modules
local LrDialogs    = import "LrDialogs"
local LrTasks      = import "LrTasks"
local LrHttp       = import "LrHttp"
local LrFileUtils  = import "LrFileUtils"

-- Import custom modules
local logger = require("Logger")
local LOC = LOC

-- Define a local table to store functions
local observation = {}

--------------------------------------------------------------------------------
-- Internal function to submit an observation to iNaturalist
-- photoPath : full path of the exported JPEG
-- keyword   : species keyword(s) (string or table)
-- token     : iNaturalist authentication token
--------------------------------------------------------------------------------
local function submitObservation(photoPath, keyword, token)
    -- Ensure keyword is a string; if table, join multiple keywords with comma
    local species_guess_str
    if type(keyword) == "table" then
        species_guess_str = table.concat(keyword, ", ")
    else
        species_guess_str = tostring(keyword or "Unknown species")
    end

    -- Build multipart parameters for iNaturalist API
    local params = {
        {
            name = "observation[species_guess]",
            value = species_guess_str
        },
        {
            name = "observation[observed_on]",
            value = os.date("!%Y-%m-%d") -- Current date in UTC
        },
        {
            name = "observation[photos_attributes][0][file]",  -- updated field name
            fileName = "tempo.jpg",
            filePath = photoPath,
            contentType = "image/jpeg"
        }
    }

    -- HTTP headers with authentication
    local headers = {
        { field = "Authorization", value = "Bearer " .. token }
    }

    -- === Log complet de la requête HTTP avant envoi ===
    logger.logMessage("[observation_selection] HTTP Request:")
    logger.logMessage("POST https://api.inaturalist.org/v1/observations")
    logger.logMessage("Headers:")
    for _, h in ipairs(headers) do
        logger.logMessage("  " .. h.field .. ": " .. h.value)
    end
    logger.logMessage("Multipart Parameters:")
    for i, p in ipairs(params) do
        local desc = "  part " .. i .. ": " .. p.name
        if p.value then desc = desc .. " = " .. tostring(p.value) end
        if p.fileName then desc = desc .. " (fileName=" .. p.fileName .. ", filePath=" .. p.filePath .. ")" end
        logger.logMessage(desc)
    end
    -- === Fin log ===

    -- Perform POST request to iNaturalist API
    local result, hdrs = LrHttp.postMultipart(
        "https://api.inaturalist.org/v1/observations",
        params,
        headers
    )

    -- Log raw server response and headers
    logger.logMessage("[observation_selection] API response body: " .. (result or "nil"))
    if hdrs then
        for k, v in pairs(hdrs) do
            logger.logMessage("[observation_selection] Header: " .. tostring(k) .. " = " .. tostring(v))
        end
    else
        logger.logMessage("[observation_selection] No headers returned from server")
    end

    -- Analyse response
    if not result or result == "" then
        return false, "No response from server."
    elseif string.find(result, '"error"') or string.find(result, '"errors"') then
        return false, result
    else
        return true, result
    end
end

--------------------------------------------------------------------------------
-- Main function to ask the user if they want to submit an observation
-- photoPath = full path of tempo.jpg (exported earlier)
-- keyword   = selected species keyword(s)
-- token     = iNaturalist authentication token
--------------------------------------------------------------------------------
function observation.askSubmit(photoPath, keyword, token)
    local response = LrDialogs.confirm(
        LOC("$$$/iNat/Dialog/AskObservation=Do you want to submit this photo as an observation to iNaturalist?"),
        LOC("$$$/iNat/Dialog/AskObservationDetails=The selected species will be submitted with the photo."),
        LOC("$$$/iNat/Dialog/Submit=Submit"),
        LOC("$$$/iNat/Dialog/Cancel=Cancel")
    )

    if response == "ok" then
        LrTasks.startAsyncTask(function()
            logger.logMessage("[observation_selection] Submitting observation...")
            local success, msg = submitObservation(photoPath, keyword, token)

            -- Show raw API response
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
        end)
    else
        logger.logMessage("[observation_selection] User cancelled observation submission.")
    end
end

-- Return the observation module
return observation

--[[
============================================================
Functional Description
------------------------------------------------------------
This module `observation_selection.lua` handles submitting 
photos and species observations to iNaturalist from Lightroom.

Functional flow:
1. Receive the exported photo path (`tempo.jpg`) and selected 
   species keywords from Lightroom.
2. Ask the user for confirmation before submission.
3. Retrieve the OAuth2 token stored in plugin preferences.
4. Build a multipart/form-data HTTP POST request to 
   https://api.inaturalist.org/v1/observations.
5. Log all details, including multipart parameters, headers, 
   and a corresponding `curl` command for testing.
6. Submit the observation using `LrHttp.postMultipart`.
7. Handle the API response, log it, and show dialogs for success 
   or failure.

Modules and Scripts Used:
- Lightroom SDK:
    * LrDialogs
    * LrHttp
    * LrTasks
    * LrLogger
- logger.lua : Logging utility used across all modules

Numbered Steps:
------------------------------------------------------------
1. Import Lightroom SDK modules + logger
2. Define internal function `submitObservation` that:
    2.1 Builds multipart parameters
    2.2 Logs parameters and headers
    2.3 Logs equivalent `curl` command for testing
    2.4 Sends HTTP request via `LrHttp.postMultipart`
    2.5 Returns success status and raw response
3. Define public function `askSubmit` that:
    3.1 Logs start and parameters
    3.2 Runs a Lightroom async task
    3.3 Shows user confirmation dialog
    3.4 Calls `submitObservation` if user confirms
    3.5 Shows success/error dialogs based on API response
============================================================
]]

-- [Step 1] Import Lightroom SDK modules
local LrDialogs = import 'LrDialogs'
local LrHttp    = import 'LrHttp'
local LrTasks   = import 'LrTasks'
local logger    = require("Logger")  -- Homogeneous logging

local observation = {}

-----------------------------------------------------------------------
-- Internal function: build and send multipart request
-----------------------------------------------------------------------
local function submitObservation(photoPath, keywords, token)
    -- [2.1] Prepare multipart parameters
    logger.logMessage("[observation_selection] Preparing multipart parameters.")
    local params = {
        { name = "observation[species_guess]", value = table.concat(keywords, ", ") },
        { name = "observation[observed_on]", value = os.date("%Y-%m-%d") },
        { name = "observation[observation_photos_attributes][0][photo]",
          filePath = photoPath,
          fileName = "tempo.jpg",
          contentType = "image/jpeg"
        }
    }

    for i, part in ipairs(params) do
        if part.value then
            logger.logMessage(string.format("  part %d: %s = %s", i, part.name, tostring(part.value)))
        else
            logger.logMessage(string.format("  part %d: %s (fileName=%s, filePath=%s)", i, part.name, part.fileName, part.filePath))
        end
    end

    -- [2.2] Prepare headers
    local headers = { { field = "Authorization", value = "Bearer " .. token } }
    logger.logMessage("[observation_selection] Headers:")
    for _, h in ipairs(headers) do
        logger.logMessage("  " .. h.field .. ": " .. h.value)
    end

    -- [2.3] Log equivalent curl command for testing
    local curlCmd = 'curl -X POST "https://api.inaturalist.org/v1/observations" -H "Authorization: Bearer ' .. token .. '"'
    for _, part in ipairs(params) do
        if part.value then
            curlCmd = curlCmd .. ' -F "' .. part.name .. '=' .. tostring(part.value) .. '"'
        else
            curlCmd = curlCmd .. ' -F "' .. part.name .. '=@' .. part.filePath:gsub("\\","/") .. '"'
        end
    end
    logger.logMessage("[observation_selection] Equivalent curl command for testing:\n" .. curlCmd)

    -- [2.4] Perform HTTP request
    logger.logMessage("[observation_selection] Submitting POST request to iNaturalist API.")
    local result, headersOut = LrHttp.postMultipart("https://api.inaturalist.org/v1/observations", params, headers)

    -- [2.5] Log API response
    logger.logMessage("[observation_selection] API raw response: " .. tostring(result))
    if headersOut then
        for k, v in pairs(headersOut) do
            logger.logMessage("[observation_selection] Header: " .. tostring(k) .. " = " .. tostring(v))
        end
    end

    -- Determine success based on presence of "id" field
    if result and result:find('"id"') then
        return true, result
    else
        return false, result
    end
end

-----------------------------------------------------------------------
-- Public function: called from SelectAndTagResults.lua
-----------------------------------------------------------------------
function observation.askSubmit(photoPath, keywords, token)
    logger.logMessage("=== START askSubmit ===")
    logger.logMessage("Parameters received:")
    logger.logMessage("  photoPath: " .. tostring(photoPath))
    logger.logMessage("  keywords: " .. (type(keywords) == "table" and table.concat(keywords, ", ") or tostring(keywords)))
    logger.logMessage("  token: " .. (token and "***provided***" or "NIL"))

    -- [3.2] Run inside async task to avoid coroutine errors
    LrTasks.startAsyncTask(function()
        -- [3.3] Ask user for confirmation
        local response = LrDialogs.confirm(
            "Submit observation to iNaturalist?",
            "The selected species will be submitted with the photo.",
            "Submit",
            "Cancel"
        )
        logger.logMessage("[observation_selection] User dialog response: " .. tostring(response))

        if response == "ok" then
            logger.logMessage("[observation_selection] User confirmed - submitting observation.")
            local success, msg = submitObservation(photoPath, keywords, token)

            if success then
                logger.logMessage("[observation_selection] Observation submitted successfully.")
                LrDialogs.message("Observation submitted", "Thank you for contributing to science!")
            else
                logger.logMessage("[observation_selection] Failed to submit observation.")
                LrDialogs.message("Failed to submit observation", msg or "Unknown error occurred.")
            end
        else
            logger.logMessage("[observation_selection] User cancelled observation submission.")
        end

        logger.logMessage("=== END askSubmit ===")
    end)
end

-----------------------------------------------------------------------
-- Return module
-----------------------------------------------------------------------
return observation

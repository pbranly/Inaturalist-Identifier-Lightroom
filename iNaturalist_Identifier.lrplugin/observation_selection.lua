-- observation_selection.lua

-- Import Lightroom SDK modules
local LrDialogs = import "LrDialogs"         -- Provides dialog boxes (confirmation, alerts, etc.)
local LrTasks = import "LrTasks"             -- For running asynchronous tasks in Lightroom

-- Import custom modules
local logger = require("Logger")             -- Custom logging utility for debugging and info messages
local callAPI = require("call_inaturalist")  -- Module that handles API communication with iNaturalist
local LOC = LOC                              -- Localization function for translated strings

-- Define a local table to store functions
local observation = {}

-- Main function to ask the user if they want to submit an observation
function observation.askSubmit(photo, keywords, token)
    -- Show a confirmation dialog asking the user to submit the photo to iNaturalist
    local response = LrDialogs.confirm(
        LOC("$$$/iNat/Dialog/AskObservation=Do you want to submit this photo as an observation to iNaturalist?"),
        LOC("$$$/iNat/Dialog/AskObservationDetails=The selected species will be submitted with the photo."),
        LOC("$$$/iNat/Dialog/Submit=Submit"),     -- OK button text
        LOC("$$$/iNat/Dialog/Cancel=Cancel")      -- Cancel button text
    )

    -- If the user clicked OK (Submit)
    if response == "ok" then
        -- Start the submission as an asynchronous task to avoid blocking the Lightroom UI
        LrTasks.startAsyncTask(function()
            logger.logMessage("[observation_selection] Submitting observation...")

            -- Call the API submission function with the exported photo, selected keywords, and token
            local success, msg = callAPI.submitObservation(photo, keywords, token)

            -- If submission succeeded
            if success then
                -- Show success message
                LrDialogs.message(
                    LOC("$$$/iNat/Dialog/ObservationSubmitted=Observation submitted successfully."),
                    LOC("$$$/iNat/Dialog/Thanks=Thank you for contributing to science!")
                )
            else
                -- Show error message
                LrDialogs.message(
                    LOC("$$$/iNat/Dialog/ObservationFailed=Failed to submit observation."),
                    msg or LOC("$$$/iNat/Dialog/UnknownError=Unknown error occurred.")
                )
            end
        end)
    else
        -- Log that the user chose not to submit the observation
        logger.logMessage("[observation_selection] User cancelled observation submission.")
    end
end

-- Return the observation module to be used by other scripts
return observation

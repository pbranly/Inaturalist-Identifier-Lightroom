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
       - Call the `submitObservation()` function from the `call_inaturalist` module,
         using the path of the already-exported JPEG (tempo.jpg).
       - Show a success or error message based on the result.
    3. If the user cancels, it logs that the action was aborted.

    Dependencies:
    -------------
    - Logger.lua              : Logs success, failure, or cancellation messages.
    - call_inaturalist.lua    : Responsible for actual API interaction with iNaturalist.
    - Lightroom SDK           : Used for dialogs and background tasks.
    - Translated LOC strings  : Used for multi-language support in UI prompts and messages.

    Notes:
    ------
    - The photo to submit must already have been exported via `export_photo_to_tempo.lua`.
    - This script only receives the path to that exported file (tempo.jpg).
]]

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
-- photoPath = full path of tempo.jpg (exported earlier)
-- keywords  = selected species keywords
-- token     = iNaturalist authentication token
function observation.askSubmit(photoPath, keywords, token)
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

            -- Call the API submission function with the exported photo path, selected keywords, and token
            local success, msg = callAPI.submitObservation(photoPath, keywords, token)

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

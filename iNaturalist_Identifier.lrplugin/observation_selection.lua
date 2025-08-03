-- observation_selection.lua

local LrDialogs = import "LrDialogs"
local LrTasks = import "LrTasks"
local logger = require("Logger")
local callAPI = require("call_inaturalist")
local LOC = LOC

local observation = {}

function observation.askSubmit(photo, keywords, token)
    -- Ask user to submit observation
    local response = LrDialogs.confirm(
        LOC("$$$/iNat/Dialog/AskObservation=Do you want to submit this photo as an observation to iNaturalist?"),
        LOC("$$$/iNat/Dialog/AskObservationDetails=The selected species will be submitted with the photo."),
        LOC("$$$/iNat/Dialog/Submit=Submit"),
        LOC("$$$/iNat/Dialog/Cancel=Cancel")
    )

    if response == "ok" then
        -- Submit observation
        LrTasks.startAsyncTask(function()
            logger.logMessage("[observation_selection] Submitting observation...")

            local success, msg = callAPI.submitObservation(photo, keywords, token)

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

return observation

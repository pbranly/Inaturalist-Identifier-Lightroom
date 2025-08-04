--[[
=====================================================================================
 Script         : observation_selection.lua
 Purpose        : Prompt the user to confirm if they want to submit the selected
                  photo and species as an observation to iNaturalist.

 Functional Description:
 -----------------------
 This module provides a user interaction layer between species identification
 (keywords tagged on a photo) and the actual upload of an observation to 
 iNaturalist using their API.

 Responsibilities:
   1. Prompt the user with a confirmation dialog asking if they want to submit.
   2. If confirmed, delegate the upload operation to UploadObservation.lua.
   3. Handle success and failure messages for the user.
   4. Log the process at each step using Logger.lua.

 Workflow:
   - This script is triggered *after* species selection and keyword tagging.
   - It requires:
       • A valid `LrPhoto` object
       • A non-empty list of keywords (containing at least a Latin name)
       • A valid OAuth2 token for iNaturalist

 Dependencies:
   - Logger.lua             : Logs debug/info messages
   - UploadObservation.lua  : Executes actual API call to upload
   - Lightroom SDK:
       • LrDialogs          : For UI dialogs
       • LrTasks            : To run background upload
   - LOC() translation keys : For multilingual support

 Author          : Philippe
=====================================================================================
--]]

-- Import Lightroom SDK modules
local LrDialogs = import "LrDialogs"
local LrTasks = import "LrTasks"

-- Custom modules
local logger = require("Logger")
local uploader = require("UploadObservation") -- Handles the actual API request

-- Module table
local observation = {}

--- Prompts the user and uploads the observation if confirmed
-- @param photo (LrPhoto) : The Lightroom photo object
-- @param keywords (table) : List of keywords (usually including species name)
-- @param token (string) : OAuth2 token for authenticating with iNaturalist API
function observation.askSubmit(photo, keywords, token)
    -- Basic validation
    if not photo or not keywords or #keywords == 0 or not token then
        logger.logMessage("[observation_selection] Invalid inputs.")
        return
    end

    -- Ask user for confirmation before submitting
    local response = LrDialogs.confirm(
        LOC("$$$/iNat/Dialog/AskObservation=Do you want to submit this photo as an observation to iNaturalist?"),
        LOC("$$$/iNat/Dialog/AskObservationDetails=The selected species will be submitted with the photo."),
        LOC("$$$/iNat/Dialog/Submit=Submit"),
        LOC("$$$/iNat/Dialog/Cancel=Cancel")
    )

    if response == "ok" then
        -- Submit asynchronously to avoid UI blocking
        LrTasks.startAsyncTask(function()
            logger.logMessage("[observation_selection] Submitting observation...")

            local success, message = uploader.upload(photo, token)

            if success then
                LrDialogs.message(
                    LOC("$$$/iNat/Dialog/ObservationSubmitted=Observation submitted successfully."),
                    LOC("$$$/iNat/Dialog/Thanks=Thank you for contributing to science!")
                )
                logger.logMessage("[observation_selection] Upload successful.")
            else
                LrDialogs.message(
                    LOC("$$$/iNat/Dialog/ObservationFailed=Failed to submit observation."),
                    message or LOC("$$$/iNat/Dialog/UnknownError=Unknown error occurred.")
                )
                logger.logMessage("[observation_selection] Upload failed: " .. (message or "unknown error"))
            end
        end)
    else
        logger.logMessage("[observation_selection] User cancelled observation submission.")
    end
end

-- Return module
return observation

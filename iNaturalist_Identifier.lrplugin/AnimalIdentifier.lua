--[[
=====================================================================================
 Script : AnimalIdentifier.lua
 Purpose : Main Lightroom Classic integration for species identification and 
           optional observation upload using the iNaturalist API.
 Author  : Philippe Branly

 Description :
 This script is the entry point that:
   1. Retrieves the currently selected photo in Lightroom Classic.
   2. Exports it temporarily as a JPEG (`tempo.jpg`).
   3. Calls the iNaturalist AI identification service through `UploadObservation.lua`.
   4. Displays the candidate species to the user via `SelectAndTagResults.lua`,
      allowing them to choose one or more keywords to tag the photo.
   5. After tagging is completed, optionally calls 
      `UploadObservation.submitObservation()` to upload the observation.

 The script does **not** perform observation submission directly anymore.
 It delegates the task to the `UploadObservation.lua` module.

 Requirements :
   - A valid API token stored in plugin preferences (`prefs.token`).
   - JPEG export capability (Lightroom SDK).
   - `UploadObservation.lua` for API calls.
   - `SelectAndTagResults.lua` for UI selection and tagging.

 Workflow :
   Lightroom Photo → Export temp JPEG → iNat Identification → User selects species →
   Tag photo → Submit observation via API.

 Dependencies :
   - LrApplication, LrTasks, LrDialogs, LrFunctionContext (Lightroom SDK)
   - `UploadObservation.lua`
   - `SelectAndTagResults.lua`
=====================================================================================
--]]

-- Lightroom SDK modules
local LrApplication = import("LrApplication")
local LrTasks = import("LrTasks")
local LrDialogs = import("LrDialogs")
local LrFunctionContext = import("LrFunctionContext")

-- Plugin modules
local call_iNat = require("UploadObservation")
local selector = require("SelectAndTagResults")

-- Main function to identify species and then optionally upload observation
local function identifyAndUpload()
    LrFunctionContext.callWithContext("identifyAndUpload", function(context)
        local catalog = LrApplication.activeCatalog()
        local photo = catalog:getTargetPhoto()

        if not photo then
            LrDialogs.message(LOC("$$$/iNat/Error/NoPhoto=No photo selected."))
            return
        end

        -- Retrieve stored API token
        local prefs = import("LrPrefs").prefsForPlugin()
        local token = prefs.token
        if not token or token == "" then
            LrDialogs.message(LOC("$$$/iNat/Error/NoToken=No iNaturalist token found. Please configure it first."))
            return
        end

        -- Export temporary JPEG for API processing
        local imagePath = _PLUGIN.path .. "/tempo.jpg"
        catalog:withWriteAccessDo("Export temp image", function()
            photo:requestJpegThumbnail(3000, 3000, imagePath)
        end)

        -- Identification via iNaturalist API
        local result, err = call_iNat.identify(imagePath, token)
        if not result then
            LrDialogs.message(err or LOC("$$$/iNat/Error/IdentificationFailed=Identification failed."))
            return
        end

        -- Let the user choose species to tag (must return keywords)
        local keywords = selector.showSelection(photo, result, token)
        if not keywords or #keywords == 0 then
            return -- user cancelled or no keywords chosen
        end

        -- After tagging, submit observation
        local ok, msg = call_iNat.UploadObservation(photo, keywords, token)
        if not ok then
            LrDialogs.message(msg or LOC("$$$/iNat/Error/UploadFailed=Observation upload failed."))
        else
            LrDialogs.message(LOC("$$$/iNat/UploadSuccess=Observation uploaded successfully."))
        end
    end)
end

-- Run asynchronously to keep the UI responsive
LrTasks.startAsyncTask(identifyAndUpload)

--[[
=====================================================================================
 Script    : AnimalIdentifier.lua
 Purpose   : Main controller script for the Lightroom iNaturalist plugin.
             Automates the process of recognizing species in a selected photo using
             the iNaturalist API and allows tagging and optional upload.

 Functionality :
   - Retrieves the selected photo in Lightroom.
   - Loads the user's iNaturalist authentication token.
   - Validates the token (presence and expiry).
   - Exports the selected photo as a temporary JPEG file (tempo.jpg).
   - Sends the image to the iNaturalist API for automated species identification.
   - Parses the results and automatically opens a species selection dialog.
   - If the user validates one or more species:
       → adds them as keywords to the photo in Lightroom,
       → asks whether to upload the observation to iNaturalist,
       → if confirmed, delegates to UploadObservation.lua.

 Modifications from previous version:
   - Removed raw result display (no LrDialogs.message with all predictions).
   - Automatically proceeds to species selection if valid predictions exist.
   - Introduces a confirmation dialog for sending observation after tagging.
   - Requires new script: `UploadObservation.lua` (not yet implemented).

 Dependencies :
   - Logger.lua              → Logging utility for all steps and errors.
   - TokenUpdater.lua        → UI to update user's iNaturalist token.
   - VerificationToken.lua   → Token validity checker.
   - export_to_tempo.lua     → Handles export of selected photo to JPEG.
   - call_inaturalist.lua    → Makes API call to iNaturalist for identification.
   - SelectAndTagResults.lua → UI for selecting species to tag and confirm upload.
   - UploadObservation.lua   → [To be created] Sends observation to iNaturalist API.

 Invoked by :
   - main.lua (menu entry handler)
   - Registered via `info.lua` in Lightroom export menu

 Author    : Philippe (adapted version)
=====================================================================================
--]]

-- Lightroom SDK modules
local LrTasks        = import "LrTasks"
local LrDialogs      = import "LrDialogs"
local LrApplication  = import "LrApplication"
local LrPrefs        = import "LrPrefs"

-- Custom plugin modules
local logger          = require("Logger")
local tokenUpdater    = require("TokenUpdater")
local tokenChecker    = require("VerificationToken")
local callAPI         = require("call_inaturalist")
local export_to_tempo = require("export_to_tempo")
local LOC             = LOC

-- Main identification function
local function identifyAnimal()
    LrTasks.startAsyncTask(function()

        -- Initialize log and notify user
        logger.initializeLogFile()
        logger.logMessage(LOC("$$$/iNat/Log/Started=Plugin started"))
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Started=Plugin started"), 2)

        -- Load API token from preferences
        local prefs = LrPrefs.prefsForPlugin()
        local token = prefs.token

        -- Token required
        if not token or token == "" then
            logger.notify(LOC("$$$/iNat/Error/TokenMissing=Token is missing. Please enter it in Preferences."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- Check if token is valid
        local isValid, msg = tokenChecker.isTokenValid()
        if not isValid then
            logger.notify(LOC("$$$/iNat/Error/TokenInvalid=Invalid or expired token."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- Get selected photo
        local catalog = LrApplication.activeCatalog()
        local photo = catalog:getTargetPhoto()
        if not photo then
            logger.logMessage("No photo selected.")
            LrDialogs.showBezel("No photo selected.", 3)
            return
        end

        local filename = photo:getFormattedMetadata("fileName") or "unknown"
        logger.logMessage("Selected photo: " .. filename)
        LrDialogs.showBezel("Selected photo: " .. filename, 2)

        -- Export photo to tempo.jpg
        local exportedPath, err = export_to_tempo.exportToTempo(photo)
        if not exportedPath then
            logger.logMessage("Failed to export image: " .. (err or "unknown"))
            LrDialogs.showBezel("Image export failed.", 3)
            return
        end

        logger.logMessage("Image exported to tempo.jpg")
        LrDialogs.showBezel("Image exported to tempo.jpg", 2)

        -- Call iNaturalist API to identify species
        local result, err = callAPI.identify(exportedPath, token)
        if not result then
            logger.logMessage("API error: " .. (err or "unknown"))
            LrDialogs.message("Identification failed", err or "Unknown error.")
            return
        end

        -- Check format of returned results
        local hasTitle = result:match("🕊️")
        local count = 0
        for line in result:gmatch("[^\r\n]+") do
            if line:match("%%") and line:match("%(") and line:match("%)") then
                count = count + 1
            end
        end

        -- Open selection dialog if valid results
        if hasTitle and count > 0 then
            logger.logMessage("Identification results:\n" .. result)

            local selector = require("SelectAndTagResults")
            selector.showSelection(photo, result, token)

        else
            LrDialogs.showBezel("No results found.", 3)
            logger.logMessage("No identification results.")
        end
    end)
end

return {
    identify = identifyAnimal
}

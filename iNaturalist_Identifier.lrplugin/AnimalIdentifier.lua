--[[
=====================================================================================
 Script    : AnimalIdentifier.lua
 Purpose   : Main controller script for the Lightroom iNaturalist plugin.
             Automates the process of recognizing species in a selected photo using
             the iNaturalist API, and allows tagging of results.

 Functionality:
   - Retrieves the selected photo from Lightroom.
   - Loads the user's iNaturalist authentication token from preferences.
   - Validates the token (checks existence and expiry).
   - Exports the selected photo as a temporary JPEG file (tempo.jpg).
   - Sends the exported image to the iNaturalist API for species identification.
   - Parses API results and determines whether to open a selection dialog.
   - If valid species predictions exist, opens a dialog for the user to choose which
     species to tag in the Lightroom catalog.

 Dependencies:
   - Logger.lua              → Logging utility for plugin operations and errors.
   - TokenUpdater.lua        → UI for updating the user's iNaturalist token.
   - VerificationToken.lua   → Validates token expiry and authenticity.
   - export_to_tempo.lua     → Exports the selected photo to a temporary JPEG.
   - call_inaturalist.lua    → Makes API calls to the iNaturalist service.
   - SelectAndTagResults.lua → Provides UI for selecting and tagging species.

 Invoked by:
   - main.lua (via menu entry)
   - Registered in `info.lua` for Lightroom export menu actions

 Author    : Philippe Branly
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

-- Main identification function
local function identifyAnimal()
    LrTasks.startAsyncTask(function()

        -- Initialize log file and internal logs
        logger.initializeLogFile()
        logger.logMessage("=== Plugin started ===")
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Started=Plugin started"), 2)

        -- Retrieve API token from plugin preferences
        local prefs = LrPrefs.prefsForPlugin()
        local token = prefs.token

        -- No token → prompt user
        if not token or token == "" then
            logger.logMessage("No token found in preferences.")
            LrDialogs.message(
                LOC("$$$/iNat/Error/TokenMissing=Token is missing. Please enter it in Preferences.")
            )
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- Token exists → validate it
        local isValid, _ = tokenChecker.isTokenValid()
        if not isValid then
            logger.logMessage("Token invalid or expired.")
            LrDialogs.message(
                LOC("$$$/iNat/Error/TokenInvalid=Invalid or expired token.")
            )
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- Retrieve selected photo
        local catalog = LrApplication.activeCatalog()
        local photo = catalog:getTargetPhoto()
        if not photo then
            logger.logMessage("No photo selected.")
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoPhoto=No photo selected."), 3)
            return
        end

        -- Filename for logs
        local filename = photo:getFormattedMetadata("fileName") or "unknown"
        logger.logMessage("Selected photo: " .. filename)
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/SelectedPhoto=Selected photo: ") .. filename, 2)

        -- Export to tempo.jpg
        local exportedPath, err = export_to_tempo.exportToTempo(photo)
        if not exportedPath then
            logger.logMessage("Image export failed: " .. (err or "unknown"))
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/ExportFailed=Image export failed."), 3)
            return
        end

        logger.logMessage("Image exported as tempo.jpg")
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Exported=Image exported to tempo.jpg"), 2)

        -- Call API
        local result, apiErr = callAPI.identify(exportedPath, token)
        if not result then
            logger.logMessage("API error: " .. (apiErr or "unknown"))
            LrDialogs.message(
                LOC("$$$/iNat/Dialog/IdentificationFailed=Identification failed"),
                apiErr or LOC("$$$/iNat/Dialog/UnknownError=Unknown error.")
            )
            return
        end

        -- Parse results
        local hasTitle = result:match("🕊️")
        local count = 0
        for line in result:gmatch("[^\r\n]+") do
            if line:match("%%") and line:match("%(") and line:match("%)") then
                count = count + 1
            end
        end

        if hasTitle and count > 0 then
            logger.logMessage("Identification results:\n" .. result)
            local selector = require("SelectAndTagResults")
            selector.showSelection(photo, result, token)
        else
            logger.logMessage("No identification results.")
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoResult=No results found."), 3)
        end
    end)
end

return {
    identify = identifyAnimal
}

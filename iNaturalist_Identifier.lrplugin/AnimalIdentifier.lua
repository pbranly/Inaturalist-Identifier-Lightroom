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
local LrTasks        = import "LrTasks"        -- Allows asynchronous task execution
local LrDialogs      = import "LrDialogs"      -- UI dialogs, notifications, and bezels
local LrApplication  = import "LrApplication"  -- Access to Lightroom's catalog and photo objects
local LrPrefs        = import "LrPrefs"        -- Access to plugin-specific preferences storage

-- Custom plugin modules
local logger          = require("Logger")           -- Centralized logging
local tokenUpdater    = require("TokenUpdater")     -- Handles token update UI
local tokenChecker    = require("VerificationToken")-- Token validation utility
local callAPI         = require("call_inaturalist") -- API request handler
local export_to_tempo = require("export_to_tempo")  -- Temporary export utility
local LOC             = LOC                         -- Lightroom's localization function

-- Main identification function
local function identifyAnimal()
    -- Run the process asynchronously so Lightroom's UI remains responsive
    LrTasks.startAsyncTask(function()

        -- Initialize log file and notify the user
        logger.initializeLogFile()
        logger.logMessage(LOC("$$$/iNat/Log/Started=Plugin started"))
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Started=Plugin started"), 2)

        -- Retrieve API token from plugin preferences
        local prefs = LrPrefs.prefsForPlugin()
        local token = prefs.token

        -- Case 1: No token stored → prompt user to update it
        if not token or token == "" then
            logger.notify(LOC("$$$/iNat/Error/TokenMissing=Token is missing. Please enter it in Preferences."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- Case 2: Token exists → check if it's still valid
        local isValid, msg = tokenChecker.isTokenValid()
        if not isValid then
            logger.notify(LOC("$$$/iNat/Error/TokenInvalid=Invalid or expired token."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- Retrieve the active photo from the Lightroom catalog
        local catalog = LrApplication.activeCatalog()
        local photo = catalog:getTargetPhoto()
        if not photo then
            logger.logMessage(LOC("$$$/iNat/Log/NoPhoto=No photo selected."))
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoPhoto=No photo selected."), 3)
            return
        end

        -- Get photo filename for logs and UI
        local filename = photo:getFormattedMetadata("fileName") or "unknown"
        logger.logMessage(LOC("$$$/iNat/Log/SelectedPhoto=Selected photo: ") .. filename)
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/SelectedPhoto=Selected photo: ") .. filename, 2)

        -- Export the selected photo as a temporary JPEG file
        local exportedPath, err = export_to_tempo.exportToTempo(photo)
        if not exportedPath then
            logger.logMessage(LOC("$$$/iNat/Log/ExportFailed=Failed to export image: ") .. (err or "unknown"))
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/ExportFailed=Image export failed."), 3)
            return
        end

        logger.logMessage(LOC("$$$/iNat/Log/Exported=Image exported as tempo.jpg"))
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Exported=Image exported to tempo.jpg"), 2)

        -- Send exported image to the iNaturalist API for identification
        local result, err = callAPI.identify(exportedPath, token)
        if not result then
            logger.logMessage(LOC("$$$/iNat/Log/APIError=API error: ") .. (err or "unknown"))
            LrDialogs.message(
                LOC("$$$/iNat/Dialog/IdentificationFailed=Identification failed"),
                err or LOC("$$$/iNat/Dialog/UnknownError=Unknown error.")
            )
            return
        end

        -- Analyze returned results
        -- hasTitle: checks if header marker 🕊️ is present
        local hasTitle = result:match("🕊️")
        local count = 0
        -- Count valid prediction lines (percentage + parentheses for species name)
        for line in result:gmatch("[^\r\n]+") do
            if line:match("%%") and line:match("%(") and line:match("%)") then
                count = count + 1
            end
        end

        -- If we have a title and at least one valid prediction → proceed
        if hasTitle and count > 0 then
            logger.logMessage(LOC("$$$/iNat/Log/Results=Identification results:\n") .. result)

            -- Open selection dialog for the user to choose species
            local selector = require("SelectAndTagResults")
            selector.showSelection(photo, result, token)

        else
            -- No usable results found
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoResult=No results found."), 3)
            logger.logMessage(LOC("$$$/iNat/Log/NoResult=No identification results."))
        end
    end)
end

-- Expose public API for other scripts
return {
    identify = identifyAnimal
}

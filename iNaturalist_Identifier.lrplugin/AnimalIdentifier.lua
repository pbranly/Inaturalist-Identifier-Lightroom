--[[
=====================================================================================
 Script   : AnimalIdentifier.lua
 Purpose  : Main logic for identifying wildlife species in a Lightroom photo using 
            the iNaturalist API.
 Author   : Philippe

 Description :
 ------------
 This script is the core engine of the Lightroom plugin for automated species 
 identification using iNaturalist. It performs the following key tasks:

   1. Loads the user’s iNaturalist API token from plugin preferences.
   2. Validates the token's presence, format, and expiration.
   3. Exports the currently selected photo as a temporary JPEG.
   4. Sends the image to the iNaturalist API for identification.
   5. Parses and checks the results.
   6. Displays species recognition results to the user.
   7. Allows the user to optionally assign identified species as keywords.

 The script runs as an asynchronous task to keep Lightroom’s UI responsive 
 and includes error handling for all major failure scenarios.

 Dependencies:
 -------------
 - Logger.lua             : Logging utility for debugging and tracking.
 - TokenManager.lua       : UI helper for token input, saving, and validation.
 - call_inaturalist.lua   : Handles HTTP communication with the iNaturalist API.
 - export_to_tempo.lua    : Responsible for exporting the selected photo to a JPEG file.
 - SelectAndTagResults.lua: Displays identification results and keyword tagging interface.

 Usage:
 ------
 - This module is invoked via the plugin’s main menu entry.
 - Calls the identify() function as its main routine.
=====================================================================================
--]]

-- Lightroom SDK modules
local LrTasks       = import "LrTasks"
local LrDialogs     = import "LrDialogs"
local LrApplication = import "LrApplication"
local LrPrefs       = import "LrPrefs"

-- Custom plugin modules
local logger          = require("Logger")
local TokenManager    = require("TokenManager")
local callAPI         = require("call_inaturalist")
local export_to_tempo = require("export_to_tempo")

-- Localization (Lightroom’s LOC function)
local LOC = LOC

--------------------------------------------------------------------------------
-- Main function: identifies the animal in the selected Lightroom photo
--------------------------------------------------------------------------------
local function identifyAnimal()
    LrTasks.startAsyncTask(function()
        local success, err = pcall(function()

            -- Initialize logging
            logger.initializeLogFile()
            logger.logMessage("=== Plugin launched ===")
            logger.logMessage("Plugin started")
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Started=Plugin started"), 2)

            -- Load stored token
            logger.logMessage("Loading stored token from plugin preferences")
            local prefs = LrPrefs.prefsForPlugin()
            local token = prefs.token

            -- Validate token
            logger.logMessage("Validating API token")
            local isValid, msg = TokenManager.isTokenValid(token)
            if not isValid then
                logger.notify(msg or "Invalid or expired token.")
                logger.logMessage("Token invalid or expired, opening token dialog")
                TokenManager.showTokenDialog()
                return
            end

            -- Get selected photo
            logger.logMessage("Retrieving selected photo from catalog")
            local catalog = LrApplication.activeCatalog()
            local photo = catalog:getTargetPhoto()
            if not photo then
                logger.logMessage("No photo selected.")
                LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoPhoto=No photo selected."), 3)
                return
            end

            -- Log photo filename
            local filename = photo:getFormattedMetadata("fileName") or "unknown"
            logger.logMessage("Selected photo: " .. filename)
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/SelectedPhoto=Selected photo: ") .. filename, 2)

            -- Debug: check yield context
            logger.logMessage("DEBUG: Before export, LrTasks.canYield()=" .. tostring(LrTasks.canYield()))
            logger.logMessage("DEBUG: Call stack:\n" .. debug.traceback())

            -- Export photo to tempo.jpg (inside async context)
            logger.logMessage("Exporting selected photo to tempo.jpg")
            local exportedPath, expErr = export_to_tempo.exportToTempo(photo)
            if not exportedPath then
                logger.logMessage("Failed to export image: " .. (expErr or "unknown"))
                LrDialogs.showBezel(LOC("$$$/iNat/Bezel/ExportFailed=Image export failed."), 3)
                return
            end
            logger.logMessage("Image successfully exported as tempo.jpg")
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Exported=Image exported to tempo.jpg"), 2)

            -- Call the iNaturalist API
            logger.logMessage("Sending image to iNaturalist API for identification")
            local result, apiErr = callAPI.identify(exportedPath, token)
            if not result then
                logger.logMessage("API error: " .. (apiErr or "unknown"))
                LrDialogs.message(
                    LOC("$$$/iNat/Dialog/IdentificationFailed=Identification failed"),
                    apiErr or LOC("$$$/iNat/Dialog/UnknownError=Unknown error.")
                )
                return
            end

            -- Validate result format
            logger.logMessage("Validating identification results")
            local hasTitle = result:match("🕊️")
            local count = 0
            for line in result:gmatch("[^\r\n]+") do
                if line:match("%%") and line:match("%(") and line:match("%)") then
                    count = count + 1
                end
            end

            if hasTitle and count > 0 then
                logger.logMessage("Identification results:\n" .. result)
                LrDialogs.message(LOC("$$$/iNat/Dialog/Results=Identification results:"), result)

                logger.logMessage("Prompting user for keyword tagging")
                local choix = LrDialogs.confirm(
                    LOC("$$$/iNat/Dialog/AskTag=Do you want to add one or more identifications as keywords?"),
                    LOC("$$$/iNat/Dialog/AskTagDetails=Click 'Continue' to select species."),
                    LOC("$$$/iNat/Dialog/Continue=Continue"),
                    LOC("$$$/iNat/Dialog/Cancel=Cancel")
                )

                if choix == "ok" then
                    logger.logMessage("User chose to continue with tagging")
                    local selector = require("SelectAndTagResults")
                    selector.showSelection(result)
                else
                    logger.logMessage("User skipped tagging.")
                end
            else
                logger.logMessage("No identification results.")
                LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoResult=No results found."), 3)
            end

            -- Final notification
            logger.logMessage("Analysis completed.")
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Done=Analysis completed."), 2)
        end)

        -- Catch unexpected errors globally
        if not success then
            logger.logMessage("Unexpected error: " .. tostring(err))
            LrDialogs.message(
                LOC("$$$/iNat/Dialog/Error=Unexpected error"),
                tostring(err)
            )
        end
    end)
end

--------------------------------------------------------------------------------
-- Auto-execution when called via Lightroom menu
--------------------------------------------------------------------------------
identifyAnimal()

--------------------------------------------------------------------------------
-- Module export for external calls
--------------------------------------------------------------------------------
return {
    identify = identifyAnimal
}

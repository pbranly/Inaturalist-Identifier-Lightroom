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
    local success, err = pcall(function()

        print("🔍 Plugin launched")
        logger.initializeLogFile()
        logger.logMessage("=== Plugin launched ===")
        logger.logMessage("Plugin started")
        print("✅ Plugin started")
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Started=Plugin started"), 2)

        -- Load stored API token from preferences
        print("🔐 Loading API token")
        local prefs = LrPrefs.prefsForPlugin()
        local token = prefs.token

        -- Validate the token (format and expiration)
        print("🔎 Validating token")
        logger.logMessage("Validating API token")
        local isValid, msg = TokenManager.isTokenValid(token)
        if not isValid then
            print("❌ Token invalid or expired")
            logger.notify(msg or "Invalid or expired token.")
            logger.logMessage("Token invalid or expired, opening token dialog")
            TokenManager.showTokenDialog()
            return
        end
        print("✅ Token valid")

        -- Retrieve the currently selected photo in Lightroom
        print("🖼️ Retrieving selected photo")
        logger.logMessage("Retrieving selected photo from catalog")
        local catalog = LrApplication.activeCatalog()
        local photo = catalog:getTargetPhoto()
        if not photo then
            print("⚠️ No photo selected")
            logger.logMessage("No photo selected.")
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoPhoto=No photo selected."), 3)
            return
        end

        -- Log the selected photo's filename for debugging
        local filename = photo:getFormattedMetadata("fileName") or "unknown"
        print("📷 Selected photo: " .. filename)
        logger.logMessage("Selected photo: " .. filename)
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/SelectedPhoto=Selected photo: ") .. filename, 2)

        -- Export the selected photo to a temporary JPEG file named "tempo.jpg"
        print("📤 Exporting photo to tempo.jpg")
        logger.logMessage("Exporting selected photo to tempo.jpg")
        local exportedPath, exportErr = export_to_tempo.exportToTempo(photo)
        if not exportedPath then
            print("❌ Export failed: " .. (exportErr or "unknown"))
            logger.logMessage("Failed to export image: " .. (exportErr or "unknown"))
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/ExportFailed=Image export failed."), 3)
            return
        end
        print("✅ Export successful: " .. exportedPath)
        logger.logMessage("Image successfully exported as tempo.jpg")
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Exported=Image exported to tempo.jpg"), 2)

        -- Send the exported photo to iNaturalist API for identification (asynchronous)
        print("🌐 Sending image to iNaturalist API")
        logger.logMessage("Sending image to iNaturalist API for identification")
        callAPI.identifyAsync(exportedPath, token, function(result, apiErr)
            if not result then
                print("❌ API error: " .. (apiErr or "unknown"))
                logger.logMessage("API error: " .. (apiErr or "unknown"))
                LrDialogs.message(
                    LOC("$$$/iNat/Dialog/IdentificationFailed=Identification failed"),
                    apiErr or LOC("$$$/iNat/Dialog/UnknownError=Unknown error.")
                )
                return
            end

            print("📊 Parsing identification results")
            logger.logMessage("Validating identification results")
            local hasTitle = result:match("🕊️")
            local count = 0
            for line in result:gmatch("[^\r\n]+") do
                if line:match("%%") and line:match("%(") and line:match("%)") then
                    count = count + 1
                end
            end

            if hasTitle and count > 0 then
                print("✅ Species identified")
                logger.logMessage("Identification results:\n" .. result)
                LrDialogs.message(LOC("$$$/iNat/Dialog/Results=Identification results:"), result)

                print("🏷️ Prompting user for keyword tagging")
                logger.logMessage("Prompting user for keyword tagging")
                local choix = LrDialogs.confirm(
                    LOC("$$$/iNat/Dialog/AskTag=Do you want to add one or more identifications as keywords?"),
                    LOC("$$$/iNat/Dialog/AskTagDetails=Click 'Continue' to select species."),
                    LOC("$$$/iNat/Dialog/Continue=Continue"),
                    LOC("$$$/iNat/Dialog/Cancel=Cancel")
                )

                if choix == "ok" then
                    print("📝 User accepted tagging")
                    logger.logMessage("User chose to continue with tagging")
                    local selector = require("SelectAndTagResults")
                    selector.showSelection(result)
                else
                    print("🚫 User skipped tagging")
                    logger.logMessage("User skipped tagging.")
                end
            else
                print("⚠️ No identification results")
                logger.logMessage("No identification results.")
                LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoResult=No results found."), 3)
            end

            print("✅ Analysis completed")
            logger.logMessage("Analysis completed.")
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Done=Analysis completed."), 2)
        end)
    end)

    -- Global error catch for unexpected errors
    if not success then
        print("🔥 Unexpected error: " .. tostring(err))
        logger.logMessage("Unexpected error: " .. tostring(err))
        LrDialogs.message(
            LOC("$$$/iNat/Dialog/Error=Unexpected error"),
            tostring(err)
        )
    end
end

--------------------------------------------------------------------------------
-- Auto-execute when this module is called via Lightroom menu
--------------------------------------------------------------------------------
LrTasks.startAsyncTask(function()
    identifyAnimal()
end)

--------------------------------------------------------------------------------
-- Export module interface for external calls if needed
--------------------------------------------------------------------------------
return {
    identify = identifyAnimal
}
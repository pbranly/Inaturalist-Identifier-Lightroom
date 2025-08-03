-- Import required Lightroom modules
local LrTasks = import "LrTasks"
local LrDialogs = import "LrDialogs"
local LrApplication = import "LrApplication"
local LrPrefs = import "LrPrefs"

-- Import custom modules
local logger = require("Logger")
local tokenUpdater = require("TokenUpdater")
local tokenChecker = require("VerificationToken")
local callAPI = require("call_inaturalist")
local export_to_tempo = require("export_to_tempo") -- Externalized export logic
local LOC = LOC

-- Main function to identify the animal in the selected photo
local function identifyAnimal()
    LrTasks.startAsyncTask(function()
        -- Initialize logging and show start message
        logger.initializeLogFile()
        logger.logMessage(LOC("$$$/iNat/Log/Started=Plugin started"))
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Started=Plugin started"), 2)

        -- Get the token from plugin preferences
        local prefs = LrPrefs.prefsForPlugin()
        local token = prefs.token

        -- Validate the token
        if not token or token == "" then
            logger.notify(LOC("$$$/iNat/Error/TokenMissing=Token is missing. Please enter it in Preferences."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        local isValid, msg = tokenChecker.isTokenValid()
        if not isValid then
            logger.notify(LOC("$$$/iNat/Error/TokenInvalid=Invalid or expired token."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- Get the selected photo from Lightroom catalog
        local catalog = LrApplication.activeCatalog()
        local photo = catalog:getTargetPhoto()
        if not photo then
            logger.logMessage(LOC("$$$/iNat/Log/NoPhoto=No photo selected."))
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoPhoto=No photo selected."), 3)
            return
        end

        -- Show selected photo filename
        local filename = photo:getFormattedMetadata("fileName") or "unknown"
        logger.logMessage(LOC("$$$/iNat/Log/SelectedPhoto=Selected photo: ") .. filename)
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/SelectedPhoto=Selected photo: ") .. filename, 2)

        -- Export the photo as tempo.jpg via separate module
        local exportedPath, err = export_to_tempo.exportToTempo(photo)
        if not exportedPath then
            logger.logMessage(LOC("$$$/iNat/Log/ExportFailed=Failed to export image: ") .. (err or "unknown"))
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/ExportFailed=Image export failed."), 3)
            return
        end

        logger.logMessage(LOC("$$$/iNat/Log/Exported=Image exported as tempo.jpg"))
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Exported=Image exported to tempo.jpg"), 2)

        -- Send the exported image to the identification API
        local result, err = callAPI.identify(exportedPath, token)
        if not result then
            logger.logMessage(LOC("$$$/iNat/Log/APIError=API error: ") .. (err or "unknown"))
            LrDialogs.message(
                LOC("$$$/iNat/Dialog/IdentificationFailed=Identification failed"),
                err or LOC("$$$/iNat/Dialog/UnknownError=Unknown error.")
            )
            return
        end

        -- If response includes bird emoji, it's considered valid
        if result:match("🕊️") then
            logger.logMessage(LOC("$$$/iNat/Log/Results=Identification results:\n") .. result)
            LrDialogs.message(LOC("$$$/iNat/Dialog/Results=Identification results:"), result)

            -- Ask the user if they want to apply tags
            local choix = LrDialogs.confirm(
                LOC("$$$/iNat/Dialog/AskTag=Do you want to add one or more identifications as keywords?"),
                LOC("$$$/iNat/Dialog/AskTagDetails=Click 'Continue' to select species."),
                LOC("$$$/iNat/Dialog/Continue=Continue"),
                LOC("$$$/iNat/Dialog/Cancel=Cancel")
            )

            if choix == "ok" then
                local selector = require("SelectAndTagResults")
                selector.showSelection(result)
            else
                logger.logMessage(LOC("$$$/iNat/Log/SkippedTag=User skipped tagging."))
            end
        else
            -- No identification result found
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoResult=No results found."), 3)
            logger.logMessage(LOC("$$$/iNat/Log/NoResult=No identification results."))
        end

        -- Show completion message
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Done=Analysis completed."), 2)
    end)
end

return {
    identify = identifyAnimal
}

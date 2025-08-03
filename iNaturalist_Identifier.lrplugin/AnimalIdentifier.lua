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
local export_to_tempo = require("export_to_tempo")
local LOC = LOC

-- Main function to identify the animal in the selected photo
local function identifyAnimal()
    -- Start an asynchronous task (non-blocking for Lightroom UI)
    LrTasks.startAsyncTask(function()
        -- Initialize the log file
        logger.initializeLogFile()
        logger.logMessage(LOC("$$$/iNat/Log/Started=Plugin started"))
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Started=Plugin started"), 2)

        -- Load plugin preferences and check if the token is present
        local prefs = LrPrefs.prefsForPlugin()
        local token = prefs.token

        if not token or token == "" then
            -- Notify user if token is missing and attempt to update it
            logger.notify(LOC("$$$/iNat/Error/TokenMissing=Token is missing. Please enter it in Preferences."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- Verify token validity
        local isValid, msg = tokenChecker.isTokenValid()
        if not isValid then
            logger.notify(LOC("$$$/iNat/Error/TokenInvalid=Invalid or expired token."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- Get the selected photo from the Lightroom catalog
        local catalog = LrApplication.activeCatalog()
        local photo = catalog:getTargetPhoto()
        if not photo then
            logger.logMessage(LOC("$$$/iNat/Log/NoPhoto=No photo selected."))
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoPhoto=No photo selected."), 3)
            return
        end

        -- Log selected photo filename
        local filename = photo:getFormattedMetadata("fileName") or "unknown"
        logger.logMessage(LOC("$$$/iNat/Log/SelectedPhoto=Selected photo: ") .. filename)
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/SelectedPhoto=Selected photo: ") .. filename, 2)

        -- Export the selected photo to a temporary file
        local exportedPath, err = export_to_tempo.exportToTempo(photo)
        if not exportedPath then
            logger.logMessage(LOC("$$$/iNat/Log/ExportFailed=Failed to export image: ") .. (err or "unknown"))
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/ExportFailed=Image export failed."), 3)
            return
        end

        logger.logMessage(LOC("$$$/iNat/Log/Exported=Image exported as tempo.jpg"))
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Exported=Image exported to tempo.jpg"), 2)

        -- Call iNaturalist API with the exported image
        local result, err = callAPI.identify(exportedPath, token)
        if not result then
            logger.logMessage(LOC("$$$/iNat/Log/APIError=API error: ") .. (err or "unknown"))
            LrDialogs.message(
                LOC("$$$/iNat/Dialog/IdentificationFailed=Identification failed"),
                err or LOC("$$$/iNat/Dialog/UnknownError=Unknown error.")
            )
            return
        end

        -- Check the format of the result: look for at least one line with a percentage (match) and valid characters
        local hasTitle = result:match("🕊️")
        local count = 0
        for line in result:gmatch("[^\r\n]+") do
            if line:match("%%") and line:match("%(") and line:match("%)") then
                count = count + 1
            end
        end

        -- If the result contains species, display them and ask for keyword tagging
        if hasTitle and count > 0 then
            logger.logMessage(LOC("$$$/iNat/Log/Results=Identification results:\n") .. result)
            LrDialogs.message(LOC("$$$/iNat/Dialog/Results=Identification results:"), result)

            local choix = LrDialogs.confirm(
                LOC("$$$/iNat/Dialog/AskTag=Do you want to add one or more identifications as keywords?"),
                LOC("$$$/iNat/Dialog/AskTagDetails=Click 'Continue' to select species."),
                LOC("$$$/iNat/Dialog/Continue=Continue"),
                LOC("$$$/iNat/Dialog/Cancel=Cancel")
            )

            if choix == "ok" then
                -- Open the selection dialog to allow user to choose which species to tag
                local selector = require("SelectAndTagResults")
                selector.showSelection(result)
            else
                logger.logMessage(LOC("$$$/iNat/Log/SkippedTag=User skipped tagging."))
            end
        else
            -- No species recognized or result formatting invalid
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoResult=No results found."), 3)
            logger.logMessage(LOC("$$$/iNat/Log/NoResult=No identification results."))
        end

        -- Final status
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Done=Analysis completed."), 2)
    end)
end

-- Return the main function for external use
return {
    identify = identifyAnimal
}

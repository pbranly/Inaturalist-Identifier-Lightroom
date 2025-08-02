-- Import required Lightroom modules
local LrTasks = import "LrTasks"
local LrDialogs = import "LrDialogs"
local LrApplication = import "LrApplication"
local LrPathUtils = import "LrPathUtils"
local LrFileUtils = import "LrFileUtils"
local LrExportSession = import "LrExportSession"
local LrPrefs = import "LrPrefs"

-- Custom modules
local logger = require("Logger")
local imageUtils = require("ImageUtils")
local tokenUpdater = require("TokenUpdater")
local tokenChecker = require("VerificationToken")
local callAPI = require("call_inaturalist")
local LOC = LOC

-- Main function
local function identifyAnimal()
    LrTasks.startAsyncTask(function()
        logger.initializeLogFile()
        logger.logMessage(LOC("$$$/iNat/Log/Started=Plugin started"))
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Started=Plugin started"), 2)

        local prefs = LrPrefs.prefsForPlugin()
        local token = prefs.token

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

        local catalog = LrApplication.activeCatalog()
        local photo = catalog:getTargetPhoto()
        if not photo then
            logger.logMessage(LOC("$$$/iNat/Log/NoPhoto=No photo selected."))
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoPhoto=No photo selected."), 3)
            return
        end

        local filename = photo:getFormattedMetadata("fileName") or "unknown"
        logger.logMessage(LOC("$$$/iNat/Log/SelectedPhoto=Selected photo: ") .. filename)
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/SelectedPhoto=Selected photo: ") .. filename, 2)

        local pluginFolder = _PLUGIN.path
        imageUtils.clearJPEGs(pluginFolder)

        local exportSettings = {
            LR_export_destinationType = "specificFolder",
            LR_export_destinationPathPrefix = pluginFolder,
            LR_export_useSubfolder = false,
            LR_format = "JPEG",
            LR_jpeg_quality = 0.8,
            LR_size_resizeType = "wh",
            LR_size_maxWidth = 1024,
            LR_size_maxHeight = 1024,
            LR_size_doNotEnlarge = true,
            LR_renamingTokensOn = true,
            LR_renamingTokens = "{{image_name}}",
        }

        local exportSession = LrExportSession({
            photosToExport = { photo },
            exportSettings = exportSettings
        })

        local success = LrTasks.pcall(function()
            exportSession:doExportOnCurrentTask()
        end)

        local exportedPath = imageUtils.findSingleJPEG(pluginFolder)
        if not exportedPath then
            logger.logMessage(LOC("$$$/iNat/Log/ExportFailed=Failed to export image."))
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/ExportFailed=Image export failed."), 3)
            return
        end

        local finalPath = LrPathUtils.child(pluginFolder, "tempo.jpg")
        local ok, err = LrFileUtils.move(exportedPath, finalPath)
        if not ok then
            logger.logMessage(LOC("$$$/iNat/Log/RenameFailed=File rename error: ") .. (err or "unknown"))
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/RenameFailed=Rename failed."), 3)
            return
        end

        logger.logMessage(LOC("$$$/iNat/Log/Exported=Image exported as tempo.jpg"))
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Exported=Image exported to tempo.jpg"), 2)

        local result, err = callAPI.identify(finalPath, token)

        if not result then
            logger.logMessage(LOC("$$$/iNat/Log/APIError=API error: ") .. (err or "unknown"))
            LrDialogs.message(
                LOC("$$$/iNat/Dialog/IdentificationFailed=Identification failed"),
                err or LOC("$$$/iNat/Dialog/UnknownError=Unknown error.")
            )
            return
        end

        if result:match("🕊️") then
            logger.logMessage(LOC("$$$/iNat/Log/Results=Identification results:\n") .. result)
            LrDialogs.message(LOC("$$$/iNat/Dialog/Results=Identification results:"), result)

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
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoResult=No results found."), 3)
            logger.logMessage(LOC("$$$/iNat/Log/NoResult=No identification results."))
        end

        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Done=Analysis completed."), 2)
    end)
end

return {
    identify = identifyAnimal
}

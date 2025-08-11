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
local pythonRunner = require("PythonRunner")
local tokenUpdater = require("TokenUpdater")
local tokenChecker = require("VerificationToken")

-- Main function: exports selected photo, runs Python script, and handles result
local function identifyAnimal()
    LrTasks.startAsyncTask(function()
        -- Initialization
        logger.initializeLogFile()
        logger.logMessage("Plugin started")
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/PluginStarted=Plugin started"), 3)

        -- Retrieve token from preferences
        local prefs = LrPrefs.prefsForPlugin()
        local token = prefs.token

        -- Check if token is missing
        if not token or token == "" then
            logger.notify(LOC("$$$/iNat/Error/MissingToken=Token is missing. Please enter it in Preferences."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- Validate token
        local isValid, msg = tokenChecker.isTokenValid()
        if not isValid then
            logger.notify(LOC("$$$/iNat/Error/InvalidToken=Invalid or expired token."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- Get the selected photo
        local catalog = LrApplication.activeCatalog()
        local photo = catalog:getTargetPhoto()
        if not photo then
            logger.logMessage("No photo selected.")
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoPhoto=No photo selected."), 3)
            return
        end

        -- Display selected photo filename
        local filename = photo:getFormattedMetadata("fileName") or "unknown"
        logger.logMessage("Selected photo: " .. filename)
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/PhotoName=Selected photo: ") .. filename, 3)

        -- Prepare export folder and cleanup
        local pluginFolder = _PLUGIN.path
        imageUtils.clearJPEGs(pluginFolder)
        logger.logMessage("Previous JPEGs deleted.")
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Cleared=Previous image removed."), 3)

        -- Export settings
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

        -- Perform export
        local exportSession = LrExportSession({
            photosToExport = { photo },
            exportSettings = exportSettings
        })

        local success = LrTasks.pcall(function()
            exportSession:doExportOnCurrentTask()
        end)

        -- Check if export succeeded
        local exportedPath = imageUtils.findSingleJPEG(pluginFolder)
        if not exportedPath then
            logger.logMessage("Failed to export temporary image.")
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/ExportFailed=Temporary export failed."), 3)
            return
        end

        -- Rename the exported file to tempo.jpg
        local finalPath = LrPathUtils.child(pluginFolder, "tempo.jpg")
        local ok, err = LrFileUtils.move(exportedPath, finalPath)
        if not ok then
            local msg = string.format("Error renaming file: %s", err or "unknown")
            logger.logMessage(msg)
            LrDialogs.showBezel(msg, 3)
            return
        end

        logger.logMessage("Image exported as tempo.jpg")
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Exported=Image exported to tempo.jpg"), 3)

        -- Run Python identification script
        local result = pythonRunner.runPythonIdentifier(
            LrPathUtils.child(pluginFolder, "identifier_animal.py"),
            finalPath,
            token
        )

        -- Check and display result
        if result:match("🕊️") then
            local titre = LOC("$$$/iNat/Title/Result=Identification results:")
            logger.logMessage(titre .. "\n" .. result)
            LrDialogs.message(titre, result)

            -- Ask user whether to proceed with keyword tagging
            local choix = LrDialogs.confirm(
                LOC("$$$/iNat/Confirm/Ask=Do you want to add one or more identifications as keywords?"),
                LOC("$$$/iNat/Confirm/Hint=Click 'Continue' to select species."),
                LOC("$$$/iNat/Confirm/Continue=Continue"),
                LOC("$$$/iNat/Confirm/Cancel=Cancel")
            )

            if choix == "ok" then
                local selector = require("SelectAndTagResults")
                selector.showSelection(result)
            else
                logger.logMessage("Keyword tagging skipped by user.")
            end
        else
            -- No results from Python script
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/ResultNone=No identification results ❌"), 3)
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoneFound=No results found."), 3)
        end

        logger.logMessage("Analysis completed.")
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/AnalysisDone=Analysis completed."), 3)
    end)
end

return {
    identify = identifyAnimal
}

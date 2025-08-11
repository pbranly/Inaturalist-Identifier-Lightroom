--[[
============================================================
Functional Description
------------------------------------------------------------
This script defines the function `identifyAnimal()` which is 
the core of the animal identification process in Lightroom.
When called (from main.lua), it performs the following actions:

1. Launches a Lightroom asynchronous task.
2. Initializes the log and displays a startup message.
3. Retrieves and checks the access token from preferences.
4. Validates the token via a verification module.
5. Retrieves the selected photo from the Lightroom catalog.
6. Displays and logs the name of the selected photo.
7. Cleans up any temporary JPEGs in the plugin folder.
8. Configures export settings (format, size, quality).
9. Exports the selected photo into the plugin folder.
10. Renames the exported file to `tempo.jpg`.
11. Runs the Python identification script.
12. Displays and logs the identification results.
13. Asks the user if they want to add identifications as keywords.
14. If accepted, launches the selection and tagging module.
15. Displays an end-of-analysis message.

------------------------------------------------------------
Numbered Steps
1. Import the required Lightroom modules.
2. Import the plugin's custom modules.
3. Define the main `identifyAnimal` function.
4. Launch a Lightroom asynchronous task.
5. Initialize the log and show a start message.
6. Retrieve the token from preferences.
7. If the token is missing, run the update script.
8. Validate the token.
9. If invalid, run the update script.
10. Retrieve the selected photo.
11. If no photo, log and stop.
12. Display the selected filename.
13. Delete existing JPEGs in the plugin folder.
14. Define export settings.
15. Perform the export.
16. Check if the export succeeded.
17. Rename the exported file to `tempo.jpg`.
18. Run the Python identification script.
19. Check the Python script result.
20. Display results and ask the user if tagging is desired.
21. If yes, call the selection and tagging module.
22. If no, log that tagging is skipped.
23. If no result, display a "no result" message.
24. Log and notify the end of the process.

------------------------------------------------------------
Called Scripts
- Logger.lua
- ImageUtils.lua
- PythonRunner.lua
- TokenUpdater.lua
- VerificationToken.lua
- SelectAndTagResults.lua
- identifier_animal.py (Python script)

------------------------------------------------------------
Calling Script
- main.lua → called from Lightroom via Info.lua
============================================================
]]

-- [Step 1] Import required Lightroom modules
local LrTasks = import "LrTasks"
local LrDialogs = import "LrDialogs"
local LrApplication = import "LrApplication"
local LrPathUtils = import "LrPathUtils"
local LrFileUtils = import "LrFileUtils"
local LrExportSession = import "LrExportSession"
local LrPrefs = import "LrPrefs"

-- [Step 2] Import plugin custom modules
local logger = require("Logger")
local imageUtils = require("ImageUtils")
local pythonRunner = require("PythonRunner")
local tokenUpdater = require("TokenUpdater")
local tokenChecker = require("VerificationToken")

-- [Step 3] Main function: exports selected photo, runs Python script, and processes result
local function identifyAnimal()
    -- [Step 4] Launch asynchronous Lightroom task
    LrTasks.startAsyncTask(function()
        -- [Step 5] Initialization
        logger.initializeLogFile()
        logger.logMessage("Plugin started")
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/PluginStarted=Plugin started"), 3)

        -- [Step 6] Retrieve token from preferences
        local prefs = LrPrefs.prefsForPlugin()
        local token = prefs.token

        -- [Step 7] Check if token is missing
        if not token or token == "" then
            logger.notify(LOC("$$$/iNat/Error/MissingToken=Token is missing. Please enter it in Preferences."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- [Step 8] Validate token
        local isValid, msg = tokenChecker.isTokenValid()
        -- [Step 9] If token invalid, prompt update
        if not isValid then
            logger.notify(LOC("$$$/iNat/Error/InvalidToken=Invalid or expired token."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- [Step 10] Get the selected photo
        local catalog = LrApplication.activeCatalog()
        local photo = catalog:getTargetPhoto()
        -- [Step 11] Stop if no photo selected
        if not photo then
            logger.logMessage("No photo selected.")
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoPhoto=No photo selected."), 3)
            return
        end

        -- [Step 12] Display selected photo filename
        local filename = photo:getFormattedMetadata("fileName") or "unknown"
        logger.logMessage("Selected photo: " .. filename)
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/PhotoName=Selected photo: ") .. filename, 3)

        -- [Step 13] Prepare export folder and cleanup
        local pluginFolder = _PLUGIN.path
        imageUtils.clearJPEGs(pluginFolder)
        logger.logMessage("Previous JPEGs deleted.")
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Cleared=Previous image removed."), 3)

        -- [Step 14] Define export settings
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

        -- [Step 15] Perform export
        local exportSession = LrExportSession({
            photosToExport = { photo },
            exportSettings = exportSettings
        })

        local success = LrTasks.pcall(function()
            exportSession:doExportOnCurrentTask()
        end)

        -- [Step 16] Check if export succeeded
        local exportedPath = imageUtils.findSingleJPEG(pluginFolder)
        if not exportedPath then
            logger.logMessage("Failed to export temporary image.")
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/ExportFailed=Temporary export failed."), 3)
            return
        end

        -- [Step 17] Rename the exported file to tempo.jpg
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

        -- [Step 18] Run Python identification script
        local result = pythonRunner.runPythonIdentifier(
            LrPathUtils.child(pluginFolder, "identifier_animal.py"),
            finalPath,
            token
        )

        -- [Step 19] Check and display result
        if result:match("🕊️") then
            -- [Step 20] Display results and ask user if tagging is desired
            local title = LOC("$$$/iNat/Title/Result=Identification results:")
            logger.logMessage(title .. "\n" .. result)
            LrDialogs.message(title, result)

            local choice = LrDialogs.confirm(
                LOC("$$$/iNat/Confirm/Ask=Do you want to add one or more identifications as keywords?"),
                LOC("$$$/iNat/Confirm/Hint=Click 'Continue' to select species."),
                LOC("$$$/iNat/Confirm/Continue=Continue"),
                LOC("$$$/iNat/Confirm/Cancel=Cancel")
            )

            -- [Step 21] If yes, run selection and tagging module
            if choice == "ok" then
                local selector = require("SelectAndTagResults")
                selector.showSelection(result)
            else
                -- [Step 22] If no, log skipping
                logger.logMessage("Keyword tagging skipped by user.")
            end
        else
            -- [Step 23] No results from Python script
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/ResultNone=No identification results ❌"), 3)
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoneFound=No results found."), 3)
        end

        -- [Step 24] Final log and notification
        logger.logMessage("Analysis completed.")
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/AnalysisDone=Analysis completed."), 3)
    end)
end

return {
    identify = identifyAnimal
}

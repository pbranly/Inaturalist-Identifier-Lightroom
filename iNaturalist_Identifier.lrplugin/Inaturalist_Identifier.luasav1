--[[
=====================================================================================
Inaturalist_Identifier.lua
-------------------------------------------------------------------------------------
Functional Description
-------------------------------------------------------------------------------------
This module defines the `identify()` function, which orchestrates the process of 
identifying an animal or plant in a Lightroom-selected photo using the iNaturalist API.

When executed (typically from `main.lua`), the workflow is as follows:

1. Launches a Lightroom asynchronous task.
2. Initializes the log and displays a startup notification.
3. Retrieves the stored access token from plugin preferences.
4. Validates the token via the verification module.
5. Retrieves the currently selected photo in the Lightroom catalog.
6. Displays and logs the name of the selected photo.
7. Uses the `export_photo_to_tempo.lua` module to:
   - Delete previous JPEGs in the plugin folder.
   - Export the selected photo as a 1024×1024 JPEG.
   - Save it as `tempo.jpg` in the plugin folder.
8. Runs the identification process via the `call_inaturalist.lua` module.
9. Displays identification results to the user.
10. Asks the user whether to add identifications as Lightroom keywords.
11. If accepted, calls the selection and tagging module.
12. Displays an "analysis completed" message and writes final logs.

-------------------------------------------------------------------------------------
Numbered Steps in Code
-------------------------------------------------------------------------------------
1. Import required Lightroom SDK modules.
2. Import custom plugin modules.
3. Define the main `identify()` function.
4. Launch a Lightroom asynchronous task.
5. Initialize logging and display start notification.
6. Retrieve token from plugin preferences.
7. If token missing, prompt user to update.
8. Validate the token.
9. If invalid, prompt user to update.
10. Get the selected photo from the catalog.
11. If no photo selected, stop and notify.
12. Display the selected photo filename.
13. Export the photo to `tempo.jpg` via `export_photo_to_tempo.lua`.
14. If export fails, log and stop.
15. Call `call_inaturalist.lua` to identify the image.
16. If identification successful, display results and ask about tagging.
17. If user accepts, call `SelectAndTagResults.lua`.
18. If no results, display "no identification found".
19. Log and notify that analysis is complete.

-------------------------------------------------------------------------------------
Called Scripts
-------------------------------------------------------------------------------------
- Logger.lua              → Logging events and messages.
- export_photo_to_tempo.lua → Handles photo cleanup and export to `tempo.jpg`.
- call_inaturalist.lua    → Sends the photo to the iNaturalist API and returns results.
- TokenUpdater.lua        → Prompts the user to update their iNaturalist token.
- VerificationToken.lua   → Checks if the stored token is valid.
- SelectAndTagResults.lua → Lets the user select identifications and add them as keywords.

-------------------------------------------------------------------------------------
Calling Script
-------------------------------------------------------------------------------------
- main.lua → executed by Lightroom through Info.lua configuration.

-------------------------------------------------------------------------------------
Module Usage
-------------------------------------------------------------------------------------
local identifier = require("Inaturalist_Identifier")
identifier.identify()
=====================================================================================
]]

-- [Step 1] Import required Lightroom modules
local LrTasks       = import "LrTasks"
local LrDialogs     = import "LrDialogs"
local LrApplication = import "LrApplication"
local LrPrefs       = import "LrPrefs"

-- [Step 2] Import plugin custom modules
local logger           = require("Logger")
local callInaturalist  = require("call_inaturalist")
local tokenUpdater     = require("TokenUpdater")
local tokenChecker     = require("VerificationToken")
local exportToTempoMod = require("export_photo_to_tempo")

-- [Step 3] Main function: exports selected photo, runs identification, and processes result
local function identify()
    -- [Step 4] Launch asynchronous Lightroom task
    LrTasks.startAsyncTask(function()
        -- [Step 5] Initialization
        logger.initializeLogFile()
        logger.logMessage("Plugin started")
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/PluginStarted=Plugin started"), 3)

        -- [Step 6] Retrieve token from preferences
        local prefs = LrPrefs.prefsForPlugin()
        local token = prefs.token

        -- [Step 7] If token missing, prompt update
        if not token or token == "" then
            logger.notify(LOC("$$$/iNat/Error/MissingToken=Token is missing. Please enter it in Preferences."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- [Step 8] Validate token
        local isValid = tokenChecker.isTokenValid()
        -- [Step 9] If invalid, prompt update
        if not isValid then
            logger.notify(LOC("$$$/iNat/Error/InvalidToken=Invalid or expired token."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- [Step 10] Get the selected photo
        local catalog = LrApplication.activeCatalog()
        local photo   = catalog:getTargetPhoto()

        -- [Step 11] If no photo selected
        if not photo then
            logger.logMessage("No photo selected.")
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoPhoto=No photo selected."), 3)
            return
        end

        -- [Step 12] Display selected photo filename
        local filename = photo:getFormattedMetadata("fileName") or "unknown"
        logger.logMessage("Selected photo: " .. filename)
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/PhotoName=Selected photo: ") .. filename, 3)

        -- [Step 13] Export to tempo.jpg using export_photo_to_tempo.lua
        local tempoPath, err = exportToTempoMod.exportToTempo(photo)
        -- [Step 14] If export fails
        if not tempoPath then
            logger.logMessage("Export failed: " .. (err or "unknown error"))
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/ExportFailed=Temporary export failed."), 3)
            return
        end

        logger.logMessage("Image exported to " .. tempoPath)
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Exported=Image exported to tempo.jpg"), 3)

        -- [Step 15] Run identification script
        callInaturalist.identifyAsync(tempoPath, token, function(result, err)
            if err then
                logger.logMessage("Identification error: " .. err)
                LrDialogs.message(LOC("$$$/iNat/Title/Error=Error during identification"), err)
                return
            end

            -- [Step 16] If identification result is found
            if result:match("🕊️") then
                local title = LOC("$$$/iNat/Title/Result=Identification results:")
                logger.logMessage(title .. "\n" .. result)
                LrDialogs.message(title, result)

                local choice = LrDialogs.confirm(
                    LOC("$$$/iNat/Confirm/Ask=Do you want to add one or more identifications as keywords?"),
                    LOC("$$$/iNat/Confirm/Hint=Click 'Continue' to select species."),
                    LOC("$$$/iNat/Confirm/Continue=Continue"),
                    LOC("$$$/iNat/Confirm/Cancel=Cancel")
                )

                -- [Step 17] If user accepts tagging
                if choice == "ok" then
                    local selector = require("SelectAndTagResults")
                    selector.showSelection(result)
                else
                    logger.logMessage("Keyword tagging skipped by user.")
                end
            else
                -- [Step 18] No results from identification
                LrDialogs.showBezel(LOC("$$$/iNat/Bezel/ResultNone=No identification results ❌"), 3)
                LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoneFound=No results found."), 3)
            end

            -- [Step 19] Final log and notification
            logger.logMessage("Analysis completed.")
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/AnalysisDone=Analysis completed."), 3)
        end) -- end of identifyAsync callback
    end) -- end of LrTasks.startAsyncTask
end -- end of identify function

-- Function Lightroom calls at export start (optional)
local function processRenderedPhotos(functionContext, exportContext)
    identify()
end

return {
    processRenderedPhotos = processRenderedPhotos,
    identify = identify,
}

--[[
=====================================================================================
Inaturalist_Identifier.lua (Modified version)
-------------------------------------------------------------------------------------
Functional Description
-------------------------------------------------------------------------------------
This updated version changes the original workflow as follows:

- Removes the step that displays identification results to the user.
- Automatically calls the "Select and Tag" module if at least one species is recognized.
- If no species is recognized, displays a modal message "There are no recognized species" 
  with an "OK" button before exiting.
- Keeps 3-second bezel displays for main progress steps.
- Logs all major events to log.txt in English (not localized).
- All on-screen UI messages are internationalized using LOC().

-------------------------------------------------------------------------------------
Numbered Workflow Steps
-------------------------------------------------------------------------------------
1. Launch a Lightroom asynchronous task to avoid blocking the UI.
2. Initialize the log file and display a startup bezel message for 3 seconds.
3. Retrieve the stored access token from plugin preferences.
4. If token is missing, log the issue, notify the user, and run the token update module.
5. Validate the token using TokenUpdater.lua based on timestamp.
6. If token is invalid or expired, log the issue, notify the user, and run the token update module.
7. Retrieve the currently selected photo in the Lightroom catalog.
8. If no photo is selected, log the issue, display a bezel for 3 seconds, and exit.
9. Log and display the name of the selected photo for 3 seconds.
10. Export the photo to tempo.jpg (1024×1024 JPEG) using export_photo_to_tempo.lua.
11. If export fails, log the error, display a bezel for 3 seconds, and exit.
12. Log successful export and display a bezel for 3 seconds.
13. Call the call_inaturalist.lua module to identify the image.
14. If an error occurs during identification, log the error, display a modal message, and exit.
15. If at least one species is recognized, log the fact and directly call the SelectAndTagResults module.
16. If no species is recognized, log the fact and display a modal "No recognized species" message with an OK button.
17. Log "Analysis completed" and display a completion bezel for 3 seconds.

-------------------------------------------------------------------------------------
Called Modules
-------------------------------------------------------------------------------------
- Logger.lua               → Handles logging of events and errors.
- export_photo_to_tempo.lua→ Exports the selected photo to a temporary file.
- call_inaturalist.lua     → Sends the exported image to iNaturalist API for identification.
- TokenUpdater.lua         → Guides the user to enter or update their iNaturalist token.
- SelectAndTagResults.lua  → Allows the user to select and tag recognized species.

=====================================================================================
]]

-- [Step 1] Import Lightroom SDK modules
local LrTasks       = import "LrTasks"
local LrDialogs     = import "LrDialogs"
local LrApplication = import "LrApplication"
local LrPrefs       = import "LrPrefs"

-- [Step 2] Import custom plugin modules
local logger           = require("Logger")
local callInaturalist  = require("call_inaturalist")
local tokenUpdater     = require("TokenUpdater")  -- central token management
local exportToTempoMod = require("export_photo_to_tempo")

-- [Step 3] Main function definition
local function identify()
    -- [Step 4] Run inside an asynchronous Lightroom task
    LrTasks.startAsyncTask(function()
        
        -- [Step 5] Initialize logging and show startup bezel
        logger.initializeLogFile()
        logger.logMessage("Plugin started")
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/PluginStarted=Plugin started"), 3)

        -- [Step 6] Retrieve token from plugin preferences
        local prefs = LrPrefs.prefsForPlugin()
        local token = prefs.token
        local tokenTimestamp = prefs.tokenTimestamp or 0
        local currentTime = os.time()

        -- [Step 7] If token missing, notify and update
        if not token or token == "" then
            logger.logMessage("Missing token. Prompting user to update.")
            logger.notify(LOC("$$$/iNat/Error/MissingToken=Token is missing. Please enter it in Preferences."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- [Step 8] Validate token based on timestamp (max 24h)
        if (currentTime - tokenTimestamp) > (24*60*60) then
            logger.logMessage("Token expired (older than 24h). Prompting user to update.")
            logger.notify(LOC("$$$/iNat/Error/ExpiredToken=Token is expired. Please update it."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- [Step 9] Get the selected photo from Lightroom
        local catalog = LrApplication.activeCatalog()
        local photo   = catalog:getTargetPhoto()

        -- [Step 10] If no photo selected, notify and exit
        if not photo then
            logger.logMessage("No photo selected.")
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoPhoto=No photo selected."), 3)
            return
        end

        -- [Step 11] Log and show the selected photo filename
        local filename = photo:getFormattedMetadata("fileName") or "unknown"
        logger.logMessage("Selected photo: " .. filename)
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/PhotoName=Selected photo: ") .. filename, 3)

        -- [Step 12] Export to tempo.jpg
        local tempoPath, err = exportToTempoMod.exportToTempo(photo)
        if not tempoPath then
            logger.logMessage("Export failed: " .. (err or "unknown error"))
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/ExportFailed=Temporary export failed."), 3)
            return
        end
        logger.logMessage("Image exported to " .. tempoPath)
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Exported=Image exported to tempo.jpg"), 3)

        -- [Step 13] Call identification
        callInaturalist.identifyAsync(tempoPath, token, function(result, err)
            -- [Step 14] Handle identification errors
            if err then
                logger.logMessage("Identification error: " .. err)
                LrDialogs.message(
                    LOC("$$$/iNat/Title/Error=Error during identification"), 
                    err
                )
                return
            end

            -- [Step 15] If at least one species recognized → go directly to selection/tagging
            if result:match("🕊️") then
                logger.logMessage("Species recognized. Launching selection and tagging module.")
                local selector = require("SelectAndTagResults")
                selector.showSelection(result)
            else
                -- [Step 16] No species recognized
                logger.logMessage("No recognized species.")
                LrDialogs.message(
                    LOC("$$$/iNat/Title/NoSpecies=No recognized species"),
                    LOC("$$$/iNat/Message/NoSpecies=There are no recognized species"),
                    "ok"
                )
            end

            -- [Step 17] Final log and completion bezel
            logger.logMessage("Analysis completed.")
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/AnalysisDone=Analysis completed."), 3)
        end)
    end)
end

-- Optional Lightroom export hook
local function processRenderedPhotos(functionContext, exportContext)
    identify()
end

return {
    processRenderedPhotos = processRenderedPhotos,
    identify = identify,
}

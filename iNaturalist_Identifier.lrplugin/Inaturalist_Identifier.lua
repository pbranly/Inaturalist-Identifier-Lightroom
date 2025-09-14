--[[
=====================================================================================
Inaturalist_Identifier.lua (Sequential Multi-photo Version with Detailed Logging)
-------------------------------------------------------------------------------------
Functional Description:
This plugin identifies species from selected photos in Adobe Lightroom using the 
iNaturalist API. It processes photos sequentially to avoid concurrency issues, 
exports temporary images for API submission, checks and updates access tokens, 
and allows the user to select and tag recognized species. All key events, API 
requests, and responses are logged in English. UI messages are internationalized 
using LOC() and appear in English by default.

MODIFICATION: Ajout du forçage de l'affichage de la photo en cours de traitement
pour résoudre le problème d'image fixe en multi-sélection.

Modules/Scripts Used:
- Logger.lua              → Handles detailed logging of all events, errors, and API activity
- call_inaturalist.lua    → Sends images to iNaturalist API for species identification
- export_photo_to_tempo.lua → Exports Lightroom photos to a temporary JPEG file
- TokenUpdater.lua        → Prompts user to enter/update iNaturalist token
- VerificationToken.lua   → Validates existing token
- SelectAndTagResults.lua → Allows user to select/tag recognized species

Scripts that use this script:
- Optional Lightroom export hooks: processRenderedPhotos
- Can also be called directly via identify()

=====================================================================================
Numbered Workflow Steps:
-------------------------------------------------------------------------------------
1. Launch asynchronous Lightroom task to avoid UI blocking.
2. Initialize log file and display startup bezel for 3 seconds.
3. Retrieve stored iNaturalist token from plugin preferences.
4. If token is missing, log, notify user, and run TokenUpdater.
5. Validate the token using VerificationToken module.
6. If token invalid, log, notify user, and run TokenUpdater.
7. Retrieve selected photos from Lightroom catalog.
8. If no photo selected, log and display a 3-second bezel, then exit.
9. Process each photo sequentially:
    9.1. Log photo filename and show bezel message.
    9.2. Export photo to tempo.jpg using export_photo_to_tempo.lua.
    9.3. If export fails, log error, show bezel, and continue to next photo.
    9.4. Log exported file path.
    9.5. Call call_inaturalist.identifyAsync() with the temporary file.
    9.6. Log API request sent and response received.
    9.7. If species recognized, log and launch SelectAndTagResults module.
    9.8. If no species recognized, log and display modal message.
    9.9. Log analysis completion for current photo and show 3-second bezel.
10. After all photos processed, log completion and show final bezel.

=====================================================================================
]]

-- Step 1: Import Lightroom SDK modules
local LrTasks       = import "LrTasks"
local LrDialogs     = import "LrDialogs"
local LrApplication = import "LrApplication"
local LrPrefs       = import "LrPrefs"

-- Step 2: Import custom plugin modules
local logger           = require("Logger")
local callInaturalist  = require("call_inaturalist")
local tokenUpdater     = require("TokenUpdater")
local tokenChecker     = require("VerificationToken")
local exportToTempoMod = require("export_photo_to_tempo")
local selectorModule   = require("SelectAndTagResults") -- imported early for clarity

-- Step 3: Main identify function
local function identify()
    LrTasks.startAsyncTask(function()
        -- Step 2: Initialize logging and show startup bezel
        logger.initializeLogFile()
        logger.logMessage("[Step 2] Plugin started.")
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/PluginStarted=Plugin started"), 3)

        -- Step 3: Retrieve stored token
        local prefs = LrPrefs.prefsForPlugin()
        local token = prefs.token
        logger.logMessage("[Step 3] Retrieved token: " .. (token or "<missing>"))

        -- Step 4: Token missing
        if not token or token == "" then
            logger.logMessage("[Step 4] Missing token. Prompting user to update.")
            logger.notify("Token is missing. Please enter it in Preferences.")
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- Step 5: Validate token
        local valid = tokenChecker.isTokenValid()
        logger.logMessage("[Step 5] Token validation result: " .. tostring(valid))
        if not valid then
            -- Step 6: Token invalid
            logger.logMessage("[Step 6] Invalid or expired token. Prompting user to update.")
            logger.notify("Invalid or expired token.")
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- Step 7: Retrieve selected photos
        local catalog = LrApplication.activeCatalog()
        local photos  = catalog:getTargetPhotos()
        logger.logMessage("[Step 7] Number of selected photos: " .. (#photos or 0))

        -- Step 8: No photos selected
        if not photos or #photos == 0 then
            logger.logMessage("[Step 8] No photos selected. Exiting.")
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoPhoto=No photo selected."), 3)
            return
        end

        -- Step 9: Sequential processing of photos
        local function processNextPhoto(index)
            if index > #photos then
                logger.logMessage("[Step 10] All photos processed.")
                LrDialogs.showBezel(LOC("$$$/iNat/Bezel/AllDone=All photos processed."), 3)
                return
            end

            local photo = photos[index]
            local filename = photo:getFormattedMetadata("fileName") or ("photo_" .. index)
            logger.logMessage("[Step 9.1] Processing photo " .. index .. "/" .. #photos .. ": " .. filename)
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/PhotoName=Selected photo: ") .. filename, 3)

            -- Step 9.2: Export photo
            local tempoPath, err = exportToTempoMod.exportToTempo(photo)
            if not tempoPath then
                -- Step 9.3: Export failed
                logger.logMessage("[Step 9.3] Export failed for " .. filename .. ": " .. (err or "unknown error"))
                LrDialogs.showBezel(LOC("$$$/iNat/Bezel/ExportFailed=Temporary export failed."), 3)
                processNextPhoto(index + 1)
                return
            end

            -- Step 9.4: Log exported path
            logger.logMessage("[Step 9.4] Image exported to: " .. tempoPath)
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Exported=Image exported to tempo.jpg"), 3)

            -- Step 9.5 & 9.6: Call iNaturalist API and log request/response
            logger.logMessage("[Step 9.5] Sending identification request for " .. filename .. " to iNaturalist API")
            callInaturalist.identifyAsync(tempoPath, token, function(result, err, httpDetails)
                if httpDetails then
                    logger.logMessage("[Step 9.6] HTTP request: " .. (httpDetails.request or "<unknown>"))
                    logger.logMessage("[Step 9.6] HTTP response: " .. (httpDetails.response or "<unknown>"))
                end

                if err then
                    logger.logMessage("[Step 9.6] Identification error for " .. filename .. ": " .. err)
                    LrDialogs.message(LOC("$$$/iNat/Title/Error=Error during identification"), err)
                    processNextPhoto(index + 1)
                    return
                end

                -- Step 9.7 & 9.8: Handle recognized or unrecognized species
                if result:match("🕊️") then
                    logger.logMessage("[Step 9.7] Species recognized for " .. filename .. ". Launching selection/tagging module.")
                    
                    -- 🔑 MODIFICATION : Forcer l'affichage de cette photo spécifique
                    catalog:withWriteAccessDo("Set active photo", function()
                        catalog:setSelectedPhotos(photo, {photo})
                        logger.logMessage("[Step 9.7] Photo " .. filename .. " set as active photo in Lightroom.")
                    end)
                    
                    -- Petit délai pour laisser l'interface se mettre à jour
                    LrTasks.sleep(0.5)
                    
                    -- Lancer le module de sélection avec la photo ciblée
                    selectorModule.showSelection(result, photo)
                else
                    logger.logMessage("[Step 9.8] No recognized species for " .. filename)
                    LrDialogs.message(
                        LOC("$$$/iNat/Title/NoSpecies=No recognized species"),
                        LOC("$$$/iNat/Message/NoSpecies=There are no recognized species"),
                        "ok"
                    )
                end

                -- Step 9.9: Log analysis completion
                logger.logMessage("[Step 9.9] Analysis completed for " .. filename)
                LrDialogs.showBezel(LOC("$$$/iNat/Bezel/AnalysisDone=Analysis completed."), 3)

                -- Continue with next photo
                processNextPhoto(index + 1)
            end)
        end

        -- Start sequential processing from first photo
        processNextPhoto(1)
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

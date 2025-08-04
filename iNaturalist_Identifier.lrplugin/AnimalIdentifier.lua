--[[
=====================================================================================
 Script : identify.lua
 Purpose : Main logic for identifying species in a selected photo using iNaturalist API
 Author  : Philippe (or your name here)
 Description :
 This script serves as the main entry point for the iNaturalist Lightroom plugin.
 It performs the following steps:
   1. Loads and verifies the user’s iNaturalist API token.
   2. Exports the currently selected photo in Lightroom as a temporary JPEG.
   3. Sends the exported image to the iNaturalist API for species identification.
   4. Parses and validates the results.
   5. Optionally allows the user to add identified species as keywords to the photo.

 The script uses asynchronous execution to keep Lightroom responsive, and handles error
 cases gracefully (e.g., no token, export failure, no photo selected, API error, etc.).

 Dependencies:
 - Logger.lua: For logging to a text file and Lightroom's console.
 - TokenUpdater.lua: UI for prompting token entry.
 - VerificationToken.lua: Token validation logic.
 - call_inaturalist.lua: API call wrapper.
 - export_to_tempo.lua: Photo exporter to temporary location.
 - SelectAndTagResults.lua: Displays identification results and lets user tag photo.

=====================================================================================
--]]

-- Lightroom SDK modules
local LrTasks        = import "LrTasks"         -- Allows asynchronous/background execution
local LrDialogs      = import "LrDialogs"       -- For showing dialogs and bezeled notifications
local LrApplication  = import "LrApplication"   -- Access Lightroom catalog and photo selection
local LrPrefs        = import "LrPrefs"         -- For storing user preferences (e.g., token)

-- Custom plugin modules
local logger          = require("Logger")            -- Logs actions and errors
local tokenUpdater    = require("TokenUpdater")      -- UI/dialog for updating the token
local tokenChecker    = require("VerificationToken") -- Validates token format or expiry
local callAPI         = require("call_inaturalist")  -- Sends photo to iNaturalist for identification
local export_to_tempo = require("export_to_tempo")   -- Exports selected photo to tempo.jpg
local LOC             = LOC                          -- Localization utility (Lightroom's i18n)

-- Main function: identifies the animal in the selected Lightroom photo
local function identifyAnimal()
    -- Run the entire process as a background task to avoid freezing the UI
    LrTasks.startAsyncTask(function()

        -- Log plugin start and show a small notification in Lightroom
        logger.initializeLogFile()
        logger.logMessage(LOC("$$$/iNat/Log/Started=Plugin started"))
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Started=Plugin started"), 2)

        -- Load stored token from plugin preferences
        local prefs = LrPrefs.prefsForPlugin()
        local token = prefs.token

        -- If no token is found, prompt the user to set it up
        if not token or token == "" then
            logger.notify(LOC("$$$/iNat/Error/TokenMissing=Token is missing. Please enter it in Preferences."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- Check if the token is still valid (e.g., not expired)
        local isValid, msg = tokenChecker.isTokenValid()
        if not isValid then
            logger.notify(LOC("$$$/iNat/Error/TokenInvalid=Invalid or expired token."))
            tokenUpdater.runUpdateTokenScript()
            return
        end

        -- Get the currently selected photo in Lightroom
        local catalog = LrApplication.activeCatalog()
        local photo = catalog:getTargetPhoto()
        if not photo then
            logger.logMessage(LOC("$$$/iNat/Log/NoPhoto=No photo selected."))
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoPhoto=No photo selected."), 3)
            return
        end

        -- Log selected filename
        local filename = photo:getFormattedMetadata("fileName") or "unknown"
        logger.logMessage(LOC("$$$/iNat/Log/SelectedPhoto=Selected photo: ") .. filename)
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/SelectedPhoto=Selected photo: ") .. filename, 2)

        -- Export photo to tempo.jpg (temporary location)
        local exportedPath, err = export_to_tempo.exportToTempo(photo)
        if not exportedPath then
            logger.logMessage(LOC("$$$/iNat/Log/ExportFailed=Failed to export image: ") .. (err or "unknown"))
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/ExportFailed=Image export failed."), 3)
            return
        end

        logger.logMessage(LOC("$$$/iNat/Log/Exported=Image exported as tempo.jpg"))
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Exported=Image exported to tempo.jpg"), 2)

        -- Send the image to iNaturalist for species recognition
        local result, err = callAPI.identify(exportedPath, token)
        if not result then
            logger.logMessage(LOC("$$$/iNat/Log/APIError=API error: ") .. (err or "unknown"))
            LrDialogs.message(
                LOC("$$$/iNat/Dialog/IdentificationFailed=Identification failed"),
                err or LOC("$$$/iNat/Dialog/UnknownError=Unknown error.")
            )
            return
        end

        -- Basic result format validation
        local hasTitle = result:match("🕊️") -- Look for bird emoji in the title
        local count = 0
        for line in result:gmatch("[^\r\n]+") do
            if line:match("%%") and line:match("%(") and line:match("%)") then
                count = count + 1 -- Count lines with percentage and parentheses
            end
        end

        -- If results look valid, prompt user to choose tags
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
                -- Show a selection dialog for tagging keywords
                local selector = require("SelectAndTagResults")
                selector.showSelection(result)
            else
                logger.logMessage(LOC("$$$/iNat/Log/SkippedTag=User skipped tagging."))
            end
        else
            -- If result is empty or unrecognized
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoResult=No results found."), 3)
            logger.logMessage(LOC("$$$/iNat/Log/NoResult=No identification results."))
        end

        -- End of process notification
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Done=Analysis completed."), 2)
    end)
end

-- Return the function in a module table so it can be called elsewhere
return {
    identify = identifyAnimal
}
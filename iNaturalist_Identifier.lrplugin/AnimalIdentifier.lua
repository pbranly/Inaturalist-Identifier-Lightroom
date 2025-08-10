--[[
=====================================================================================
 Script   : AnimalIdentifier.lua
 Purpose  : Identify species in a selected Lightroom photo using iNaturalist API
 Author   : Philippe

 Description:
 ------------
 This script is the main engine of the Lightroom plugin. It:
   1. Ensures the iNaturalist API token is valid (via TokenManager)
   2. Exports the selected photo as a temporary JPEG
   3. Sends the image to iNaturalist for identification
   4. Parses results and displays them
   5. Optionally adds identified species as keywords

 Dependencies:
 - Logger.lua             : For logging
 - TokenManager.lua       : Handles token retrieval/validation
 - call_inaturalist.lua   : API communication with iNaturalist
 - export_to_tempo.lua    : Photo export to temporary file
 - SelectAndTagResults.lua: UI for selecting species as keywords
=====================================================================================
--]]

-- Lightroom SDK modules
local LrTasks       = import "LrTasks"
local LrDialogs     = import "LrDialogs"
local LrApplication = import "LrApplication"

-- Custom plugin modules
local logger          = require("Logger")
local TokenManager    = require("TokenManager")
local callAPI         = require("call_inaturalist")
local export_to_tempo = require("export_to_tempo")

--------------------------------------------------------------------------------
-- Main function: identifyAnimal
--------------------------------------------------------------------------------
local function identifyAnimal()
    LrTasks.startAsyncTask(function()
        logger.initializeLogFile()
        logger.logMessage(LOC("$$$/iNat/Log/Started=Plugin started"))
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Started=Plugin started"), 2)

        -- Step 1: Ensure token is valid
        local token = TokenManager.ensureValidToken()
        if not token then
            logger.logMessage(LOC("$$$/iNat/Log/TokenMissing=No valid token provided."))
            return
        end

        -- Step 2: Get selected photo
        local catalog = LrApplication.activeCatalog()
        local photo = catalog:getTargetPhoto()
        if not photo then
            logger.logMessage(LOC("$$$/iNat/Log/NoPhoto=No photo selected."))
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoPhoto=No photo selected."), 3)
            return
        end

        -- Step 3: Export photo to temporary JPEG
        local exportedPath, err = export_to_tempo.exportToTempo(photo)
        if not exportedPath then
            logger.logMessage(LOC("$$$/iNat/Log/ExportFailed=Failed to export image: ") .. (err or "unknown"))
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/ExportFailed=Image export failed."), 3)
            return
        end

        logger.logMessage(LOC("$$$/iNat/Log/Exported=Image exported as tempo.jpg"))
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Exported=Image exported to tempo.jpg"), 2)

        -- Step 4: Call iNaturalist API
        local result, apiErr = callAPI.identify(exportedPath, token)
        if not result then
            logger.logMessage(LOC("$$$/iNat/Log/APIError=API error: ") .. (apiErr or "unknown"))
            LrDialogs.message(
                LOC("$$$/iNat/Dialog/IdentificationFailed=Identification failed"),
                apiErr or LOC("$$$/iNat/Dialog/UnknownError=Unknown error.")
            )
            return
        end

        -- Step 5: Basic result check
        local hasTitle = result:match("🕊️")
        local count = 0
        for line in result:gmatch("[^\r\n]+") do
            if line:match("%%") and line:match("%(") and line:match("%)") then
                count = count + 1
            end
        end

        -- Step 6: Show results & optional tagging
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
                local selector = require("SelectAndTagResults")
                selector.showSelection(result)
            else
                logger.logMessage(LOC("$$$/iNat/Log/SkippedTag=User skipped tagging."))
            end
        else
            LrDialogs.showBezel(LOC("$$$/iNat/Bezel/NoResult=No results found."), 3)
            logger.logMessage(LOC("$$$/iNat/Log/NoResult=No identification results."))
        end

        -- Step 7: Done
        LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Done=Analysis completed."), 2)
    end)
end

--------------------------------------------------------------------------------
-- Exported function
--------------------------------------------------------------------------------
return {
    identify = identifyAnimal
}

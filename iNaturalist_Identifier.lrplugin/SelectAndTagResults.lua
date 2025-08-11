--[[
============================================================
Functional Description
------------------------------------------------------------
This module `selectAndTagResults.lua` parses a text string 
resulting from animal identification (iNaturalist results), 
extracts the list of recognized species, then displays a 
Lightroom UI allowing the user to select which species to add 
as keywords to the active photo.

Main features:
1. Identify the selected photo in the Lightroom catalog.
2. Parse the results string to extract each detected species 
   with its French name, Latin name, and confidence percentage.
3. Display a modal dialog listing these species as checkboxes.
4. Allow the user to select species to add as Lightroom keywords.
5. Create keywords if they don't exist, then add them to the photo.
6. Log the various steps and show error or success messages.

------------------------------------------------------------
Numbered Steps
1. Import required Lightroom modules and the logger.
2. Define the function `showSelection` which:
    2.1. Retrieves the active photo from the catalog.
    2.2. Checks if a photo is selected, else logs and quits.
    2.3. Finds the recognized animals section in the results string.
    2.4. Extracts species with French name, Latin name, and confidence.
    2.5. Checks if any species were detected, else logs and quits.
    2.6. Creates a modal interface with checkboxes for each species.
    2.7. On user confirmation, collects selected species.
    2.8. If none selected, warns the user and exits.
    2.9. Adds the keywords to the photo (creating if necessary).
    2.10. Logs the addition and shows a success message.
    2.11. Logs if the dialog was cancelled.
3. Export the function for external use.

------------------------------------------------------------
Called Scripts
- Logger.lua (for logging)
- Lightroom SDK (for UI, catalog and keyword management)

------------------------------------------------------------
Calling Script
- AnimalIdentifier.lua (after identification, to propose keywords)
============================================================
]]

-- [Step 1] Import Lightroom SDK modules
local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrBinding = import "LrBinding"
local LrView = import "LrView"
local LrApplication = import "LrApplication"

-- [Step 1] Import logger
local logger = require("Logger")

-- [Step 2] Main function: show species selection dialog
local function showSelection(resultsString)
    -- [2.1] Get the active photo
    local catalog = LrApplication.activeCatalog()
    local photo = catalog:getTargetPhoto()
    
    -- [2.2] Check if photo is selected
    if not photo then
        logger.logMessage(LOC("$$$/iNat/NoPhotoSelected=No photo selected."))
        return
    end

    -- [2.3] Find the recognized animals section in the results
    local startIndex = resultsString:find("🕊️%s*Animaux reconnus%s*:") or resultsString:find("🕊️%s*Recognized animals%s*:")
    if not startIndex then
        logger.logMessage(LOC("$$$/iNat/UnknownFormat=Unrecognized result format."))
        return
    end

    -- [2.4] Extract species info (French name, Latin name, confidence %)
    local subResult = resultsString:sub(startIndex)
    local parsedItems = {}

    for line in subResult:gmatch("[^\r\n]+") do
        local nom_fr, nom_latin, pourcent = line:match("%- (.-) %((.-)%)%s*:%s*([%d%.]+)%%")
        if nom_fr and nom_latin and pourcent then
            local label = string.format("%s (%s) — %s%%", nom_fr, nom_latin, pourcent)
            local keyword = string.format("%s (%s)", nom_fr, nom_latin)
            table.insert(parsedItems, { label = label, keyword = keyword })
        end
    end

    -- [2.5] Check at least one species detected
    if #parsedItems == 0 then
        logger.logMessage(LOC("$$$/iNat/NoSpeciesDetected=No species detected."))
        return
    end

    -- [2.6] Create modal UI with checkboxes for each species
    LrFunctionContext.callWithContext("showSelection", function(context)
        local f = LrView.osFactory()
        local props = LrBinding.makePropertyTable(context)
        local checkboxes = {}

        for i, item in ipairs(parsedItems) do
            local key = "item_" .. i
            props[key] = false
            table.insert(checkboxes, f:checkbox {
                title = item.label,
                value = LrView.bind(key)
            })
        end

        local contents = f:scrolled_view {
            width = 500,
            height = 300,
            bind_to_object = props,
            f:column(checkboxes)
        }

        -- [2.7] Show dialog and wait for user response
        local result = LrDialogs.presentModalDialog {
            title = LOC("$$$/iNat/DialogTitle=Select species to add as keywords"),
            contents = contents,
            actionVerb = LOC("$$$/iNat/AddKeywords=Add")
        }

        -- [2.8] If user confirmed, gather selected keywords
        if result == "ok" then
            local selectedKeywords = {}

            for i, item in ipairs(parsedItems) do
                local key = "item_" .. i
                if props[key] == true then
                    table.insert(selectedKeywords, item.keyword)
                end
            end

            -- [2.9] If none selected, inform and quit
            if #selectedKeywords == 0 then
                logger.logMessage(LOC("$$$/iNat/NoKeywordsSelected=No keywords selected."))
                LrDialogs.message(
                    LOC("$$$/iNat/NoSpeciesCheckedTitle=No species selected"),
                    LOC("$$$/iNat/NoKeywordsMessage=No keywords will be added.")
                )
                return
            end

            -- [2.10] Add selected keywords to the photo (create if needed)
            catalog:withWriteAccessDo(LOC("$$$/iNat/AddKeywordsWriteAccess=Adding keywords"), function()
                local function getOrCreateKeyword(name)
                    for _, kw in ipairs(catalog:getKeywords()) do
                        if kw:getName() == name then
                            return kw
                        end
                    end
                    return catalog:createKeyword(name, {}, true, nil, true)
                end

                for _, keyword in ipairs(selectedKeywords) do
                    local kw = getOrCreateKeyword(keyword)
                    if kw then
                        photo:addKeyword(kw)
                    end
                end
            end)

            logger.logMessage(LOC("$$$/iNat/KeywordsAdded=Keywords added: ") .. table.concat(selectedKeywords, ", "))
            LrDialogs.message(
                LOC("$$$/iNat/SuccessTitle=Success"),
                LOC("$$$/iNat/SuccessMessage=Selected keywords have been successfully added.")
            )
        else
            -- [2.11] Log user cancelled dialog
            logger.logMessage(LOC("$$$/iNat/DialogCancelled=Dialog cancelled."))
        end
    end)
end

-- [Step 3] Export function
return {
    showSelection = showSelection
}

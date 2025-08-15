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

-- Localization function (provided by Lightroom)
local LOC = LOC

-- [Step 2] Main function: show species selection dialog
local function showSelection(resultsString)
    logger.logMessage("[Step 2] Starting showSelection with resultsString length: " .. tostring(#resultsString or "nil"))

    -- [2.1] Get the active photo
    logger.logMessage("[2.1] Retrieving active photo from catalog.")
    local catalog = LrApplication.activeCatalog()
    local photo = catalog:getTargetPhoto()
    
    -- [2.2] Check if photo is selected
    if not photo then
        logger.logMessage("[2.2] No active photo selected. Aborting.")
        LrDialogs.message(
            LOC("$$$/iNat/Error/NoPhoto=No photo selected"),
            LOC("$$$/iNat/Error/PleaseSelectPhoto=Please select a photo before adding keywords.")
        )
        return
    end
    logger.logMessage("[2.2] Active photo retrieved successfully.")

    -- [2.3] Find the recognized animals section in the results string
    logger.logMessage("[2.3] Searching for recognized species section in results string.")
    local startIndex = resultsString:find("🕊️%s*Recognized species%s*:")
    if not startIndex then
        logger.logMessage("[2.3] No recognized species section found in the results string.")
        LrDialogs.message(
            LOC("$$$/iNat/Error/NoRecognizedSection=No recognized species found"),
            LOC("$$$/iNat/Error/UnexpectedFormat=The result format is not recognized.")
        )
        return
    end
    logger.logMessage("[2.3] Recognized species section found at index: " .. tostring(startIndex))

    -- Extract the substring from this position
    local subResult = resultsString:sub(startIndex)
    logger.logMessage("[2.3] Extracted recognized species section: " .. subResult)

    -- [2.4] Parse species lines
    logger.logMessage("[2.4] Parsing species lines from results.")
    local parsedItems = {}
    for line in subResult:gmatch("[^\r\n]+") do
        logger.logMessage("[2.4] Processing line: " .. line)
        local nom_fr, nom_latin, pourcent = line:match("%- (.-) %((.-)%)%s*:%s*([%d%.]+)%%")
        if nom_fr and nom_latin and pourcent then
            local label = string.format("%s (%s) — %s%%", nom_fr, nom_latin, pourcent)
            local keyword = string.format("%s (%s)", nom_fr, nom_latin)
            logger.logMessage("[2.4] Parsed species: label='" .. label .. "', keyword='" .. keyword .. "'")
            table.insert(parsedItems, { label = label, keyword = keyword })
        else
            logger.logMessage("[2.4] Line did not match species format.")
        end
    end

    -- [2.5] Check at least one species detected
    if #parsedItems == 0 then
        logger.logMessage("[2.5] No valid species detected after parsing.")
        LrDialogs.message(
            LOC("$$$/iNat/Error/NoSpeciesDetected=No species detected"),
            LOC("$$$/iNat/Error/TryAgain=Please try running the identification again.")
        )
        return
    end
    logger.logMessage("[2.5] Parsed " .. tostring(#parsedItems) .. " species from results.")

    -- [2.6] Create modal UI with checkboxes for each species
    logger.logMessage("[2.6] Creating modal dialog UI with checkboxes.")
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
            logger.logMessage("[2.6] Added checkbox for: " .. item.label)
        end

        local contents = f:scrolled_view {
            width = 500,
            height = 300,
            bind_to_object = props,
            f:column(checkboxes)
        }
        logger.logMessage("[2.6] Modal dialog UI created.")

        -- [2.7] Show dialog and wait for user response
        logger.logMessage("[2.7] Presenting modal dialog to user.")
        local result = LrDialogs.presentModalDialog {
            title = LOC("$$$/iNat/Dialog/SelectSpecies=Select species to add as keywords"),
            contents = contents,
            actionVerb = LOC("$$$/iNat/Dialog/Add=Add")
        }

        -- [2.8] If user confirmed, gather selected keywords
        if result == "ok" then
            logger.logMessage("[2.8] User confirmed selection. Gathering selected keywords.")
            local selectedKeywords = {}

            for i, item in ipairs(parsedItems) do
                local key = "item_" .. i
                if props[key] == true then
                    table.insert(selectedKeywords, item.keyword)
                    logger.logMessage("[2.8] Selected: " .. item.keyword)
                end
            end

            -- [2.9] If none selected, inform and quit
            if #selectedKeywords == 0 then
                logger.logMessage("[2.9] No keywords selected by user.")
                LrDialogs.message(
                    LOC("$$$/iNat/Error/NoKeywordsSelected=No species selected"),
                    LOC("$$$/iNat/Info/NoKeywordsAdded=No keywords will be added.")
                )
                return
            end

            -- [2.10] Add selected keywords to the photo (create if needed)
            logger.logMessage("[2.10] Adding " .. tostring(#selectedKeywords) .. " keywords to the photo.")
            catalog:withWriteAccessDo(LOC("$$$/iNat/WriteAccess/AddingKeywords=Adding keywords"), function()
                local function getOrCreateKeyword(name)
                    logger.logMessage("[2.10] Searching for keyword: " .. name)
                    for _, kw in ipairs(catalog:getKeywords()) do
                        if kw:getName() == name then
                            logger.logMessage("[2.10] Found existing keyword: " .. name)
                            return kw
                        end
                    end
                    logger.logMessage("[2.10] Creating new keyword: " .. name)
                    return catalog:createKeyword(name, {}, true, nil, true)
                end

                for _, keyword in ipairs(selectedKeywords) do
                    local kw = getOrCreateKeyword(keyword)
                    if kw then
                        logger.logMessage("[2.10] Adding keyword to photo: " .. keyword)
                        photo:addKeyword(kw)
                    end
                end
            end)

            logger.logMessage("[2.10] Keywords successfully added: " .. table.concat(selectedKeywords, ", "))
            LrDialogs.message(
                LOC("$$$/iNat/Success/KeywordsAdded=Success"),
                LOC("$$$/iNat/Success/KeywordsAddedMessage=Selected keywords have been successfully added.")
            )
        else
            -- [2.11] Log user cancelled dialog
            logger.logMessage("[2.11] User cancelled the dialog.")
        end
    end)
end

-- [Step 3] Export function
return {
    showSelection = showSelection
}

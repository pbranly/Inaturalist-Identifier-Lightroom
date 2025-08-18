--[[
=====================================================================================
Module       : selectAndTagResults.lua
Author       : Philippe
Purpose      : Display recognized species from iNaturalist results and add
               selected species as Lightroom keywords.
Dependencies : Lightroom SDK modules (LrDialogs, LrFunctionContext, LrBinding,
               LrView, LrApplication), logger.lua
Used by      : call_inaturalist.lua
=====================================================================================

Functional Description (English):
This module receives the results table produced by the iNaturalist AI identification
service (call_inaturalist.lua). It performs the following actions:

1. Parses the iNaturalist results table to extract recognized species with their
   French common name, Latin name, and confidence percentage.
2. Displays a modal dialog in Lightroom with checkboxes for each species.
3. Allows the user to select which species to add as keywords.
4. Creates missing keywords in the Lightroom catalog if necessary.
5. Adds the selected keywords to the active photo.
6. Logs each step via logger.lua for debugging and traceability.
7. Provides internationalized messages for screen display (English).
=====================================================================================
]]

-- [Step 1] Import Lightroom SDK modules and logger
local LrDialogs         = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrBinding         = import "LrBinding"
local LrView            = import "LrView"
local LrApplication     = import "LrApplication"

local logger = require("logger")

-- [Step 2] Main function: show species selection dialog
local function showSelection(resultsTable)

    if type(resultsTable) == "string" then
        logger.logMessage("[Step 2] Warning: resultsTable is a string. Creating fallback entry.")
        resultsTable = {
            {
                taxon = {
                    preferred_common_name = "Unknown",
                    name = "Unknown"
                },
                combined_score = 1
            }
        }
    end

    logger.logMessage("[Step 2] Starting showSelection. Number of results received: " .. tostring(#resultsTable))

    -- [Step 3] Parse and filter species
    local parsedItems = {}
    for index, r in ipairs(resultsTable) do
        local taxon = r.taxon or {}
        local name_fr = taxon.preferred_common_name or "Unknown"
        local name_latin = taxon.name or "Unknown"
        local score = tonumber(r.combined_score) or 0

        logger.logMessage(string.format("[Step 3] Processing result #%d: FR='%s', Latin='%s', Score=%.3f", index, name_fr, name_latin, score))

        if score >= 5 then
            local scorePct = string.format("%.0f%%", score)
            local keyword = (name_fr == "Unknown") and name_latin or string.format("%s (%s)", name_fr, name_latin)
            local label   = (name_fr == "Unknown") and string.format("%s — %s", name_latin, scorePct)
                                                   or string.format("%s (%s) — %s", name_fr, name_latin, scorePct)

            table.insert(parsedItems, { label = label, keyword = keyword })
            logger.logMessage("[Step 3] Accepted species for UI: " .. label)
        else
            logger.logMessage("[Step 3] Ignored species (confidence <5%): " .. (name_latin or "Unknown"))
        end
    end

    -- [Step 4] Check for valid species
    if #parsedItems == 0 then
        logger.logMessage("[Step 4] No species with sufficient confidence found.")
        LrDialogs.message(
            LOC("$$$/iNat/NoSpeciesDetected=No species detected"),
            LOC("$$$/iNat/TryAgain=Please try running the identification again.")
        )
        return
    end

    -- [Step 5] Create modal UI
    LrFunctionContext.callWithContext("showSelection", function(context)
        local f = LrView.osFactory()
        local props = LrBinding.makePropertyTable(context)
        local checkboxes = {}

        for i, item in ipairs(parsedItems) do
            local key = "item_" .. i
            props[key] = false
            table.insert(checkboxes, f:row {
                spacing = 5,
                f:checkbox {
                    title = item.label,
                    value = LrView.bind(key)
                }
            })
            logger.logMessage(string.format("[Step 5] Checkbox added for species: %s", item.label))
        end

        local contents = f:scrolled_view {
            width = 500,
            height = 300,
            bind_to_object = props,
            f:column(checkboxes)
        }

        logger.logMessage("[Step 5] Presenting modal dialog to user for species selection.")
        local result = LrDialogs.presentModalDialog {
            title = LOC("$$$/iNat/PluginName=iNaturalist Identification"),
            contents = contents,
            actionVerb = LOC("$$$/iNat/Add=Add")
        }

        -- [Step 6] Handle user selection
        if result == "ok" then
            local selectedKeywords = {}
            for i, item in ipairs(parsedItems) do
                if props["item_" .. i] then
                    table.insert(selectedKeywords, item.keyword)
                    logger.logMessage("[Step 6] User selected: " .. item.keyword)
                end
            end

            if #selectedKeywords == 0 then
                logger.logMessage("[Step 6] No keywords selected by user.")
                LrDialogs.message(
                    LOC("$$$/iNat/NoSpeciesSelected=No species selected"),
                    LOC("$$$/iNat/NoKeywordsAdded=No keywords will be added.")
                )
                return
            end

            -- [Step 7] Add keywords to active photo
            local catalog = LrApplication.activeCatalog()
            local photo = catalog:getTargetPhoto()
            if not photo then
                logger.logMessage("[Step 7] ERROR: No active photo found.")
                LrDialogs.message(
                    LOC("$$$/iNat/NoPhotoSelected=No photo selected"),
                    LOC("$$$/iNat/PleaseSelectPhoto=Please select a photo before adding keywords.")
                )
                return
            end

            catalog:withWriteAccessDo("Adding keywords", function()
                local function getOrCreateKeyword(name)
                    for _, kw in ipairs(catalog:getKeywords()) do
                        if kw:getName() == name then return kw end
                    end
                    return catalog:createKeyword(name, {}, true, nil, true)
                end

                for _, keyword in ipairs(selectedKeywords) do
                    local kw = getOrCreateKeyword(keyword)
                    if kw then
                        photo:addKeyword(kw)
                        logger.logMessage("[Step 7] Added keyword to photo: " .. keyword)
                    end
                end
            end)

            logger.logMessage("[Step 7] Successfully added keywords: " .. table.concat(selectedKeywords, ", "))
            LrDialogs.message(
                LOC("$$$/iNat/Success=Success"),
                LOC("$$$/iNat/KeywordsAdded=Selected keywords have been successfully added.")
            )
        else
            -- [Step 8] Log cancellation
            logger.logMessage("[Step 8] User cancelled the species selection dialog.")
        end
    end)
end

-- [Step 9] Export function
return {
    showSelection = showSelection
}
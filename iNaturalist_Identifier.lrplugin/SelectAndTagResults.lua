--[[
=====================================================================================
 Script       : SelectAndTagResults.lua
 Purpose      : Display species identification results for manual keyword selection
 Author       : Philippe

 Functional Overview:
 This module is designed to process species identification results—typically generated
 by an AI model or external service—and present them in a user-friendly dialog within
 Adobe Lightroom. The user can manually select which species to tag as keywords on the
 currently selected photo. The script parses a formatted result string, builds a modal
 UI with checkboxes for each species, and adds the selected keywords to the photo.

 Key Features:
 - Parses species names, Latin names, and confidence percentages from a result string.
 - Displays a scrollable modal dialog with checkboxes for each identified species.
 - Allows users to select which species to tag as keywords.
 - Automatically creates missing keywords and applies them to the selected photo.
 - Logs all actions and handles edge cases gracefully.

 Expected Input Format:
 🕊️
 - Eurasian Blue Tit (Cyanistes caeruleus) : 96.3%
 - Great Tit (Parus major) : 2.1%
 ...

 Dependencies:
 - Lightroom SDK: LrDialogs, LrFunctionContext, LrBinding, LrView, LrApplication
 - Custom Logger module
=====================================================================================
--]]

-- Import necessary Lightroom SDK modules
local LrDialogs = import "LrDialogs"                 -- For displaying dialogs
local LrFunctionContext = import "LrFunctionContext" -- For managing UI lifecycle
local LrBinding = import "LrBinding"                 -- For binding UI elements to properties
local LrView = import "LrView"                       -- For building UI layouts
local LrApplication = import "LrApplication"         -- For accessing Lightroom catalog

-- Import custom logger module
local logger = require("Logger")

local function showSelection(resultsString)
    local catalog = LrApplication.activeCatalog()
    local photo = catalog:getTargetPhoto()

    if not photo then
        logger.logMessage("No photo selected.")
        return
    end

    local startIndex = resultsString:find("🕊️")
    if not startIndex then
        logger.logMessage("Unrecognized result format.")
        return
    end

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

    if #parsedItems == 0 then
        logger.logMessage("No species detected.")
        return
    end

    logger.logMessage(string.format("Parsed %d species, opening selection dialog.", #parsedItems))

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

        local result = LrDialogs.presentModalDialog {
            title = LOC("$$$/iNat/DialogTitle=Select species to add as keywords"),
            contents = contents,
            actionVerb = LOC("$$$/iNat/AddKeywords=Add")
        }

        if result == "ok" then
            local selectedKeywords = {}

            for i, item in ipairs(parsedItems) do
                local key = "item_" .. i
                if props[key] == true then
                    table.insert(selectedKeywords, item.keyword)
                end
            end

            if #selectedKeywords == 0 then
                logger.logMessage("No keywords selected.")
                LrDialogs.message(
                    LOC("$$$/iNat/NoSpeciesCheckedTitle=No species selected"),
                    LOC("$$$/iNat/NoKeywordsMessage=No keywords will be added.")
                )
                return
            end

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

            logger.logMessage("Keywords added: " .. table.concat(selectedKeywords, ", "))
            LrDialogs.message(
                LOC("$$$/iNat/SuccessTitle=Success"),
                LOC("$$$/iNat/SuccessMessage=Selected keywords have been successfully added.")
            )
        else
            logger.logMessage("Dialog cancelled.")
        end
    end)
end

return {
    showSelection = showSelection
}

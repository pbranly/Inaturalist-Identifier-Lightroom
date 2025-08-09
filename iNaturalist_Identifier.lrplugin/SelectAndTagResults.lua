--[[
=====================================================================================
 Script : SelectAndTagResults.lua
 Purpose : Display species identification results for manual keyword selection
 Author  : Philippe (or your name here)
 Description :
 This module processes identification results (typically from an AI or external service)
 and presents a dialog in Lightroom allowing the user to select which species names
 to add as keywords to the currently selected photo.

 Key Features:
   - Parses results from a string that includes species names, Latin names, and confidence percentages.
   - Presents results in a modal UI dialog with checkboxes for each identified species.
   - Lets the user choose which keywords to apply.
   - Adds the selected keywords to the photo in Lightroom, creating them if necessary.

 Expected Input Format (from result string):
   🕊️
   - Eurasian Blue Tit (Cyanistes caeruleus) : 96.3%
   - Great Tit (Parus major) : 2.1%
   ...

 Dependencies:
 - Lightroom SDK: LrDialogs, LrFunctionContext, LrBinding, LrView, LrApplication
 - Logger module (custom)
=====================================================================================
--]]

-- Import necessary Lightroom SDK modules
local LrDialogs = import "LrDialogs"                -- To show dialogs and messages
local LrFunctionContext = import "LrFunctionContext"-- To manage UI lifecycle
local LrBinding = import "LrBinding"                -- To bind UI elements to variables
local LrView = import "LrView"                      -- For building UI layouts
local LrApplication = import "LrApplication"        -- To interact with Lightroom catalog

-- Import custom logger module
local logger = require("Logger")

-- Function to parse the identification results and allow user to select keywords
local function showSelection(resultsString)
    local catalog = LrApplication.activeCatalog()
    local photo = catalog:getTargetPhoto()          -- Get the currently selected photo

    if not photo then
        logger.logMessage(LOC("$$$/iNat/NoPhotoSelected=No photo selected."))
        return
    end

    -- Find the position of the bird icon marking the start of results
    local startIndex = resultsString:find("🕊️")
    if not startIndex then
        logger.logMessage(LOC("$$$/iNat/UnknownFormat=Unrecognized result format."))
        return
    end

    -- Extract the relevant section of results
    local subResult = resultsString:sub(startIndex)
    local parsedItems = {}

    -- Parse each line that contains: - name_fr (latin_name) : XX%
    for line in subResult:gmatch("[^\r\n]+") do
        local nom_fr, nom_latin, pourcent = line:match("%- (.-) %((.-)%)%s*:%s*([%d%.]+)%%")
        if nom_fr and nom_latin and pourcent then
            local label = string.format("%s (%s) — %s%%", nom_fr, nom_latin, pourcent)
            local keyword = string.format("%s (%s)", nom_fr, nom_latin)
            table.insert(parsedItems, { label = label, keyword = keyword })
        end
    end

    if #parsedItems == 0 then
        logger.logMessage(LOC("$$$/iNat/NoSpeciesDetected=No species detected."))
        return
    end

    -- Create and show a dialog with checkboxes for each species
    LrFunctionContext.callWithContext("showSelection", function(context)
        local f = LrView.osFactory()
        local props = LrBinding.makePropertyTable(context)
        local checkboxes = {}

        for i, item in ipairs(parsedItems) do
            local key = "item_" .. i
            props[key] = false  -- Default: checkbox unchecked
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

        -- Present the modal dialog to the user
        local result = LrDialogs.presentModalDialog {
            title = LOC("$$$/iNat/DialogTitle=Select species to add as keywords"),
            contents = contents,
            actionVerb = LOC("$$$/iNat/AddKeywords=Add")
        }

        -- Handle user selection
        if result == "ok" then
            local selectedKeywords = {}

            for i, item in ipairs(parsedItems) do
                local key = "item_" .. i
                if props[key] == true then
                    table.insert(selectedKeywords, item.keyword)
                end
            end

            -- If no keywords selected
            if #selectedKeywords == 0 then
                logger.logMessage(LOC("$$$/iNat/NoKeywordsSelected=No keywords selected."))
                LrDialogs.message(
                    LOC("$$$/iNat/NoSpeciesCheckedTitle=No species selected"),
                    LOC("$$$/iNat/NoKeywordsMessage=No keywords will be added.")
                )
                return
            end

            -- Add the selected keywords to the photo
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

            -- Log and confirm success
            logger.logMessage(LOC("$$$/iNat/KeywordsAdded=Keywords added: ") .. table.concat(selectedKeywords, ", "))
            LrDialogs.message(
                LOC("$$$/iNat/SuccessTitle=Success"),
                LOC("$$$/iNat/SuccessMessage=Selected keywords have been successfully added.")
            )
        else
            logger.logMessage(LOC("$$$/iNat/DialogCancelled=Dialog cancelled."))
        end
    end)
end

-- Expose the function for use by other modules
return {
    showSelection = showSelection
}
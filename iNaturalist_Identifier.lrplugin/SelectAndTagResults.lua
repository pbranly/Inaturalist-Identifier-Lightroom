--[[
=====================================================================================
 Script    : SelectAndTagResults.lua
 Purpose   : Display species identification results for keyword tagging only.
             Uploading will be handled externally by the caller.

 Description :
 This module parses species recognition results and presents them to the user
 in a modal dialog. The user can:
   - Select species from a checkbox list to be added as keywords to the selected photo.

 It does NOT handle upload to iNaturalist anymore.

 Returns:
   - { keywordsAdded = { ... }, speciesSelected = true/false }

 Dependencies:
   - Lightroom SDK:
     LrDialogs, LrFunctionContext, LrBinding, LrView, LrApplication
   - Custom modules:
     Logger.lua → Logging utility

 Author    : Philippe
=====================================================================================
--]]

local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrBinding = import "LrBinding"
local LrView = import "LrView"
local LrApplication = import "LrApplication"

local logger = require("Logger")

local function showSelection(photo, resultsString)
    if not photo then
        logger.logMessage("No photo provided.")
        return { keywordsAdded = {}, speciesSelected = false }
    end

    -- Locate species result block
    local startIndex = resultsString:find("🕊️")
    if not startIndex then
        logger.logMessage("Result format unrecognized or missing species.")
        return { keywordsAdded = {}, speciesSelected = false }
    end

    local subResult = resultsString:sub(startIndex)
    local parsedItems = {}

    -- Parse species lines
    for line in subResult:gmatch("[^\r\n]+") do
        local name_fr, name_latin, percent =
            line:match("%- (.-) %((.-)%)%s*:%s*([%d%.]+)%%")
        if name_fr and name_latin and percent then
            local label = string.format("%s (%s) — %s%%", name_fr, name_latin, percent)
            local keyword = string.format("%s (%s)", name_fr, name_latin)
            table.insert(parsedItems, { label = label, keyword = keyword })
        end
    end

    if #parsedItems == 0 then
        logger.logMessage("No parsable species entries.")
        return { keywordsAdded = {}, speciesSelected = false }
    end

    local selectedKeywords = {}

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
            for i, item in ipairs(parsedItems) do
                local key = "item_" .. i
                if props[key] == true then
                    table.insert(selectedKeywords, item.keyword)
                end
            end

            if #selectedKeywords == 0 then
                logger.logMessage("No species selected by user.")
                LrDialogs.message(
                    LOC("$$$/iNat/Msg/NoSpeciesTitle=No species selected"),
                    LOC("$$$/iNat/Msg/NoSpeciesBody=No keywords will be added.")
                )
                return
            end

            -- Apply keywords
            local catalog = LrApplication.activeCatalog()
            catalog:withWriteAccessDo(LOC("$$$/iNat/WriteAccess=Add selected keywords"), function()
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
                LOC("$$$/iNat/Msg/SuccessTitle=Success"),
                LOC("$$$/iNat/Msg/SuccessBody=Selected species have been added as keywords.")
            )
        else
            logger.logMessage("Species selection dialog cancelled.")
        end
    end)

    return {
        keywordsAdded = selectedKeywords,
        speciesSelected = (#selectedKeywords > 0)
    }
end

return { showSelection = showSelection }

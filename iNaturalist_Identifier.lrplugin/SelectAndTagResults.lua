-- Import necessary Lightroom modules
local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrBinding = import "LrBinding"
local LrView = import "LrView"
local LrApplication = import "LrApplication"

-- Custom logger module
local logger = require("Logger")

-- Function to parse the result string and allow the user to select species to add as keywords
local function showSelection(resultsString)
    local catalog = LrApplication.activeCatalog()
    local photo = catalog:getTargetPhoto()
    
    if not photo then
        logger.logMessage(LOC("$$$/iNat/NoPhotoSelected=No photo selected."))
        return
    end

    -- Look for the start of the results section
    local startIndex = resultsString:find("🕊️%s*Animaux reconnus%s*:") or resultsString:find("🕊️%s*Recognized animals%s*:")
    if not startIndex then
        logger.logMessage(LOC("$$$/iNat/UnknownFormat=Unrecognized result format."))
        return
    end

    -- Extract and parse recognized species
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
        logger.logMessage(LOC("$$$/iNat/NoSpeciesDetected=No species detected."))
        return
    end

    -- Show dialog with checkboxes for each species
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

        -- If user clicked OK
        if result == "ok" then
            local selectedKeywords = {}

            for i, item in ipairs(parsedItems) do
                local key = "item_" .. i
                if props[key] == true then
                    table.insert(selectedKeywords, item.keyword)
                end
            end

            -- Handle case where no keywords are selected
            if #selectedKeywords == 0 then
                logger.logMessage(LOC("$$$/iNat/NoKeywordsSelected=No keywords selected."))
                LrDialogs.message(
                    LOC("$$$/iNat/NoSpeciesCheckedTitle=No species selected"),
                    LOC("$$$/iNat/NoKeywordsMessage=No keywords will be added.")
                )
                return
            end

            -- Add selected keywords to the photo
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
            logger.logMessage(LOC("$$$/iNat/DialogCancelled=Dialog cancelled."))
        end
    end)
end

return {
    showSelection = showSelection
}

--[[
=====================================================================================
 Script    : SelectAndTagResults.lua
 Purpose   : Display species identification results for keyword tagging and 
             optional upload to iNaturalist.

 Description :
 This module parses species recognition results (typically from the iNaturalist API)
 and presents them to the user in a modal dialog. It allows the user to:

   1. Select species from a checkbox list to be added as keywords to the selected photo.
   2. After keyword tagging, the user is asked whether they wish to upload the observation
      to iNaturalist using the stored API token.
   3. If confirmed, the UploadObservation.lua script is invoked.

 Functional Highlights:
   - Parses result strings containing French and Latin species names with confidence scores.
   - Displays a scrollable list of checkboxes (one per species).
   - Applies selected keywords to the photo.
   - Offers an upload confirmation dialog after tagging.
   - Logs all actions through the Logger module.

 Dependencies:
   - Lightroom SDK:
     LrDialogs, LrFunctionContext, LrBinding, LrView, LrApplication
   - Custom modules:
     Logger.lua              → Logging utility.
     UploadObservation.lua   → Handles POSTing observation to iNaturalist.

 Author    : Philippe
=====================================================================================
--]]

-- Lightroom SDK imports
local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrBinding = import "LrBinding"
local LrView = import "LrView"
local LrApplication = import "LrApplication"

-- Plugin modules
local logger = require("Logger")
local uploadModule = require("UploadObservation")  -- This module must define upload(photo, token)

--- Main function to show species selection and optionally upload observation
-- @param photo (LrPhoto) The photo to which keywords should be added
-- @param resultsString (string) Raw text results returned by the iNaturalist API
-- @param token (string) Auth token for API requests
local function showSelection(photo, resultsString, token)

    if not photo then
        logger.logMessage("No photo provided.")
        return
    end

    -- Attempt to locate species result block in the result string
    local startIndex = resultsString:find("🕊️")
    if not startIndex then
        logger.logMessage("Result format unrecognized or missing species.")
        return
    end

    local subResult = resultsString:sub(startIndex)
    local parsedItems = {}

    -- Parse lines with expected pattern: - Name (Latin) : XX.X%
    for line in subResult:gmatch("[^\r\n]+") do
        local name_fr, name_latin, percent = line:match("%- (.-) %((.-)%)%s*:%s*([%d%.]+)%%")
        if name_fr and name_latin and percent then
            local label = string.format("%s (%s) — %s%%", name_fr, name_latin, percent)
            local keyword = string.format("%s (%s)", name_fr, name_latin)
            table.insert(parsedItems, { label = label, keyword = keyword })
        end
    end

    if #parsedItems == 0 then
        logger.logMessage("No parsable species entries.")
        return
    end

    -- Create and present the UI for species keyword selection
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

        -- Show modal dialog to user
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
                logger.logMessage("No species selected by user.")
                LrDialogs.message("No species selected", "No keywords will be added.")
                return
            end

            -- Apply keywords to the photo
            local catalog = LrApplication.activeCatalog()
            catalog:withWriteAccessDo("Add selected keywords", function()
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
            LrDialogs.message("Success", "Selected species have been added as keywords.")

            -- Ask whether to upload the observation
            local confirm = LrDialogs.confirm(
                LOC("$$$/iNat/ConfirmUploadTitle=Send observation?"),
                LOC("$$$/iNat/ConfirmUploadBody=Do you want to upload the observation to iNaturalist?"),
                LOC("$$$/iNat/Yes=Yes"),
                LOC("$$$/iNat/No=No")
            )

            if confirm == "ok" then
                local success, err = uploadModule.upload(photo, token)
                if success then
                    LrDialogs.message("Upload Complete", "Observation successfully sent to iNaturalist.")
                    logger.logMessage("Observation uploaded successfully.")
                else
                    LrDialogs.message("Upload Failed", err or "Unknown error.")
                    logger.logMessage("Upload error: " .. (err or "unknown"))
                end
            else
                logger.logMessage("User declined to upload observation.")
            end
        else
            logger.logMessage("Species selection dialog cancelled.")
        end
    end)
end

-- Export the main function
return {
    showSelection = showSelection
}

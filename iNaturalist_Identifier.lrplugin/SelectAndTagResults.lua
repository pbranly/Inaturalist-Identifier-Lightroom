--[[
============================================================
 Script       : selectAndTagResults.lua
 Purpose      : Display iNaturalist identification results,
                filter them, and apply selected keywords
                as Lightroom tags.

 Functional Overview:
 1. Receives structured table of results from call_inaturalist.lua.
 2. Filters out predictions with score <= 10%.
 3. Displays species in a Lightroom dialog (checkboxes).
 4. Allows the user to confirm which species to tag.
 5. Applies selected species as keywords in Lightroom.

 Dependencies:
 - Lightroom SDK:
   * LrDialogs      (UI dialog for selection)
   * LrView         (to build list with checkboxes)
   * LrBinding      (bind UI to data)
   * LrTasks        (async execution)
   * LrApplication  (apply keywords)
 - External scripts:
   * Logger.lua
   * call_inaturalist.lua (provides species results)

 Scripts that use this module:
 - iNaturalist_Identifier.lua
============================================================
]]

local LrDialogs     = import "LrDialogs"
local LrView        = import "LrView"
local LrBinding     = import "LrBinding"
local LrTasks       = import "LrTasks"
local LrApplication = import "LrApplication"

local logger        = require "Logger"

-- Localization function
local LOC = LOC

-- Main function: filter, display, and apply tags
local function selectAndTagResults(results, photo)
    logger.logMessage("[Step 1] Entering selectAndTagResults with " .. tostring(#results) .. " results.")

    -- [Step 2] Filter out predictions with percent <= 10%
    logger.logMessage("[Step 2] Filtering results with confidence <= 10%.")
    local filtered = {}
    for _, r in ipairs(results) do
        if r.percent > 10 then
            table.insert(filtered, r)
            logger.logMessage(string.format(
                "[Step 2] Kept: %s (%s) %.2f%%",
                r.fr, r.latin, r.percent
            ))
        else
            logger.logMessage(string.format(
                "[Step 2] Discarded: %s (%s) %.2f%%",
                r.fr, r.latin, r.percent
            ))
        end
    end

    if #filtered == 0 then
        logger.logMessage("[Step 2] No results above 10% threshold.")
        LrDialogs.message(
            LOC("$$$/iNat/NoValidResults=No valid results"),
            LOC("$$$/iNat/ThresholdWarning=No species above 10% confidence.")
        )
        return
    end

    -- [Step 3] Build UI list with checkboxes
    logger.logMessage("[Step 3] Building UI for result selection.")
    local props = LrBinding.makePropertyTable()
    local rows = {}
    for i, r in ipairs(filtered) do
        local key = "sel_" .. tostring(i)
        props[key] = true -- default: checked
        table.insert(rows,
            LrView:row {
                bind_to_object = props,
                LrView:checkbox {
                    title = string.format("%s (%s) - %.1f%%", r.fr, r.latin, r.percent),
                    value = LrView.bind(key),
                }
            }
        )
    end

    local f = LrView.osFactory()
    local contents = f:column {
        spacing = 5,
        bind_to_object = props,
        LrView:static_text {
            title = LOC("$$$/iNat/Dialog/SelectSpecies=Select species to tag:"),
        },
        unpack(rows)
    }

    -- [Step 4] Display dialog
    logger.logMessage("[Step 4] Showing selection dialog to user.")
    local result = LrDialogs.presentModalDialog {
        title = LOC("$$$/iNat/Dialog/Title=iNaturalist Identification"),
        contents = contents,
        actionVerb = LOC("$$$/iNat/Dialog/Tag=Tag Photo"),
    }

    if result ~= "ok" then
        logger.logMessage("[Step 4] User cancelled selection dialog.")
        return
    end

    -- [Step 5] Collect selected species
    logger.logMessage("[Step 5] Collecting user selections.")
    local selected = {}
    for i, r in ipairs(filtered) do
        local key = "sel_" .. tostring(i)
        if props[key] then
            table.insert(selected, r)
            logger.logMessage(string.format(
                "[Step 5] User selected: %s (%s) %.2f%%",
                r.fr, r.latin, r.percent
            ))
        else
            logger.logMessage(string.format(
                "[Step 5] User did not select: %s (%s)",
                r.fr, r.latin
            ))
        end
    end

    if #selected == 0 then
        logger.logMessage("[Step 5] No species selected, nothing to tag.")
        return
    end

    -- [Step 6] Apply tags to photo
    logger.logMessage("[Step 6] Applying keywords to photo.")
    LrTasks.startAsyncTask(function()
        local catalog = LrApplication.activeCatalog()
        catalog:withWriteAccessDo("Tag iNaturalist results", function()
            for _, r in ipairs(selected) do
                local keywordName = r.fr .. " (" .. r.latin .. ")"
                logger.logMessage("[Step 6] Applying keyword: " .. keywordName)
                local keyword = catalog:createKeyword(keywordName, {}, true, nil, true)
                photo:addKeyword(keyword)
            end
        end)
    end)

    logger.logMessage("[Step 6] Tagging process finished.")
end

-- Export module
return {
    selectAndTagResults = selectAndTagResults
}

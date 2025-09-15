--[[
============================================================
Functional Description
------------------------------------------------------------
This module `selectAndTagResults.lua` parses a text string 
coming from iNaturalist identification results, extracts 
recognized species, and shows a Lightroom dialog where the 
user can choose which species to add as keywords.

Functional flow:
1. Parse the identification results string and extract the 
   recognized species list with French name, Latin name, and 
   confidence percentage.
2. Build a Lightroom modal dialog with checkboxes for each 
   detected species.
3. Allow the user to select which species will be added.
4. Add the selected keywords to the provided photo in Lightroom, 
   creating new keywords if necessary.
5. After successful keyword addition, call observation_selection
   to ask user about iNaturalist submission.
6. Log all actions in detail using `logger.lua`.

------------------------------------------------------------
Modules and Scripts Used
------------------------------------------------------------
- Lightroom SDK:
  * LrDialogs          : UI dialogs
  * LrFunctionContext  : Scoped UI context
  * LrBinding          : Bind data to UI elements
  * LrView             : UI controls
  * LrApplication      : Access to catalog and photos
  * LrPathUtils        : For path operations
  * LrFileUtils        : For file existence checks
  * LrPrefs            : Access to plugin preferences
- logger.lua           : Logging utility (English logs)
- observation_selection.lua : Handles iNaturalist submission

------------------------------------------------------------
Scripts Using This Script
------------------------------------------------------------
- Typically called by:
  * AnimalIdentifier.lua
  * Other modules processing iNaturalist API responses

------------------------------------------------------------
Numbered Steps
------------------------------------------------------------
1. Import required modules (Lightroom SDK + logger + observation_selection).
2. Define `showSelection` function.
   2.1. Locate "Recognized species" section in the results string.
   2.2. Parse each line to extract species (name + confidence).
   2.3. Check that at least one valid species was parsed.
   2.4. Create a Lightroom UI with checkboxes for species.
   2.5. Show modal dialog and handle user choice.
   2.6. If user confirmed, collect selected species.
   2.7. If none selected, notify and exit.
   2.8. Add selected species as keywords to the given photo.
   2.9. Call observation_selection to ask about iNaturalist submission.
   2.10. Log success or cancellation.
3. Export `showSelection` function.

Each step is logged in English using `logger.lua`.
============================================================
]]

-- [Step 1] Import Lightroom SDK modules
local LrDialogs         = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrBinding         = import "LrBinding"
local LrView            = import "LrView"
local LrApplication     = import "LrApplication"
local LrPathUtils       = import "LrPathUtils"
local LrFileUtils       = import "LrFileUtils"
local LrPrefs           = import "LrPrefs"

-- [Step 1] Import logger and observation_selection
local logger = require("Logger")
local observationSelection = require("observation_selection")

-- Localization function
local LOC = LOC

-- [Step 2] Main function: show species selection dialog
local function showSelection(resultsString, photo)
    logger.logMessage("[Step 2] Starting showSelection. Results string length: " .. tostring(#resultsString or "nil"))
    logger.logMessage("[Step 2] Photo object received: " .. (photo and "present" or "missing"))

    -- [2.1] Find "Recognized species" section
    logger.logMessage("[2.1] Searching for recognized species section in results string.")
    local startIndex = resultsString:find("🕊️%s*Recognized species%s*:")
    if not startIndex then
        logger.logMessage("[2.1] No recognized species section found. Aborting.")
        LrDialogs.message(
            LOC("$$$/iNat/Error/NoRecognizedSection=No recognized species found"),
            LOC("$$$/iNat/Error/UnexpectedFormat=The result format is not recognized.")
        )
        return
    end
    logger.logMessage("[2.1] Recognized species section found at index: " .. tostring(startIndex))

    local subResult = resultsString:sub(startIndex)
    logger.logMessage("[2.1] Extracted recognized species section:\n" .. subResult)

    -- [2.2] Parse species lines
    logger.logMessage("[2.2] Parsing species lines.")
    local parsedItems = {}
    for line in subResult:gmatch("[^\r\n]+") do
        logger.logMessage("[2.2] Processing line: " .. line)
        local nom_fr, nom_latin, pourcent = line:match("%- (.-) %((.-)%)%s*:%s*([%d%.]+)")
        if nom_fr and nom_latin and pourcent then
            local pourcentNum = tonumber(pourcent) or 0
            if pourcentNum >= 5 then -- ignore species < 5%
                local rounded = string.format("%.0f", pourcentNum)
                local keyword = (nom_fr == "Unknown") and nom_latin or string.format("%s (%s)", nom_fr, nom_latin)
                local label   = (nom_fr == "Unknown") and string.format("%s — %s%%", nom_latin, rounded)
                                   or string.format("%s (%s) — %s%%", nom_fr, nom_latin, rounded)
                logger.logMessage("[2.2] Parsed species: label='" .. label .. "', keyword='" .. keyword .. "'")
                table.insert(parsedItems, { label = label, keyword = keyword })
            else
                logger.logMessage("[2.2] Ignored species with confidence < 5%: " .. line)
            end
        else
            logger.logMessage("[2.2] Line did not match expected species format.")
        end
    end

    -- [2.3] Check at least one valid species
    if #parsedItems == 0 then
        logger.logMessage("[2.3] No valid species parsed. Aborting.")
        LrDialogs.message(
            LOC("$$$/iNat/Error/NoSpeciesDetected=No species detected"),
            LOC("$$$/iNat/Error/TryAgain=Please try identification again.")
        )
        return
    end
    logger.logMessage("[2.3] Parsed " .. tostring(#parsedItems) .. " species.")

    -- [2.4] Build modal dialog with checkboxes
    logger.logMessage("[2.4] Building modal dialog with species checkboxes.")
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
            logger.logMessage("[2.4] Added checkbox for species: " .. item.label)
        end

        local contents = f:scrolled_view {
            width = 500,
            height = 300,
            bind_to_object = props,
            f:column(checkboxes)
        }

        -- [2.5] Show dialog
        logger.logMessage("[2.5] Presenting modal dialog for user selection.")
        local result = LrDialogs.presentModalDialog {
            title = LOC("$$$/iNat/Dialog/SelectSpecies=Select species to add as keywords"),
            contents = contents,
            actionVerb = LOC("$$$/iNat/Dialog/Add=Add")
        }

        if result == "ok" then
            -- [2.6] Collect selected keywords
            local selectedKeywords = {}
            for i, item in ipairs(parsedItems) do
                local key = "item_" .. i
                if props[key] == true then
                    table.insert(selectedKeywords, item.keyword)
                    logger.logMessage("[2.6] User selected: " .. item.keyword)
                end
            end

            -- [2.7] If none selected, warn and exit
            if #selectedKeywords == 0 then
                logger.logMessage("[2.7] No keywords selected. Exiting without changes.")
                LrDialogs.message(
                    LOC("$$$/iNat/Error/NoKeywordsSelected=No species selected"),
                    LOC("$$$/iNat/Info/NoKeywordsAdded=No keywords will be added.")
                )
                return
            end

            -- [2.8] Add selected keywords to the provided photo
            local catalog = LrApplication.activeCatalog()
            local photoName = photo and photo:getFormattedMetadata("fileName") or "<unknown>"
            logger.logMessage("[2.8] Preparing to add keywords to photo: " .. photoName)

            catalog:withWriteAccessDo("Adding iNaturalist keywords", function()
                local function getOrCreateKeyword(name)
                    for _, kw in ipairs(catalog:getKeywords()) do
                        if kw:getName() == name then
                            logger.logMessage("[2.8] Found existing keyword: " .. name)
                            return kw
                        end
                    end
                    logger.logMessage("[2.8] Creating new keyword: " .. name)
                    return catalog:createKeyword(name, {}, true, nil, true)
                end

                for _, keyword in ipairs(selectedKeywords) do
                    local kw = getOrCreateKeyword(keyword)
                    if kw and photo then
                        logger.logMessage("[2.8] Adding keyword '" .. keyword .. "' to photo: " .. photoName)
                        photo:addKeyword(kw)
                    end
                end
            end)

            logger.logMessage("[2.8] Keywords successfully added to " .. photoName .. ": " .. table.concat(selectedKeywords, ", "))

            -- [2.9] Call observation_selection after successful keyword addition
            logger.logMessage("[2.9] Keywords applied successfully. Calling observation_selection module.")
            
            -- Enhanced validation before calling observation_selection
            if selectedKeywords and #selectedKeywords > 0 then
                -- Get plugin preferences for token
                local prefs = LrPrefs.prefsForPlugin()
                local token = prefs.token
                logger.logMessage("[2.9] Retrieved token from preferences: " .. (token and "present" or "missing"))
                
                if not token or token == "" then
                    logger.logMessage("[2.9] No iNaturalist token found in preferences.")
                    LrDialogs.message(
                        LOC("$$$/iNat/Error/NoToken=No iNaturalist token configured"),
                        LOC("$$$/iNat/Error/ConfigureToken=Please configure your iNaturalist token in plugin preferences.")
                    )
                    return
                end
                
                -- Path to tempo.jpg (created by export_photo_to_tempo.lua)
                local tempoPath = LrPathUtils.child(_PLUGIN.path, "tempo.jpg")
                logger.logMessage("[2.9] Checking for tempo.jpg at path: " .. tempoPath)

                if LrFileUtils.exists(tempoPath) then
                    logger.logMessage("[2.9] tempo.jpg found. Calling observation_selection.askSubmit() with 4 parameters:")
                    logger.logMessage("[2.9]   - photoPath: " .. tempoPath)
                    logger.logMessage("[2.9]   - keywords: " .. table.concat(selectedKeywords, ", "))
                    logger.logMessage("[2.9]   - token: [PRESENT]")
                    logger.logMessage("[2.9]   - photo object: " .. (photo and "provided" or "nil"))
                    
                    -- Protection against errors with enhanced error handling
                    local success, err = pcall(function()
                        -- CORRECTION IMPORTANTE: Passer 4 paramètres au lieu de 3
                        observationSelection.askSubmit(tempoPath, selectedKeywords, token, photo)
                    end)
                    
                    if not success then
                        logger.logMessage("[2.9] Error calling observation_selection: " .. tostring(err))
                        LrDialogs.message(
                            LOC("$$$/iNat/Error/ObservationError=Error launching observation submission"), 
                            tostring(err),
                            "error"
                        )
                    else
                        logger.logMessage("[2.9] observation_selection.askSubmit() called successfully")
                    end
                else
                    logger.logMessage("[2.9] tempo.jpg not found at expected path. Cannot ask for observation submission.")
                    LrDialogs.message(
                        LOC("$$$/iNat/Error/TempoNotFound=Temporary file not found"),
                        LOC("$$$/iNat/Error/CannotSubmitObservation=Cannot submit observation without exported image. Please ensure the photo export completed successfully.")
                    )
                end
            else
                logger.logMessage("[2.9] No selectedKeywords available for observation submission")
            end

            -- [2.10] Final success log
            logger.logMessage("[2.10] Process completed successfully.")

        else
            -- [2.10] User cancelled
            logger.logMessage("[2.10] User cancelled the species selection dialog.")
        end
    end)
end

-- [Step 3] Export function
return {
    showSelection = showSelection
}

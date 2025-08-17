--[[
============================================================
Module : selectAndTagResults.lua
------------------------------------------------------------
Ce module reçoit un tableau JSON renvoyé par l’API iNaturalist
(resultsTable), affiche une interface permettant de choisir 
les espèces reconnues et ajoute les sélections en mots-clés
dans Lightroom.

Étapes principales :
1. Récupère la photo active du catalogue.
2. Transforme le tableau JSON en liste affichable (labels + keywords).
3. Affiche une boîte de dialogue avec cases à cocher.
4. Ajoute les mots-clés sélectionnés à la photo.
============================================================
]]

-- Imports Lightroom SDK
local LrDialogs        = import "LrDialogs"
local LrFunctionContext= import "LrFunctionContext"
local LrBinding        = import "LrBinding"
local LrView           = import "LrView"
local LrApplication    = import "LrApplication"

-- Logger
local logger = require("Logger")

-- Fonction principale
local function showSelection(resultsTable)
    logger.logMessage("[Step 2] showSelection: " .. tostring(#resultsTable) .. " résultats reçus")

    -- [2.1] Photo active
    local catalog = LrApplication.activeCatalog()
    local photo = catalog:getTargetPhoto()
    if not photo then
        logger.logMessage("[2.1] Pas de photo active.")
        LrDialogs.message("No photo selected", "Please select a photo before adding keywords.")
        return
    end

    -- [2.2] Préparation des espèces à afficher
    local parsedItems = {}
    for _, r in ipairs(resultsTable) do
        local taxon = r.taxon or {}
        local nom_fr = taxon.preferred_common_name or "Unknown"
        local nom_latin = taxon.name or "Unknown"
        local score = tonumber(r.combined_score) or 0

        -- Filtrer (>= 5%)
        if score >= 0.05 then
            local scorePct = string.format("%.0f", score * 100)
            local keyword = (nom_fr == "Unknown")
                and nom_latin
                or string.format("%s (%s)", nom_fr, nom_latin)
            local label   = (nom_fr == "Unknown")
                and string.format("%s — %s%%", nom_latin, scorePct)
                or string.format("%s (%s) — %s%%", nom_fr, nom_latin, scorePct)

            table.insert(parsedItems, { label = label, keyword = keyword })
            logger.logMessage("[2.2] Ajout espèce : " .. label)
        else
            logger.logMessage("[2.2] Espèce ignorée (<5%) : " .. (taxon.name or "??"))
        end
    end

    if #parsedItems == 0 then
        logger.logMessage("[2.2] Aucun résultat exploitable.")
        LrDialogs.message("No species detected", "Try running the identification again.")
        return
    end

    -- [2.3] Interface utilisateur
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
            width = 500, height = 300,
            bind_to_object = props,
            f:column(checkboxes)
        }

        -- [2.4] Affichage de la boîte de dialogue
        local result = LrDialogs.presentModalDialog {
            title = "Select species to add as keywords",
            contents = contents,
            actionVerb = "Add"
        }

        -- [2.5] Traitement si OK
        if result == "ok" then
            local selectedKeywords = {}
            for i, item in ipairs(parsedItems) do
                if props["item_" .. i] then
                    table.insert(selectedKeywords, item.keyword)
                    logger.logMessage("[2.5] Sélectionné : " .. item.keyword)
                end
            end

            if #selectedKeywords == 0 then
                logger.logMessage("[2.5] Aucun mot-clé choisi.")
                LrDialogs.message("No species selected", "No keywords will be added.")
                return
            end

            -- [2.6] Ajout des mots-clés dans Lightroom
            catalog:withWriteAccessDo("Adding keywords", function()
                local function getOrCreateKeyword(name)
                    for _, kw in ipairs(catalog:getKeywords()) do
                        if kw:getName() == name then return kw end
                    end
                    return catalog:createKeyword(name, {}, true, nil, true)
                end

                for _, keyword in ipairs(selectedKeywords) do
                    local kw = getOrCreateKeyword(keyword)
                    if kw then photo:addKeyword(kw) end
                end
            end)

            logger.logMessage("[2.6] Mots-clés ajoutés : " .. table.concat(selectedKeywords, ", "))
            LrDialogs.message("Success", "Selected keywords have been successfully added.")
        else
            logger.logMessage("[2.4] L’utilisateur a annulé la boîte de dialogue.")
        end
    end)
end

-- Export
return {
    showSelection = showSelection
}

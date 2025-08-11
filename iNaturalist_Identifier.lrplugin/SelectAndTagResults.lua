--[[
============================================================
Description fonctionnelle
------------------------------------------------------------
Ce module `selectAndTagResults.lua` analyse une chaîne de texte 
résultant d’une identification d’animaux (résultats d’iNaturalist), 
extrait la liste des espèces reconnues, puis affiche une interface 
à l’utilisateur Lightroom lui permettant de sélectionner celles à 
ajouter comme mots-clés à la photo active.

Fonctionnalités principales :
1. Identifier la photo sélectionnée dans le catalogue Lightroom.
2. Parser la chaîne de résultats pour extraire chaque espèce détectée 
   avec son nom français, nom latin et pourcentage de confiance.
3. Afficher une fenêtre modale listant ces espèces sous forme de 
   cases à cocher.
4. Permettre à l’utilisateur de sélectionner les espèces à ajouter 
   comme mots-clés Lightroom.
5. Créer les mots-clés s’ils n’existent pas, puis les ajouter à la photo.
6. Journaliser les différentes étapes et afficher des messages 
   d’erreur ou succès.

------------------------------------------------------------
Étapes numérotées
1. Importer les modules Lightroom nécessaires et le logger.
2. Définir la fonction `showSelection` qui :
    2.1. Récupérer la photo active dans le catalogue.
    2.2. Vérifier si une photo est sélectionnée, sinon loguer et quitter.
    2.3. Trouver la section des résultats dans la chaîne reçue.
    2.4. Extraire les espèces avec nom français, latin, et pourcentage.
    2.5. Vérifier si des espèces ont été détectées, sinon loguer et quitter.
    2.6. Créer une interface modale avec des cases à cocher pour chaque espèce.
    2.7. Lorsque l’utilisateur valide, collecter les espèces sélectionnées.
    2.8. Si aucune sélection, avertir l’utilisateur et quitter.
    2.9. Ajouter les mots-clés à la photo (création si nécessaire).
    2.10. Loguer l’ajout et afficher un message de succès.
    2.11. Si annulation, loguer l’action.
3. Exporter la fonction pour usage externe.

------------------------------------------------------------
Scripts appelés
- Logger.lua (pour journaliser)
- Lightroom SDK (pour interface, gestion catalogue et mots-clés)

------------------------------------------------------------
Script appelant
- AnimalIdentifier.lua (après identification, pour proposer les mots-clés)
============================================================
]]

-- [Étape 1] Import Lightroom SDK modules
local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrBinding = import "LrBinding"
local LrView = import "LrView"
local LrApplication = import "LrApplication"

-- [Étape 1] Import logger
local logger = require("Logger")

-- [Étape 2] Fonction principale : afficher le choix des espèces à taguer
local function showSelection(resultsString)
    -- [2.1] Récupérer la photo active
    local catalog = LrApplication.activeCatalog()
    local photo = catalog:getTargetPhoto()
    
    -- [2.2] Vérifier sélection photo
    if not photo then
        logger.logMessage(LOC("$$$/iNat/NoPhotoSelected=No photo selected."))
        return
    end

    -- [2.3] Trouver la section des résultats d’animaux reconnus
    local startIndex = resultsString:find("🕊️%s*Animaux reconnus%s*:") or resultsString:find("🕊️%s*Recognized animals%s*:")
    if not startIndex then
        logger.logMessage(LOC("$$$/iNat/UnknownFormat=Unrecognized result format."))
        return
    end

    -- [2.4] Extraire les espèces et leurs infos (nom FR, latin, confiance %)
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

    -- [2.5] Vérifier qu’au moins une espèce a été détectée
    if #parsedItems == 0 then
        logger.logMessage(LOC("$$$/iNat/NoSpeciesDetected=No species detected."))
        return
    end

    -- [2.6] Créer interface modale avec cases à cocher pour chaque espèce
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

        -- [2.7] Afficher le dialogue et attendre réponse utilisateur
        local result = LrDialogs.presentModalDialog {
            title = LOC("$$$/iNat/DialogTitle=Select species to add as keywords"),
            contents = contents,
            actionVerb = LOC("$$$/iNat/AddKeywords=Add")
        }

        -- [2.8] Si utilisateur valide, récupérer sélection
        if result == "ok" then
            local selectedKeywords = {}

            for i, item in ipairs(parsedItems) do
                local key = "item_" .. i
                if props[key] == true then
                    table.insert(selectedKeywords, item.keyword)
                end
            end

            -- [2.9] Si aucune sélection, informer et quitter
            if #selectedKeywords == 0 then
                logger.logMessage(LOC("$$$/iNat/NoKeywordsSelected=No keywords selected."))
                LrDialogs.message(
                    LOC("$$$/iNat/NoSpeciesCheckedTitle=No species selected"),
                    LOC("$$$/iNat/NoKeywordsMessage=No keywords will be added.")
                )
                return
            end

            -- [2.10] Ajouter mots-clés sélectionnés à la photo (création si nécessaire)
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
            -- [2.11] Log annulation utilisateur
            logger.logMessage(LOC("$$$/iNat/DialogCancelled=Dialog cancelled."))
        end
    end)
end

-- [Étape 3] Export fonction
return {
    showSelection = showSelection
}

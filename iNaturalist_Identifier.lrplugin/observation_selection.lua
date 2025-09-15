--[[
    Script: observation_selection.lua (Version corrigée)
    ---------------------------------------------------
    This script handles user interaction for submitting an exported photo 
    (tempo.jpg) as an observation to the iNaturalist platform from within Lightroom.

    Purpose:
    --------
    Displays a confirmation dialog asking the user whether they want to submit 
    the exported photo as an observation (with species information) to iNaturalist.

    How It Works:
    -------------
    1. Prompts the user with a Yes/No dialog using `LrDialogs.confirm`.
    2. If the user confirms, starts an asynchronous task to:
       - Log the intent.
       - Extract photo metadata (GPS coordinates, date taken).
       - Call the `submitObservation()` internal function,
         using the path of the already-exported JPEG (tempo.jpg), 
         the species keywords, and the authentication token.
       - Show the raw JSON response from iNaturalist (for debugging).
       - Show a success or error message based on the result.
    3. If the user cancels, it logs that the action was aborted.

    Dependencies:
    -------------
    - Logger.lua              : Logs success, failure, or cancellation messages.
    - Lightroom SDK           : Used for dialogs, background tasks, and HTTP requests.
    - Translated LOC strings  : Used for multi-language support in UI prompts and messages.

    Notes:
    ------
    - The photo to submit must already have been exported via `export_photo_to_tempo.lua`.
    - This script is autonomous and calls the iNaturalist API directly.
    - Required parameters: 
        * photoPath (string) : full path to the exported file (tempo.jpg).
        * keyword  (string or table) : selected species keywords.
        * token    (string) : iNaturalist authentication token (OAuth2 Bearer).
        * photo    (LrPhoto) : original Lightroom photo object for metadata extraction.
]]

-- observation_selection.lua

-- Import Lightroom SDK modules
local LrDialogs    = import "LrDialogs"
local LrTasks      = import "LrTasks"
local LrHttp       = import "LrHttp"
local LrFileUtils  = import "LrFileUtils"
local LrDate       = import "LrDate"

-- Import custom modules
local logger = require("Logger")
local LOC = LOC

-- Define a local table to store functions
local observation = {}

--------------------------------------------------------------------------------
-- Function to extract GPS coordinates from photo metadata
-- photo : LrPhoto object
-- returns : latitude, longitude (numbers or nil)
--------------------------------------------------------------------------------
local function extractGPSCoordinates(photo)
    if not photo then return nil, nil end
    
    local metadata = photo:getFormattedMetadata()
    local rawMetadata = photo:getRawMetadata()
    
    -- Try to get GPS coordinates from metadata
    local latitude = rawMetadata.gpsLatitude
    local longitude = rawMetadata.gpsLongitude
    
    -- Alternative: try formatted metadata
    if not latitude or not longitude then
        latitude = metadata.gpsLatitude
        longitude = metadata.gpsLongitude
    end
    
    -- Convert to numbers if they're strings
    if latitude then latitude = tonumber(latitude) end
    if longitude then longitude = tonumber(longitude) end
    
    return latitude, longitude
end

--------------------------------------------------------------------------------
-- Function to extract date taken from photo metadata
-- photo : LrPhoto object
-- returns : formatted date string or current date
--------------------------------------------------------------------------------
local function extractDateTaken(photo)
    if not photo then 
        return os.date("!%Y-%m-%d %H:%M:%S UTC")
    end
    
    local rawMetadata = photo:getRawMetadata()
    local dateTimeOriginal = rawMetadata.dateTimeOriginal
    
    if dateTimeOriginal then
        -- Convert LrDate to ISO format
        return LrDate.formatShortDate(dateTimeOriginal) .. " " .. LrDate.formatShortTime(dateTimeOriginal)
    else
        -- Fallback to current date
        return os.date("!%Y-%m-%d %H:%M:%S UTC")
    end
end

--------------------------------------------------------------------------------
-- Function to validate file size (iNaturalist has limits)
-- photoPath : full path to the photo file
-- returns : boolean (true if valid size)
--------------------------------------------------------------------------------
local function validateFileSize(photoPath)
    local MAX_SIZE = 20 * 1024 * 1024 -- 20MB limit
    
    local fileSize = LrFileUtils.fileAttributes(photoPath).fileSize
    if not fileSize then
        logger.logMessage("[observation_selection] Warning: Could not determine file size")
        return true -- Allow submission anyway
    end
    
    if fileSize > MAX_SIZE then
        logger.logMessage("[observation_selection] Error: File too large (" .. fileSize .. " bytes, max " .. MAX_SIZE .. ")")
        return false
    end
    
    return true
end

--------------------------------------------------------------------------------
-- Function to validate authentication token
-- token : authentication token string
-- returns : boolean (basic validation only)
--------------------------------------------------------------------------------
local function validateToken(token)
    if not token or token == "" then
        return false
    end
    
    -- Basic validation: token should be reasonably long
    if string.len(token) < 10 then
        return false
    end
    
    return true
end

--------------------------------------------------------------------------------
-- Internal function to submit an observation to iNaturalist
-- photoPath : full path of the exported JPEG
-- keyword   : species keyword(s) (string or table)
-- token     : iNaturalist authentication token
-- photo     : original LrPhoto object for metadata
--------------------------------------------------------------------------------
local function submitObservation(photoPath, keyword, token, photo)
    -- Validate inputs
    if not validateToken(token) then
        return false, "Invalid authentication token. Please check your iNaturalist token."
    end
    
    if not validateFileSize(photoPath) then
        return false, "Photo file is too large. Maximum size is 20MB."
    end
    
    -- Ensure keyword is a string; if table, join multiple keywords with comma
    local species_guess_str
    if type(keyword) == "table" then
        species_guess_str = table.concat(keyword, ", ")
    else
        species_guess_str = tostring(keyword or "Unknown species")
    end
    
    -- Extract metadata from photo
    local latitude, longitude = extractGPSCoordinates(photo)
    local observedDate = extractDateTaken(photo)
    
    -- Build multipart parameters for iNaturalist API
    local params = {
        {
            name = "observation[species_guess]",
            value = species_guess_str
        },
        {
            name = "observation[observed_on_string]",
            value = observedDate
        },
        {
            name = "observation[description]",
            value = "Submitted via Lightroom plugin"
        },
        {
            name = "observation[tag_list]",
            value = "lightroom,automated-upload"
        }
    }
    
    -- Add GPS coordinates if available
    if latitude and longitude then
        table.insert(params, {
            name = "observation[latitude]",
            value = tostring(latitude)
        })
        table.insert(params, {
            name = "observation[longitude]",
            value = tostring(longitude)
        })
        -- Set reasonable accuracy (in meters)
        table.insert(params, {
            name = "observation[positional_accuracy]",
            value = "100"
        })
        logger.logMessage("[observation_selection] GPS coordinates found: " .. latitude .. ", " .. longitude)
    else
        logger.logMessage("[observation_selection] No GPS coordinates found in photo metadata")
    end
    
    -- Add photo with corrected parameter name
    table.insert(params, {
        name = "observation_photo[file]",  -- Corrected parameter name
        fileName = "observation.jpg",      -- More descriptive filename
        filePath = photoPath,
        contentType = "image/jpeg"
    })
    
    -- HTTP headers with authentication
    local headers = {
        { field = "Authorization", value = "Bearer " .. token },
        { field = "User-Agent", value = "Lightroom-iNaturalist-Plugin/1.0" }
    }

    -- === Log complet de la requête HTTP avant envoi ===
    logger.logMessage("[observation_selection] HTTP Request:")
    logger.logMessage("POST https://api.inaturalist.org/v1/observations")
    logger.logMessage("Headers:")
    for _, h in ipairs(headers) do
        -- Don't log full token for security in production
        if h.field == "Authorization" then
            logger.logMessage("  " .. h.field .. ": Bearer [TOKEN_HIDDEN]")
        else
            logger.logMessage("  " .. h.field .. ": " .. h.value)
        end
    end
    logger.logMessage("Multipart Parameters:")
    for i, p in ipairs(params) do
        local desc = "  part " .. i .. ": " .. p.name
        if p.value then desc = desc .. " = " .. tostring(p.value) end
        if p.fileName then desc = desc .. " (fileName=" .. p.fileName .. ", filePath=" .. p.filePath .. ")" end
        logger.logMessage(desc)
    end
    
    -- === Génération de la commande curl équivalente (DEBUG) ===
    local curlCommand = "curl -X POST \"https://api.inaturalist.org/v1/observations\" \\\n"
    
    -- Ajouter les headers
    for _, h in ipairs(headers) do
        curlCommand = curlCommand .. "  -H \"" .. h.field .. ": " .. h.value .. "\" \\\n"
    end
    
    -- Ajouter les paramètres multipart
    for _, p in ipairs(params) do
        if p.fileName and p.filePath then
            -- Paramètre fichier
            curlCommand = curlCommand .. "  -F \"" .. p.name .. "=@" .. p.filePath .. "\" \\\n"
        else
            -- Paramètre texte (échapper les guillemets dans la valeur)
            local escapedValue = string.gsub(tostring(p.value), '"', '\\"')
            curlCommand = curlCommand .. "  -F \"" .. p.name .. "=" .. escapedValue .. "\" \\\n"
        end
    end
    
    -- Ajouter les options finales
    curlCommand = curlCommand .. "  --verbose"
    
    logger.logMessage("[observation_selection] === CURL COMMAND FOR MANUAL TESTING ===")
    logger.logMessage(curlCommand)
    logger.logMessage("[observation_selection] === END CURL COMMAND ===")
    -- === Fin log curl ===

    -- Perform POST request to iNaturalist API with timeout
    local result, hdrs = LrHttp.postMultipart(
        "https://api.inaturalist.org/v1/observations",
        params,
        headers,
        30 -- 30 second timeout
    )

    -- Log raw server response and headers
    logger.logMessage("[observation_selection] API response body: " .. (result or "nil"))
    if hdrs then
        for k, v in pairs(hdrs) do
            logger.logMessage("[observation_selection] Header: " .. tostring(k) .. " = " .. tostring(v))
        end
    else
        logger.logMessage("[observation_selection] No headers returned from server")
    end

    -- Enhanced response analysis
    if not result or result == "" then
        return false, "No response from server. Please check your internet connection."
    end
    
    -- Check for various error patterns
    if string.find(result, '"error"') or 
       string.find(result, '"errors"') or
       string.find(result, '"status":"error"') or
       (hdrs and hdrs.status and tonumber(hdrs.status) >= 400) then
        
        -- Try to extract specific error message
        local errorMsg = "Unknown error occurred."
        if string.find(result, '"message"') then
            local msgStart = string.find(result, '"message":"')
            if msgStart then
                local msgEnd = string.find(result, '"', msgStart + 11)
                if msgEnd then
                    errorMsg = string.sub(result, msgStart + 11, msgEnd - 1)
                end
            end
        end
        
        return false, "API Error: " .. errorMsg .. "\n\nFull response: " .. result
    end
    
    -- Check for successful creation (should contain observation ID)
    if string.find(result, '"id":') and string.find(result, '"uuid"') then
        return true, result
    else
        return false, "Unexpected response format. Response: " .. result
    end
end

--------------------------------------------------------------------------------
-- Enhanced function to ask the user if they want to submit an observation
-- photoPath = full path of tempo.jpg (exported earlier)
-- keyword   = selected species keyword(s)
-- token     = iNaturalist authentication token
-- photo     = original LrPhoto object for metadata extraction
--------------------------------------------------------------------------------
function observation.askSubmit(photoPath, keyword, token, photo)
    -- Pre-flight checks
    if not LrFileUtils.exists(photoPath) then
        LrDialogs.message(
            LOC("$$$/iNat/Dialog/FileNotFound=File not found"),
            LOC("$$$/iNat/Dialog/FileNotFoundDetails=The exported photo could not be found. Please export the photo first."),
            "error"
        )
        return
    end
    
    -- Show detailed confirmation dialog
    local gpsStatus = ""
    if photo then
        local lat, lon = extractGPSCoordinates(photo)
        if lat and lon then
            gpsStatus = "\n\nGPS coordinates will be included: " .. string.format("%.6f, %.6f", lat, lon)
        else
            gpsStatus = "\n\nNo GPS coordinates found in photo metadata."
        end
    end
    
    local response = LrDialogs.confirm(
        LOC("$$$/iNat/Dialog/AskObservation=Submit to iNaturalist?"),
        LOC("$$$/iNat/Dialog/AskObservationDetails=Species: ") .. tostring(keyword) .. gpsStatus,
        LOC("$$$/iNat/Dialog/Submit=Submit"),
        LOC("$$$/iNat/Dialog/Cancel=Cancel")
    )

    if response == "ok" then
        LrTasks.startAsyncTask(function()
            logger.logMessage("[observation_selection] Submitting observation...")
            
            -- Show progress dialog
            local progressScope = LrDialogs.showModalProgressDialog({
                title = "Submitting to iNaturalist",
                caption = "Uploading observation...",
                cannotCancel = false,
            })
            
            local success, msg = submitObservation(photoPath, keyword, token, photo)
            
            -- Close progress dialog
            progressScope:done()

            if success then
                -- Parse response to get observation URL if possible
                local obsId = string.match(msg, '"id":(%d+)')
                local successMsg = LOC("$$$/iNat/Dialog/ObservationSubmitted=Observation submitted successfully!")
                
                if obsId then
                    successMsg = successMsg .. "\n\nObservation ID: " .. obsId
                    successMsg = successMsg .. "\nURL: https://www.inaturalist.org/observations/" .. obsId
                end
                
                LrDialogs.message(
                    LOC("$$$/iNat/Dialog/Success=Success!"),
                    successMsg,
                    "info"
                )
                
                logger.logMessage("[observation_selection] Observation submitted successfully. ID: " .. (obsId or "unknown"))
            else
                logger.logMessage("[observation_selection] Failed to submit observation: " .. (msg or "unknown error"))
                
                LrDialogs.message(
                    LOC("$$$/iNat/Dialog/ObservationFailed=Failed to submit observation"),
                    msg or LOC("$$$/iNat/Dialog/UnknownError=Unknown error occurred."),
                    "error"
                )
            end
        end)
    else
        logger.logMessage("[observation_selection] User cancelled observation submission.")
    end
end

-- Return the observation module
return observation

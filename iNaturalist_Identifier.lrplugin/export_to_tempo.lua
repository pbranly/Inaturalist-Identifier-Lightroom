--[[
=====================================================================================
 Script      : export_to_tempo.lua
 Purpose     : Export selected photo to a temporary JPEG file for external use

 Description :
 This Lightroom plugin module exports the currently selected photo to a temporary 
 JPEG file named "tempo.jpg" located in the plugin's own folder (cross-platform).
 It intègre désormais les fonctions utilitaires `clearJPEGs` et `findSingleJPEG`
 précédemment contenues dans `imageutils.lua`, afin de simplifier l'architecture.

 Use Case:
 - The exported file can be used for external services like image recognition 
   (e.g., AI classification, iNaturalist API).

 Workflow:
 ---------
 1. Delete any existing JPEG files in the plugin folder.
 2. Set up export settings:
     - Format: JPEG
     - Size: Max 1024x1024 pixels
     - Include metadata (especially GPS, capture time)
 3. Create export session for the selected photo.
 4. Export the file to a temp location inside the plugin folder.
 5. Rename the exported file to "tempo.jpg".
 6. Return the full absolute path to "tempo.jpg", or nil and an error message.

 Platform Compatibility:
 -----------------------
 ✅ Works on macOS and Windows using `_PLUGIN.path` to locate plugin directory.
 ❌ Does not currently support mobile (Lightroom Mobile SDK not compatible).

 Dependencies:
 -------------
 - Lightroom SDK: LrExportSession, LrPathUtils, LrFileUtils
 - _PLUGIN global: for determining the plugin directory path
 - Logger.lua : for logging deletions and issues

 Author:
 -------
 Philippe
=====================================================================================
--]]

-- Import Lightroom SDK modules
local LrExportSession = import "LrExportSession"
local LrFileUtils     = import "LrFileUtils"
local LrPathUtils     = import "LrPathUtils"

-- Import logger
local logger = require("Logger")

-- Local utility function: Delete all JPEGs in a directory
local function clearJPEGs(directory)
    logger.logMessage("Clearing existing JPEG files in directory: " .. directory)
    for file in LrFileUtils.files(directory) do
        if string.lower(LrPathUtils.extension(file)) == "jpg" then
            LrFileUtils.delete(file)
            logger.logMessage("JPG file deleted: " .. file)
        end
    end
end

-- Local utility function: Find first JPEG file in a directory
local function findSingleJPEG(directory)
    logger.logMessage("Searching for a single JPEG file in directory: " .. directory)
    for file in LrFileUtils.files(directory) do
        if string.lower(LrPathUtils.extension(file)) == "jpg" then
            logger.logMessage("Found JPEG file: " .. file)
            return file
        end
    end
    logger.logMessage("No JPEG files found in directory: " .. directory)
    return nil
end

-- Define module
local export_to_tempo = {}

-- Export currently selected photo to "tempo.jpg" in plugin folder
-- Note: This function must be called inside a Lightroom async task (LrTasks.startAsyncTask)
-- because it calls rendition:waitForRender(), which yields.
function export_to_tempo.exportToTempo(photo)
    if not photo then
        logger.logMessage("No photo selected for export.")
        return nil, "No photo selected."
    end

    -- Define export folder as plugin's directory (cross-platform)
    local exportFolder = _PLUGIN.path
    local tempFileName = "tempo.jpg"
    local tempFilePath = LrPathUtils.child(exportFolder, tempFileName)

    logger.logMessage("Export folder: " .. exportFolder)
    logger.logMessage("Target export file path: " .. tempFilePath)

    -- Step 1: Clear all existing JPEGs in folder
    clearJPEGs(exportFolder)

    -- Step 2: Define export settings
    local exportSettings = {
        LR_export_destinationType = "specificFolder",
        LR_export_destinationPathPrefix = exportFolder,
        LR_export_useSubfolder = false,
        LR_format = "JPEG",
        LR_jpeg_quality = 0.9,
        LR_size_doConstrain = true,
        LR_size_maxWidth = 1024,
        LR_size_maxHeight = 1024,
        LR_metadata_include = "all",
        LR_minimizeEmbeddedMetadata = false,
        LR_removeLocationMetadata = false,
        LR_renamingTokensOn = false,
    }
    logger.logMessage("Export settings configured.")

    -- Step 3: Create export session
    local exportSession = LrExportSession {
        photosToExport = { photo },
        exportSettings = exportSettings,
    }
    logger.logMessage("Export session created.")

    -- Step 4: Perform export
    logger.logMessage("Starting export task.")
    exportSession:doExportOnCurrentTask()
    logger.logMessage("Export task finished.")

    -- Step 5: Locate exported JPEG and rename to "tempo.jpg"
    for _, rendition in exportSession:renditions() do
        local success, pathOrMsg = rendition:waitForRender()
        if success and pathOrMsg and LrFileUtils.exists(pathOrMsg) then
            logger.logMessage("Exported file located at: " .. pathOrMsg)
            local moved, moveErr = LrFileUtils.move(pathOrMsg, tempFilePath)
            if moved then
                logger.logMessage("Exported file moved to: " .. tempFilePath)
                return tempFilePath
            else
                logger.logMessage("Failed to move exported file: " .. tostring(moveErr))
                return nil, "Failed to move exported file: " .. tostring(moveErr)
            end
        else
            logger.logMessage("Failed to render photo: " .. tostring(pathOrMsg or "unknown error"))
            return nil, "Failed to render photo: " .. (pathOrMsg or "unknown error")
        end
    end

    logger.logMessage("No photo was exported during renditions processing.")
    return nil, "No photo was exported."
end

-- Return module
return export_to_tempo

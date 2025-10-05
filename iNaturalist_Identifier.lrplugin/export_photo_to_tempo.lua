--[[
=====================================================================================
 Script      : export_photo_to_tempo.lua
 Purpose     : Export selected photo to a temporary JPEG file for external use

 Description :
 This Lightroom plugin module exports the currently selected photo to a temporary
 JPEG file named "tempo.jpg" located in the plugin's own folder (cross-platform).
 It keeps only the EXIF metadata useful for iNaturalist determination:
   - Date/time of capture
   - GPS coordinates (if available)
   - Copyright
   - Author/Creator name

 Other EXIF (ISO, aperture, camera model, etc.) is excluded.

 Use Case:
 - The exported file can be used for external services like iNaturalist API.

 Workflow:
 ---------
 1. Delete any existing JPEG files in the plugin folder.
 2. Set up export settings with selected metadata filters.
 3. Create export session for the selected photo.
 4. Export the file to a temp location inside the plugin folder.
 5. Rename the exported file to "tempo.jpg".
 6. Return the full absolute path to "tempo.jpg", or nil and an error message.

 Platform Compatibility:
 -----------------------
 ✅ Works on macOS and Windows using _PLUGIN.path
 ❌ Not supported on Lightroom Mobile

 Dependencies:
 -------------
 - Lightroom SDK: LrExportSession, LrPathUtils, LrFileUtils
 - _PLUGIN global: for plugin directory path
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
    for file in LrFileUtils.files(directory) do
        if string.lower(LrPathUtils.extension(file)) == "jpg" then
            LrFileUtils.delete(file)
            logger.logMessage(LOC("$$$/iNat/Log/JPGDeleted=JPG file deleted: ") .. file)
        end
    end
end

-- Define module
local export_photo_to_tempo = {}

-- Export currently selected photo to "tempo.jpg" in plugin folder
function export_photo_to_tempo.exportToTempo(photo)
    if not photo then
        return nil, "No photo selected."
    end

    -- Define export folder as plugin's directory (cross-platform)
    local exportFolder = _PLUGIN.path
    local tempFileName = "tempo.jpg"
    local tempFilePath = LrPathUtils.child(exportFolder, tempFileName)

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

        -- Metadata control
        LR_metadata_keywordHandling = "excludeAll",
        LR_metadata_include = "all",
        LR_metadata_includeDate = true,
        LR_metadata_includeLocation = true,
        LR_metadata_includeCopyright = true,
        LR_metadata_includeCreator = true,
        LR_removeLocationMetadata = false,
        LR_minimizeEmbeddedMetadata = true,
        LR_renamingTokensOn = false,
    }

    -- Step 3: Create export session
    local exportSession = LrExportSession {
        photosToExport = { photo },
        exportSettings = exportSettings,
    }

    -- Step 4: Perform export
    exportSession:doExportOnCurrentTask()

    -- Step 5: Locate exported JPEG and rename (single photo expected)
    local renditions = exportSession:renditions()
    local rendition = renditions[1]
    if rendition then
        local success, pathOrMsg = rendition:waitForRender()
        if success and pathOrMsg and LrFileUtils.exists(pathOrMsg) then
            local result = LrFileUtils.move(pathOrMsg, tempFilePath)
            if result then
                logger.logMessage("Export successful: " .. tempFilePath)
                return tempFilePath
            else
                return nil, "Failed to move exported file."
            end
        else
            return nil, "Failed to render photo: " .. (pathOrMsg or "unknown error")
        end
    end

    return nil, "No photo was exported."
end

-- Return module
return export_photo_to_tempo

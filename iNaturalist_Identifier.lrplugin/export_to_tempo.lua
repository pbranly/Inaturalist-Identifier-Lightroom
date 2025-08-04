-- Import required Lightroom SDK modules
local LrExportSession = import "LrExportSession"     -- For exporting images from Lightroom
local LrTasks = import "LrTasks"                     -- To run tasks safely in Lightroom
local LrPathUtils = import "LrPathUtils"             -- To work with file system paths
local LrFileUtils = import "LrFileUtils"             -- To manipulate files (delete, move, etc.)

-- Import custom utility modules
local imageUtils = require("ImageUtils")             -- Module with helper functions for image file handling
local logger = require("Logger")                     -- Custom logger for writing debug/info/error messages
local LOC = LOC                                      -- Lightroom localization helper (used for translatable messages)

-- Function to export a selected Lightroom photo to a JPEG named "tempo.jpg"
local function exportToTempo(photo)
    -- Get the plugin's installation directory path
    local pluginFolder = _PLUGIN.path

    -- Step 1: Delete all existing JPEG files in the plugin folder
    imageUtils.clearJPEGs(pluginFolder)

    -- Step 2: Prepare export settings for Lightroom
    local exportSettings = {
        LR_export_destinationType = "specificFolder",            -- Export to a specific folder
        LR_export_destinationPathPrefix = pluginFolder,          -- The destination is the plugin folder
        LR_export_useSubfolder = false,                          -- Do not create subfolders
        LR_format = "JPEG",                                      -- Export as JPEG format
        LR_jpeg_quality = 0.8,                                   -- Set JPEG quality to 80%
        LR_size_resizeType = "wh",                               -- Resize using width and height
        LR_size_maxWidth = 1024,                                 -- Maximum width: 1024 pixels
        LR_size_maxHeight = 1024,                                -- Maximum height: 1024 pixels
        LR_size_doNotEnlarge = true,                             -- Prevent Lightroom from enlarging small photos
        LR_metadata_includeAll = true,                           -- Include all metadata (including GPS and EXIF)
        LR_removeLocationMetadata = false,                       -- Keep location (GPS) metadata
        LR_renamingTokensOn = true,                              -- Enable renaming using tokens
        LR_renamingTokens = "{{image_name}}",                    -- Use original image name for export
    }

    -- Step 3: Create an export session with the selected photo and the above settings
    local exportSession = LrExportSession({
        photosToExport = { photo },                              -- Only export the selected photo
        exportSettings = exportSettings                          -- Apply the export settings
    })

    -- Step 4: Run the export inside a protected call to catch any runtime errors
    local success = LrTasks.pcall(function()
        exportSession:doExportOnCurrentTask()                    -- Perform the actual export
    end)

    -- Step 5: If export failed, return nil with a localized error message
    if not success then
        return nil, LOC("$$$/iNat/Error/ExportFailed=Export failed.")
    end

    -- Step 6: Try to locate the exported JPEG file in the plugin folder
    local exportedPath = imageUtils.findSingleJPEG(pluginFolder)
    if not exportedPath then
        return nil, LOC("$$$/iNat/Error/ExportedFileNotFound=Exported file not found.")
    end

    -- Step 7: Build the full path to "tempo.jpg" inside the plugin folder
    local finalPath = LrPathUtils.child(pluginFolder, "tempo.jpg")

    -- Step 8: Move (rename) the exported file to "tempo.jpg"
    local ok, err = LrFileUtils.move(exportedPath, finalPath)
    if not ok then
        return nil, LOC("$$$/iNat/Error/FileMove=Failed to rename exported file: ") .. (err or "unknown")
    end

    -- Step 9: Return the full path to "tempo.jpg" to the caller
    return finalPath
end

-- Export the function so that it can be used by other modules
return {
    exportToTempo = exportToTempo
}

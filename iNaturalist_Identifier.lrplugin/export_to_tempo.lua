-- Import required Lightroom modules
local LrExportSession = import "LrExportSession"
local LrTasks = import "LrTasks"
local LrPathUtils = import "LrPathUtils"
local LrFileUtils = import "LrFileUtils"

-- Custom modules
local imageUtils = require("ImageUtils")
local logger = require("Logger")
local LOC = LOC

-- Function to export a given photo to tempo.jpg
local function exportToTempo(photo)
    local pluginFolder = _PLUGIN.path

    -- Clear existing JPEGs in plugin folder
    imageUtils.clearJPEGs(pluginFolder)

    -- Export settings to create a JPEG with embedded metadata
    local exportSettings = {
        LR_export_destinationType = "specificFolder",
        LR_export_destinationPathPrefix = pluginFolder,
        LR_export_useSubfolder = false,
        LR_format = "JPEG",
        LR_jpeg_quality = 0.8,
        LR_size_resizeType = "wh",
        LR_size_maxWidth = 1024,
        LR_size_maxHeight = 1024,
        LR_size_doNotEnlarge = true,
        LR_metadata_includeAll = true, -- Include all metadata including GPS
        LR_removeLocationMetadata = false,
        LR_renamingTokensOn = true,
        LR_renamingTokens = "{{image_name}}",
    }

    -- Perform export
    local exportSession = LrExportSession({
        photosToExport = { photo },
        exportSettings = exportSettings
    })

    local success = LrTasks.pcall(function()
        exportSession:doExportOnCurrentTask()
    end)

    if not success then
        return nil, LOC("$$$/iNat/Error/ExportFailed=Export failed.")
    end

    -- Locate the exported JPEG
    local exportedPath = imageUtils.findSingleJPEG(pluginFolder)
    if not exportedPath then
        return nil, LOC("$$$/iNat/Error/ExportedFileNotFound=Exported file not found.")
    end

    -- Rename to tempo.jpg
    local finalPath = LrPathUtils.child(pluginFolder, "tempo.jpg")
    local ok, err = LrFileUtils.move(exportedPath, finalPath)
    if not ok then
        return nil, LOC("$$$/iNat/Error/FileMove=Failed to rename exported file: ") .. (err or "unknown")
    end

    return finalPath
end

return {
    exportToTempo = exportToTempo
}

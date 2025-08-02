-- export_to_tempo.lua

local LrExportSession = import "LrExportSession"
local LrTasks = import "LrTasks"
local LrPathUtils = import "LrPathUtils"
local LrFileUtils = import "LrFileUtils"
local LrDialogs = import "LrDialogs"

local exportToTempo = {}

function exportToTempo.export(photo, pluginFolder, imageUtils, logger, LOC)
    -- Export settings with metadata and GPS included
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
        LR_renamingTokensOn = true,
        LR_renamingTokens = "{{image_name}}",

        -- Include metadata and GPS info
        LR_export_includeMetadata = true,
        LR_export_includeGPS = true,
        LR_minimizeEmbeddedMetadata = false,
        LR_metadata_keywordOptions = "lightroomHierarchical",
        LR_includeDevelopSettings = true,
    }

    local exportSession = LrExportSession({
        photosToExport = { photo },
        exportSettings = exportSettings
    })

    local success = LrTasks.pcall(function()
        exportSession:doExportOnCurrentTask()
    end)

    if not success then
        return nil, LOC("$$$/iNat/Error/ExportSessionFailed=Export session failed.")
    end

    local exportedPath = imageUtils.findSingleJPEG(pluginFolder)
    if not exportedPath then
        return nil, LOC("$$$/iNat/Error/ExportedFileNotFound=Exported file not found.")
    end

    local finalPath = LrPathUtils.child(pluginFolder, "tempo.jpg")
    local ok, err = LrFileUtils.move(exportedPath, finalPath)
    if not ok then
        return nil, LOC("$$$/iNat/Error/RenameFailed=File rename error: ") .. (err or LOC("$$$/iNat/Error/Unknown=unknown"))
    end

    logger.logMessage(LOC("$$$/iNat/Log/Exported=Image exported as tempo.jpg"))
    LrDialogs.showBezel(LOC("$$$/iNat/Bezel/Exported=Image exported to tempo.jpg"), 2)

    return finalPath, nil
end

return exportToTempo

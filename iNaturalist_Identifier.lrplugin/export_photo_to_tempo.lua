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
 - Lightroom SDK: LrExportSession, LrPathUtils, LrFileUtils, LrTasks, LrFunctionContext
 - _PLUGIN global: for plugin directory path
 - Logger.lua : for logging deletions and issues

 Author:
 -------
 Philippe
=====================================================================================
--]]

-- Import Lightroom SDK modules
local LrExportSession = import("LrExportSession")
local LrFileUtils = import("LrFileUtils")
local LrPathUtils = import("LrPathUtils")
local LrTasks = import("LrTasks")
local LrFunctionContext = import("LrFunctionContext")

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

	-- Step 3: Perform export in a function context
	local exportSuccess = false
	LrFunctionContext.callWithContext("export", function()
		-- Create export session
		local exportSession = LrExportSession({
			photosToExport = { photo },
			exportSettings = exportSettings,
		})

		-- Execute export on current task
		exportSession:doExportOnCurrentTask()
		exportSuccess = true
	end)

	if not exportSuccess then
		return nil, "Export session failed"
	end

	-- Step 4: Wait a bit for file system to sync
	LrTasks.sleep(0.2)

	-- Step 5: Find the exported JPEG file in the folder
	local exportedFile = nil
	for file in LrFileUtils.files(exportFolder) do
		if string.lower(LrPathUtils.extension(file)) == "jpg" then
			exportedFile = file
			logger.logMessage("Found exported file: " .. file)
			break
		end
	end

	if not exportedFile then
		return nil, "No exported file found in folder"
	end

	-- Step 6: Rename to tempo.jpg if needed
	if exportedFile ~= tempFilePath then
		local moveResult = LrFileUtils.move(exportedFile, tempFilePath)
		if not moveResult then
			return nil, "Failed to rename exported file to tempo.jpg"
		end
	end

	-- Verify final file exists
	if LrFileUtils.exists(tempFilePath) then
		logger.logMessage("Export successful: " .. tempFilePath)
		return tempFilePath
	else
		return nil, "Final file tempo.jpg not found"
	end
end

-- Return module
return export_photo_to_tempo

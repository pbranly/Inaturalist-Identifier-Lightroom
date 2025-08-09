--[[
=====================================================================================
 Script       : ImageUtils.lua
 Purpose      : Utility module for managing JPEG files in a directory
 Author       : Philippe

 Functional Overview:
 This module provides utility functions to support the Lightroom plugin’s workflow
 during species identification. It helps manage temporary image files by:

   1. Deleting all JPEG files (*.jpg) from a specified directory.
   2. Locating and returning the first JPEG file found in a directory.

 These operations are essential for maintaining a clean working environment and
 ensuring that the correct image is processed after export.

 Key Features:
 - Efficient cleanup of old or unused JPEG files
 - Reliable retrieval of the most recent exported image
 - Logging of all file operations for traceability

 Dependencies:
 - Logger.lua        : Logs deletion and detection actions.
 - Lightroom SDK     : Uses LrFileUtils and LrPathUtils for file system operations.

 Usage Notes:
 - Typically used before and after exporting a photo for species identification.
 - Assumes the target directory is accessible and contains JPEG files.
=====================================================================================
--]]

-- Import Lightroom SDK modules for file and path operations
local LrFileUtils = import "LrFileUtils"     -- For listing and deleting files
local LrPathUtils = import "LrPathUtils"     -- For handling file extensions and paths

-- Import custom logger module
local logger = require("Logger")             -- For logging file operations

--[[
 Function: clearJPEGs
 Description:
 Deletes all files with a `.jpg` extension in the specified directory.
 Helps prevent clutter and ensures only relevant images are retained.

 Parameters:
 - directory (string): Path to the directory to clean.

 Behavior:
 - Iterates through all files in the directory.
 - Deletes each file with a `.jpg` extension (case-insensitive).
 - Logs each deletion for traceability.
--]]
local function clearJPEGs(directory)
    for file in LrFileUtils.files(directory) do
        if string.lower(LrPathUtils.extension(file)) == "jpg" then
            LrFileUtils.delete(file)
            logger.logMessage(LOC("$$$/iNat/Log/JPGDeleted=JPG file deleted: ") .. file)
        end
    end
end

--[[
 Function: findSingleJPEG
 Description:
 Searches the specified directory and returns the first file with a `.jpg` extension.
 Typically used to locate the exported image for species identification.

 Parameters:
 - directory (string): Path to the directory to search.

 Returns:
 - string: Full path to the first JPEG file found, or nil if none are found.

 Behavior:
 - Iterates through all files in the directory.
 - Returns the first file with a `.jpg` extension (case-insensitive).
--]]
local function findSingleJPEG(directory)
    for file in LrFileUtils.files(directory) do
        if string.lower(LrPathUtils.extension(file)) == "jpg" then
            return file
        end
    end
    return nil
end

-- Export utility functions for use in other plugin modules
return {
    clearJPEGs = clearJPEGs,
    findSingleJPEG = findSingleJPEG
}
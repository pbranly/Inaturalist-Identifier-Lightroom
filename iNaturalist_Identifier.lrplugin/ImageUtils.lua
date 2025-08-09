--[[
=====================================================================================
 Script : file_helpers.lua
 Purpose : Utility module for managing JPEG files in a directory
 Author  : Philippe (or your name here)
 Description :
 This module provides helper functions used by the Lightroom plugin to:
   1. Delete all JPEG files (*.jpg) from a specified directory. This ensures that
      old or temporary exports don't accumulate between plugin runs.
   2. Find and return the first JPEG file in a directory. This is useful after a 
      photo is exported and needs to be located for further processing.

 These functions support the plugin’s workflow, especially when preparing and managing
 temporary image files during the species identification process.

 Dependencies:
 - Logger.lua: For logging deletion actions and file detections.
 - Lightroom SDK: LrFileUtils and LrPathUtils for filesystem and path operations.

=====================================================================================
--]]

-- Import Lightroom utilities for file and path handling
local LrFileUtils = import "LrFileUtils"     -- For file operations (delete, list files, etc.)
local LrPathUtils = import "LrPathUtils"     -- For working with file extensions, paths, etc.

-- Import custom logger
local logger = require("Logger")             -- Custom logging module for tracking actions

-- Deletes all JPEG (.jpg) files in the given directory
-- This function scans the target directory and deletes every file with a .jpg extension
local function clearJPEGs(directory)
    for file in LrFileUtils.files(directory) do
        -- Check if file has ".jpg" extension (case-insensitive)
        if string.lower(LrPathUtils.extension(file)) == "jpg" then
            LrFileUtils.delete(file)  -- Delete the file
            logger.logMessage(LOC("$$$/iNat/Log/JPGDeleted=JPG file deleted: ") .. file)
        end
    end
end

-- Returns the first JPEG file found in the directory
-- Used to retrieve the image file that was just exported
local function findSingleJPEG(directory)
    for file in LrFileUtils.files(directory) do
        -- Return the first file with a .jpg extension (case-insensitive)
        if string.lower(LrPathUtils.extension(file)) == "jpg" then
            return file
        end
    end
    return nil  -- No JPG file found
end

-- Export functions for use in other modules
return {
    clearJPEGs = clearJPEGs,           -- Function to delete all JPEGs in a folder
    findSingleJPEG = findSingleJPEG    -- Function to return the first found JPEG
}
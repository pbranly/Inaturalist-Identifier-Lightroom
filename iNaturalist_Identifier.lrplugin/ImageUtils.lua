--[[
=====================================================================================
 Module  : imageutils.lua
 Purpose : Utility functions for managing JPEG image files in a directory
 Author  : Philippe Branly (or your name)
 Description :
 This module provides helper functions used by the Lightroom iNaturalist plugin 
 to manage temporary JPEG image files. It is primarily used by the `export_to_tempo.lua`
 module to clean up old files and locate the newly exported image.

 Functions:
   - clearJPEGs(directory): Deletes all .jpg files in the specified directory.
   - findSingleJPEG(directory): Returns the first .jpg file found in the directory.

 These functions are used to maintain a clean export folder and ensure the correct
 file is passed to the iNaturalist API after Lightroom exports a photo.

 Dependencies:
   - Lightroom SDK: LrFileUtils, LrPathUtils
   - Logger.lua: for logging deleted files

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

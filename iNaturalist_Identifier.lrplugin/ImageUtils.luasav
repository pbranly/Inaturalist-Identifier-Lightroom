--[[
============================================================
Functional Description
------------------------------------------------------------
This module `ImageUtils.lua` provides utilities for managing
JPEG files in a given directory.

Main functionalities:
1. Delete all JPEG (.jpg) files in a folder.
2. Find and return the first JPEG file present in a folder.

These functions are mainly used to manage temporary images
exported by the plugin.

------------------------------------------------------------
Numbered Steps
1. Import the necessary Lightroom modules for file handling.
2. Import the custom logging module.
3. Define the clearJPEGs function to delete all .jpg files in a folder.
4. Define the findSingleJPEG function to locate a JPEG file in a folder.
5. Export the functions for external use.

------------------------------------------------------------
Called Scripts
- Logger.lua (for logging file deletions)

------------------------------------------------------------
Calling Script
- AnimalIdentifier.lua (especially for cleanup before export)
============================================================
]]

-- [Step 1] Import Lightroom utilities for file and path handling
local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"

-- [Step 2] Import custom logger
local logger = require("Logger")

-- [Step 3] Deletes all JPEG (.jpg) files in the given directory
local function clearJPEGs(directory)
    for file in LrFileUtils.files(directory) do
        if string.lower(LrPathUtils.extension(file)) == "jpg" then
            LrFileUtils.delete(file)
            logger.logMessage("JPG file deleted: " .. file)
        end
    end
end

-- [Step 4] Returns the first JPEG file found in the directory
local function findSingleJPEG(directory)
    for file in LrFileUtils.files(directory) do
        if string.lower(LrPathUtils.extension(file)) == "jpg" then
            return file
        end
    end
    return nil
end

-- [Step 5] Export functions for external use
return {
    clearJPEGs = clearJPEGs,
    findSingleJPEG = findSingleJPEG
}

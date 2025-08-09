-- Import Lightroom utilities for file and path handling
local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"

-- Import custom logger
local logger = require("Logger")

-- Deletes all JPEG (.jpg) files in the given directory
local function clearJPEGs(directory)
    for file in LrFileUtils.files(directory) do
        if string.lower(LrPathUtils.extension(file)) == "jpg" then
            LrFileUtils.delete(file)
            logger.logMessage(LOC("$$$/iNat/Log/JPGDeleted=JPG file deleted: ") .. file)
        end
    end
end

-- Returns the first JPEG file found in the directory
local function findSingleJPEG(directory)
    for file in LrFileUtils.files(directory) do
        if string.lower(LrPathUtils.extension(file)) == "jpg" then
            return file
        end
    end
    return nil
end

-- Export functions
return {
    clearJPEGs = clearJPEGs,
    findSingleJPEG = findSingleJPEG
}

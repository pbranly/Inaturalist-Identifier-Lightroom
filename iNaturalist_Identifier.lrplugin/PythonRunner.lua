-- Lightroom SDK import for path utilities
local LrPathUtils = import "LrPathUtils"

-- Custom logger module
local logger = require("Logger")

-- Runs a Python script that performs identification
-- Parameters:
--   pythonScript: full path to the Python script
--   imagePath: full path to the exported image
--   token: iNaturalist authentication token
-- Returns:
--   result: output from the Python script (string)
local function runPythonIdentifier(pythonScript, imagePath, token)
    -- Construct the command string to run the script with arguments
    local command = string.format('python "%s" "%s" "%s"', pythonScript, imagePath, token)
    logger.logMessage("Command: " .. command)

    -- Execute the command and capture its output
    local handle = io.popen(command, "r")
    local result = handle:read("*a")
    handle:close()

    -- Return the output or an empty string if nil
    return result or ""
end

-- Export the function for external use
return {
    runPythonIdentifier = runPythonIdentifier
}

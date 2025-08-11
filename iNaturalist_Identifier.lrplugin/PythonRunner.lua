--[[
============================================================
Functional Description
------------------------------------------------------------
This module `PythonRunner.lua` allows executing an external 
Python script to identify an animal from an exported image.

Main features:
1. Build a shell command to run the Python script
   with the required arguments (script path, image path,
   and authentication token).
2. Execute the command and capture its standard output.
3. Return the result (output of the Python script) for further
   processing in the plugin.

------------------------------------------------------------
Numbered Steps
1. Import the Lightroom module for path management.
2. Import the custom logging module.
3. Define the function runPythonIdentifier which:
    3.1. Builds the shell command.
    3.2. Logs the command.
    3.3. Executes the command while capturing its output.
    3.4. Returns the result or an empty string.
4. Export the function for external usage.

------------------------------------------------------------
Called scripts
- Logger.lua (for logging the executed command)

------------------------------------------------------------
Calling script
- AnimalIdentifier.lua via the main module (main.lua)
============================================================
]]

-- [Step 1] Lightroom SDK import for path utilities
local LrPathUtils = import "LrPathUtils"

-- [Step 2] Custom logger module
local logger = require("Logger")

-- [Step 3] Runs a Python script that performs identification
-- Parameters:
--   pythonScript: full path to the Python script
--   imagePath: full path to the exported image
--   token: iNaturalist authentication token
-- Returns:
--   result: output from the Python script (string)
local function runPythonIdentifier(pythonScript, imagePath, token)
    -- [3.1] Construct the command string to run the script with arguments
    local command = string.format('python "%s" "%s" "%s"', pythonScript, imagePath, token)
    -- [3.2] Log the command
    logger.logMessage("Command: " .. command)

    -- [3.3] Execute the command and capture its output
    local handle = io.popen(command, "r")
    local result = handle:read("*a")
    handle:close()

    -- [3.4] Return the output or an empty string if nil
    return result or ""
end

-- [Step 4] Export the function for external use
return {
    runPythonIdentifier = runPythonIdentifier
}

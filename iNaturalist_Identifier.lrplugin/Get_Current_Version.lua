--[[
=====================================================================
Functional Description
---------------------------------------------------------------------
This module retrieves the current installed plugin version by reading
the version numbers from `PluginVersion.lua`.  
It formats the version into a human-readable string (`major.minor.revision`)
and exposes it through a simple API.

=====================================================================
Modules and Scripts Used
---------------------------------------------------------------------
- Internal Modules:
    * PluginVersion.lua  → Holds the numeric version components of the plugin.
    * Logger.lua         → Handles log messages (added for debugging/tracing).

=====================================================================
Scripts That Use This Script
---------------------------------------------------------------------
- Any script that needs to display or compare the current plugin version:
    * Plugin Manager dialog UI scripts.
    * Update/version check scripts (e.g. Get_Version_Github.lua).

=====================================================================
Execution Steps
---------------------------------------------------------------------
Step 1: Import `PluginVersion.lua`.
Step 2: Import `Logger.lua` for debug logging.
Step 3: Read `major`, `minor`, and `revision` values from `PluginVersion`.
Step 4: Convert the numeric values into a formatted string "X.Y.Z".
Step 5: Return a table exposing:
         - `getCurrentVersion()` function
         - `versionString` constant

=====================================================================
Step-by-Step Detailed Descriptions
---------------------------------------------------------------------
1. Load the module containing the numeric plugin version components.
2. Load the logger to allow detailed tracing.
3. Extract the version numbers from the `PluginVersion` table.
4. Build the version string in "major.minor.revision" format.
5. Make the version available to other scripts via the returned API.

=====================================================================
]]

local LOC = function(msg) return msg end -- Simple placeholder for Lightroom localization

-- Step 1: Import plugin version data
local PluginVersion = require("PluginVersion")

-- Step 2: Import logger
local logger = require("Logger")
logger.logMessage("[Step 1] Imported PluginVersion.lua")
logger.logMessage("[Step 2] Logger initialized in Get_Current_Version.lua")

-- Step 3: Extract numeric values
local major    = tonumber(PluginVersion.major) or 0
local minor    = tonumber(PluginVersion.minor) or 0
local revision = tonumber(PluginVersion.revision) or 0
logger.logMessage(string.format("[Step 3] Extracted version numbers: major=%d, minor=%d, revision=%d", major, minor, revision))

-- Step 4: Build formatted version string
local currentVersion = string.format("%d.%d.%d", major, minor, revision)
logger.logMessage("[Step 4] Built version string: " .. currentVersion)

-- Step 5: Return API table
logger.logMessage("[Step 5] Returning current version API table.")
return {
    getCurrentVersion = function()
        logger.logMessage("getCurrentVersion() called, returning: " .. currentVersion)
        return currentVersion
    end,
    versionString = currentVersion
}

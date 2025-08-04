--[[
=====================================================================================
 Script : Logger.lua
 Purpose : Centralized logging utility for the Lightroom plugin
 Author  : Philippe (or your name here)
 Description :
 This module provides functions to handle logging for the plugin's operations.
 It is used to create, write to, and display messages from a `log.txt` file stored 
 in the plugin’s folder. Logging can be enabled or disabled using a plugin preference.

 Main Functions:
   - initializeLogFile(): Creates and starts the log file at plugin launch.
   - logMessage(msg): Appends timestamped messages to the log file.
   - notify(msg): Logs a message and displays it to the user via a dialog box.

 The logger helps in debugging and tracing plugin behavior without affecting Lightroom’s UI.

 Dependencies:
 - Lightroom SDK: LrPrefs for preferences, LrDialogs for alerts, LrPathUtils for paths.

=====================================================================================
--]]

-- Lightroom API imports
local LrPathUtils = import "LrPathUtils"
local LrDialogs  = import "LrDialogs"
local LrPrefs    = import "LrPrefs"

-- Access plugin-specific preferences
local prefs = LrPrefs.prefsForPlugin()

-- Returns the absolute path to the log file
local function getLogFilePath()
    return LrPathUtils.child(_PLUGIN.path, "log.txt")
end

-- Initializes the log file (if logging is enabled in preferences)
local function initializeLogFile()
    if prefs.logEnabled then
        local f = io.open(getLogFilePath(), "w") -- overwrite at each launch
        if f then
            local timestamp = os.date("[%Y-%m-%d %H:%M:%S] ")
            f:write(timestamp .. LOC("$$$/iNat/Log/PluginStarted=== Plugin launched ===") .. "\n")
            f:close()
        end
    end
end

-- Writes a message to the log (if logging is enabled)
local function logMessage(message)
    if prefs.logEnabled then
        local f = io.open(getLogFilePath(), "a") -- append mode
        if f then
            local timestamp = os.date("[%Y-%m-%d %H:%M:%S] ")
            f:write(timestamp .. message .. "\n")
            f:close()
        end
    end
end

-- Shows a message to the user and logs it if enabled
local function notify(message)
    logMessage(message)
    LrDialogs.message(message)
end

-- Exported functions
return {
    initializeLogFile = initializeLogFile,
    logMessage         = logMessage,
    notify             = notify
}
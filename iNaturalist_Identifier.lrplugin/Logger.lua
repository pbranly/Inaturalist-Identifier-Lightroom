--[[
=====================================================================================
 Script   : Logger.lua
 Purpose  : Simple logging utility for Lightroom plugin debugging.
 Author   : Philippe

 Description :
 ------------
 Handles writing timestamped log messages to a file in the plugin folder.
 Can be enabled/disabled via plugin preferences.

 Features :
 ----------
 - Overwrites log file on each plugin launch (initializeLogFile).
 - Appends all log messages with a timestamp.
 - Optional debug mode (prefs.logDebug) logs:
     * Milliseconds precision (if OS supports)
     * Thread name
     * Call stack (debug.traceback)
 - `notify()` will both log and show a Lightroom dialog.

 Preferences:
 ------------
 prefs.logEnabled : boolean - Enable/disable logging.
 prefs.logDebug   : boolean - Enable/disable detailed debug info.

=====================================================================================
--]]

-- Lightroom API imports
local LrPathUtils = import "LrPathUtils"
local LrDialogs  = import "LrDialogs"
local LrPrefs    = import "LrPrefs"

-- Access plugin-specific preferences
local prefs = LrPrefs.prefsForPlugin()

--------------------------------------------------------------------------------
-- Internal: build timestamp (with optional ms)
--------------------------------------------------------------------------------
local function getTimestamp()
    local base = os.date("[%Y-%m-%d %H:%M:%S")
    -- Try milliseconds if available
    local ms
    if debug and debug.sethook then
        local socket_ok, socket = pcall(require, "socket")
        if socket_ok and socket.gettime then
            local t = socket.gettime()
            ms = math.floor((t * 1000) % 1000)
        end
    end
    if ms then
        return string.format("%s.%03d] ", base, ms)
    else
        return base .. "] "
    end
end

--------------------------------------------------------------------------------
-- Internal: return absolute path to log file
--------------------------------------------------------------------------------
local function getLogFilePath()
    return LrPathUtils.child(_PLUGIN.path, "log.txt")
end

--------------------------------------------------------------------------------
-- Initialize log file (overwrite each launch)
--------------------------------------------------------------------------------
local function initializeLogFile()
    if prefs.logEnabled then
        local f = io.open(getLogFilePath(), "w")
        if f then
            f:write(getTimestamp() .. "=== Plugin launched ===\n")
            f:close()
        end
    end
end

--------------------------------------------------------------------------------
-- Write a message to the log file
--------------------------------------------------------------------------------
local function logMessage(message, includeTrace)
    if prefs.logEnabled then
        local f = io.open(getLogFilePath(), "a")
        if f then
            local ts = getTimestamp()
            f:write(ts .. message .. "\n")
            -- If debug mode enabled, add thread + stack trace
            if prefs.logDebug then
                local threadName = tostring(coroutine.running())
                f:write(ts .. "[DEBUG] Thread: " .. threadName .. "\n")
                if includeTrace then
                    f:write(ts .. "[DEBUG] Stack:\n" .. debug.traceback("", 2) .. "\n")
                end
            end
            f:close()
        end
    end
end

--------------------------------------------------------------------------------
-- Show Lightroom dialog + log
--------------------------------------------------------------------------------
local function notify(message)
    logMessage(message)
    LrDialogs.message(message)
end

--------------------------------------------------------------------------------
-- Exported API
--------------------------------------------------------------------------------
return {
    initializeLogFile = initializeLogFile,
    logMessage        = logMessage,
    notify            = notify,
    getLogFilePath    = getLogFilePath
}

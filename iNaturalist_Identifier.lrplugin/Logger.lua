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

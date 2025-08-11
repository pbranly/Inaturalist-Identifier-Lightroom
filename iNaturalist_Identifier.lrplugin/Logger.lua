--[[
============================================================
Functional Description
------------------------------------------------------------
This `logger.lua` module handles logging for the plugin.
It allows:
1. Determining the location of the log file.
2. Initializing the log file at plugin startup.
3. Adding timestamped messages to the log file.
4. Displaying messages to the user while also recording them.

Logging is controlled by the `logEnabled` plugin preference.

------------------------------------------------------------
Numbered Steps
1. Import the necessary Lightroom SDK modules.
2. Access plugin-specific preferences.
3. Define a function to return the path to the log file.
4. Define a function to initialize the log file.
5. Define a function to write a message to the log file.
6. Define a function to display a message and log it.
7. Export the module’s functions.

------------------------------------------------------------
Called Scripts
- No external Lua scripts (Lightroom SDK API only).

------------------------------------------------------------
Calling Script
- Called by `AnimalIdentifier.lua` and potentially other modules
  to record logs.
============================================================
]]

-- [Step 1] Lightroom API imports
local LrPathUtils = import "LrPathUtils"
local LrDialogs  = import "LrDialogs"
local LrPrefs    = import "LrPrefs"

-- [Step 2] Access plugin-specific preferences
local prefs = LrPrefs.prefsForPlugin()

-- [Step 3] Returns the absolute path to the log file
local function getLogFilePath()
    return LrPathUtils.child(_PLUGIN.path, "log.txt")
end

-- [Step 4] Initializes the log file (if logging is enabled in preferences)
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

-- [Step 5] Writes a message to the log (if logging is enabled)
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

-- [Step 6] Shows a message to the user and logs it if enabled
local function notify(message)
    logMessage(message)
    LrDialogs.message(message)
end

-- [Step 7] Exported functions
return {
    initializeLogFile = initializeLogFile,
    logMessage         = logMessage,
    notify             = notify
}

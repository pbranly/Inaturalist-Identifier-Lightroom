--[[
============================================================
Functional Description
------------------------------------------------------------
This `logger.lua` module handles logging for the plugin.
It allows:
1. Determining the location of the log file.
2. Initializing the log file at plugin startup.
3. Adding timestamped messages to the log file with the caller script name (auto-detected).
4. Displaying messages to the user while also recording them.
5. Inserting a header the first time a script writes to the log.

Logging is controlled by the `logEnabled` plugin preference.

============================================================
]]

-- [Step 1] Lightroom API imports
local LrPathUtils = import "LrPathUtils"
local LrDialogs  = import "LrDialogs"
local LrPrefs    = import "LrPrefs"

-- [Step 2] Access plugin-specific preferences
local prefs = LrPrefs.prefsForPlugin()

-- Keep track of which scripts have already written to the log
local initializedScripts = {}

-- [Step 3] Returns the absolute path to the log file
local function getLogFilePath()
    return LrPathUtils.child(_PLUGIN.path, "log.txt")
end

-- [Step 4] Detect caller script name using debug info
local function getCallerScriptName()
    local info = debug.getinfo(3, "S")  -- 3 = up the stack
    if info and info.source then
        local src = info.source:gsub("^@", "")
        return LrPathUtils.leafName(src) or "UnknownScript"
    end
    return "UnknownScript"
end

-- [Step 5] Initializes the log file (if logging is enabled in preferences)
local function initializeLogFile()
    if prefs.logEnabled then
        local f = io.open(getLogFilePath(), "w") -- overwrite at each launch
        if f then
            local timestamp = os.date("[%Y-%m-%d %H:%M:%S] ")
            f:write(timestamp .. LOC("$$$/iNat/Log/PluginStarted=== Plugin launched ===") .. "\n")
            f:close()
        end
        initializedScripts = {} -- reset script tracking at startup
    end
end

-- [Step 6] Writes a message to the log (if logging is enabled)
local function logMessage(message)
    if prefs.logEnabled then
        local scriptName = getCallerScriptName()
        local f = io.open(getLogFilePath(), "a") -- append mode
        if f then
            -- If this script writes for the first time, add a header
            if not initializedScripts[scriptName] then
                f:write("=== Logging started for " .. scriptName .. " ===\n")
                initializedScripts[scriptName] = true
            end

            local timestamp = os.date("[%Y-%m-%d %H:%M:%S] ")
            f:write(timestamp .. "[" .. scriptName .. "] " .. message .. "\n")
            f:close()
        end
    end
end

-- [Step 7] Shows a message to the user and logs it if enabled
local function notify(message)
    local scriptName = getCallerScriptName()
    logMessage(message)
    LrDialogs.message("[" .. scriptName .. "] " .. message)
end

-- [Step 8] Exported functions
return {
    initializeLogFile = initializeLogFile,
    logMessage        = logMessage,
    notify            = notify
}

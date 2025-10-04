--[[
============================================================
Functional Description
------------------------------------------------------------
This `logger.lua` module handles logging for the iNaturalist
Identifier Lightroom plugin. It provides detailed logging
and user notifications for all scripts in the plugin.
Main Features:
1. Determine the location of the log file.
2. Initialize the log file at plugin startup.
3. Add timestamped messages to the log with the caller script name auto-detected.
4. Insert a header the first time a script writes to the log.
5. Display messages to the user while also recording them.
6. Logging is entirely controlled by the `logEnabled` plugin preference.
Modules and Scripts Used:
- LrPathUtils
- LrDialogs
- LrPrefs
- Lua `debug` library
Calling Scripts:
- AnimalIdentifier.lua
- selectAndTagResults.lua
- VerificationToken.lua
- Updates.lua
- Any other plugin script needing logging
============================================================
Numbered Steps
1. Import Lightroom SDK modules and Lua debug library.
2. Access plugin-specific preferences.
3. Maintain a list of scripts that already wrote to the log.
4. Provide a function to return the absolute path to the log file.
5. Detect the caller script name automatically.
6. Initialize the log file at plugin startup.
7. Write a message to the log including timestamp and script name.
8. Display a message to the user and log it.
9. Export the module functions.
============================================================
Step Descriptions in English
------------------------------------------------------------
Step 1: Import Lightroom SDK modules and Lua debug library.
  - LrPathUtils for path operations
  - LrDialogs for user messages
  - LrPrefs for plugin preferences
  - debug for detecting caller script
Step 2: Access plugin-specific preferences to check if logging is enabled.
Step 3: Initialize a table to track which scripts have already logged messages.
  This ensures headers are added only once per script.
Step 4: Provide a function `getLogFilePath()` to determine the absolute
  path of `log.txt` inside the plugin folder.
Step 5: Provide a function `getCallerScriptName()` using Lua debug stack
  inspection to detect which script is calling the logger.
Step 6: Initialize the log file at plugin startup with a timestamped
  “Plugin launched” entry. Reset script tracking.
Step 7: Write messages to the log with timestamp, caller script name,
  and insert a header if this script writes for the first time.
Step 8: Display a message to the user and log it. The screen message
  is internationalized using a base English form.
Step 9: Export functions `initializeLogFile`, `logMessage`, and `notify`
  for use by other scripts in the plugin.
============================================================
Logging Notes
------------------------------------------------------------
- All log messages are exclusively in English.
- Caller script names are automatically detected.
- Headers are written once per script.
- Timestamp format: [YYYY-MM-DD HH:MM:SS]
- Messages displayed on-screen are internationalized with LOC,
  e.g., LOC("$$$/iNat/PluginName=iNaturalist Identification")
============================================================
]]
-- Step 1: Lightroom API imports
local LrPathUtils = import "LrPathUtils"
local LrDialogs  = import "LrDialogs"
local LrPrefs    = import "LrPrefs"
-- Lua debug library is used for caller detection
local debug = debug
-- Step 2: Access plugin-specific preferences
local prefs = LrPrefs.prefsForPlugin()
-- Step 3: Keep track of scripts that already wrote to the log
local initializedScripts = {}
-- Step 4: Returns the absolute path to the log file
local function getLogFilePath()
    return LrPathUtils.child(_PLUGIN.path, "log.txt")
end
-- Step 5: Detect caller script name automatically
local function getCallerScriptName()
    local info = debug.getinfo(3, "S")  -- 3 = caller up the stack
    if info and info.source then
        local src = info.source:gsub("^@", "")
        return LrPathUtils.leafName(src) or "UnknownScript"
    end
    return "UnknownScript"
end
-- Step 6: Initialize the log file (if logging is enabled)
local function initializeLogFile()
    if prefs.logEnabled then
        local f = io.open(getLogFilePath(), "w") -- overwrite at each launch
        if f then
            local timestamp = os.date("[%Y-%m-%d %H:%M:%S] ")
            f:write(timestamp .. LOC("$$$/iNat/Log/PluginStarted=== Plugin launched ===") .. "\n")
            f:close()
        end
        initializedScripts = {} -- reset script tracking
    end
end
-- Step 7: Write a message to the log (if logging is enabled)
local function logMessage(message)
    if prefs.logEnabled then
        local scriptName = getCallerScriptName()
        local f = io.open(getLogFilePath(), "a") -- append mode
        if f then
            -- Add header if first log from this script
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
-- Step 8: Show a message to the user and log it
local function notify(message)
    local scriptName = getCallerScriptName()
    logMessage(message)
    LrDialogs.message(LOC("$$$/iNat/PluginName=iNaturalist Identification"), "[" .. scriptName .. "] " .. message)
end
-- Step 9: Exported functions
return {
    initializeLogFile = initializeLogFile,
    logMessage        = logMessage,
    notify            = notify
}

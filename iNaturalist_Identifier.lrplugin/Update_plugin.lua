--------------------------------------------------------------------------------
-- iNaturalist Lightroom Plugin Updater
-- Functional Description:
-- This script checks for the latest release of the iNaturalist Identifier
-- Lightroom plugin on GitHub, downloads the corresponding source ZIP,
-- renames the current plugin directory with its version number as a suffix,
-- extracts the new version into place, and cleans up the ZIP archive.
-- It provides detailed logging for each step using logger.lua and displays
-- messages to the user in English international format.
--
-- Modules used:
--   logger.lua       -- Logging
--   Info.lua         -- Current plugin version
--   LrPrefs          -- Plugin preferences
--   LrDialogs        -- Display dialogs
--   LrFileUtils      -- File operations
--   LrFunctionContext-- Context for asynchronous tasks
--   LrPathUtils      -- Path manipulations
--   LrHttp           -- HTTP requests
--   LrTasks          -- Execute shell commands
--   json             -- JSON parsing
--
-- Scripts that use this updater:
--   AnimalIdentifier.lua
--   Other plugin modules that need to check for updates
--
-- Steps:
--   1. Retrieve latest release metadata from GitHub
--   2. Construct the download URL for the release ZIP
--   3. Download the ZIP into the parent directory of the plugin
--   4. Rename the existing plugin directory with its version number
--   5. Extract the ZIP into the parent directory
--   6. Keep only the "iNaturalist_Identifier.lrplugin" directory from the archive
--   7. Delete the ZIP archive
--   8. Display update messages to the user
--------------------------------------------------------------------------------

local logger = require("logger") -- logger.lua
local prefs = import("LrPrefs").prefsForPlugin()
local LrDialogs = import("LrDialogs")
local LrFileUtils = import("LrFileUtils")
local LrFunctionContext = import("LrFunctionContext")
local LrPathUtils = import("LrPathUtils")
local LrHttp = import("LrHttp")
local LrTasks = import("LrTasks")
local Info = require("Info")
local json = require("json")

local Updates = {
    baseUrl = "https://api.github.com/",
    repo = "pbranly/Inaturalist-Identifier-Lightroom",
    actionPrefKey = "doNotShowUpdatePrompt",
}

--------------------------------------------------------------------------------
-- Step 1: Get latest release metadata
--------------------------------------------------------------------------------
local function getLatestVersion()
    local url = Updates.baseUrl .. "repos/" .. Updates.repo .. "/releases/latest"
    local headers = {
        { field = "User-Agent", value = Updates.repo .. "/" .. Updates.version() },
        { field = "X-GitHub-Api-Version", value = "2022-11-28" },
    }
    logger.logMessage("[Step 1] Sending GET request to GitHub API: " .. url)
    local data, respHeaders = LrHttp.get(url, headers)
    if respHeaders.error or respHeaders.status ~= 200 then
        logger.logMessage("[Step 1] ERROR: GitHub API request failed: " .. tostring(respHeaders.status))
        return nil
    end
    logger.logMessage("[Step 1] GitHub API response: " .. data)
    local success, release = pcall(json.decode, data)
    if not success then
        logger.logMessage("[Step 1] ERROR: Failed to decode GitHub JSON response")
        return nil
    end
    logger.logMessage("[Step 1] Found latest release: " .. release.tag_name)
    return release
end

--------------------------------------------------------------------------------
-- Step 2: Construct the source ZIP URL
--------------------------------------------------------------------------------
local function findSourceZipAsset(release)
    if not release or not release.tag_name then
        logger.logMessage("[Step 2] ERROR: Release or tag_name missing")
        return nil
    end
    local url = "https://github.com/pbranly/Inaturalist-Identifier-Lightroom/archive/refs/tags/"
                .. release.tag_name .. ".zip"
    logger.logMessage("[Step 2] Constructed source zip URL: " .. url)
    return url
end

--------------------------------------------------------------------------------
-- Step 3: Download ZIP into plugin parent directory
--------------------------------------------------------------------------------
local function downloadZip(url, zipPath)
    logger.logMessage("[Step 3] Downloading ZIP from: " .. url)
    local data, headers = LrHttp.get(url)
    if headers.error then
        logger.logMessage("[Step 3] ERROR: Download failed: " .. tostring(headers.error))
        return false
    end
    local f = io.open(zipPath, "wb")
    if not f then
        logger.logMessage("[Step 3] ERROR: Cannot open file for writing: " .. zipPath)
        return false
    end
    f:write(data)
    f:close()
    logger.logMessage("[Step 3] ZIP successfully downloaded to: " .. zipPath)
    return true
end

--------------------------------------------------------------------------------
-- Step 4: Rename current plugin directory with version suffix
--------------------------------------------------------------------------------
local function backupCurrentPlugin(pluginPath)
    local v = Updates.version()
    local backupPath = pluginPath .. "-" .. v
    logger.logMessage("[Step 4] Renaming current plugin: " .. pluginPath .. " → " .. backupPath)
    local ok = LrFileUtils.move(pluginPath, backupPath)
    if not ok then
        logger.logMessage("[Step 4] ERROR: Could not rename current plugin")
        return nil
    end
    return backupPath
end

--------------------------------------------------------------------------------
-- Step 5 & 6: Extract ZIP and keep only plugin directory
--------------------------------------------------------------------------------
local function extractZip(zipPath, parentDir)
    logger.logMessage("[Step 5] Extracting ZIP into: " .. parentDir)
    local cmd = "unzip -o " .. '"' .. zipPath .. '"' .. " -d " .. '"' .. parentDir .. '"'
    logger.logMessage("[Step 5] Executing: " .. cmd)
    local ret = LrTasks.execute(cmd)
    if ret ~= 0 then
        logger.logMessage("[Step 5] ERROR: Could not extract ZIP file")
        return false
    end
    for path in LrFileUtils.directoryEntries(parentDir) do
        if path:find("Inaturalist%-Identifier%-Lightroom%-") then
            local pluginDir = LrPathUtils.child(path, "iNaturalist_Identifier.lrplugin")
            if LrFileUtils.exists(pluginDir) then
                logger.logMessage("[Step 6] Found plugin directory: " .. pluginDir)
                local finalPath = LrPathUtils.child(parentDir, "iNaturalist_Identifier.lrplugin")
                logger.logMessage("[Step 6] Moving new plugin into place: " .. finalPath)
                LrFileUtils.move(pluginDir, finalPath)
                LrFileUtils.delete(path)
                return true
            end
        end
    end
    logger.logMessage("[Step 6] ERROR: Plugin directory not found in extracted ZIP")
    return false
end

--------------------------------------------------------------------------------
-- Step 7: Delete ZIP archive
--------------------------------------------------------------------------------
local function cleanup(zipPath)
    logger.logMessage("[Step 7] Deleting ZIP file: " .. zipPath)
    LrFileUtils.delete(zipPath)
end

--------------------------------------------------------------------------------
-- Step 8: Orchestrate update
--------------------------------------------------------------------------------
local function downloadAndInstall(ctx, release)
    local pluginPath = _PLUGIN.path
    local parentDir = LrPathUtils.parent(pluginPath)
    local zipPath = LrPathUtils.child(parentDir, "download.zip")
    local url = findSourceZipAsset(release)
    if not url then return end
    if not downloadZip(url, zipPath) then return end
    if not backupCurrentPlugin(pluginPath) then return end
    if not extractZip(zipPath, parentDir) then return end
    cleanup(zipPath)
    LrDialogs.message(LOC("$$$/iNat/UpdateComplete=iNaturalist Identifier updated"),
                      LOC("$$$/iNat/RestartLightroom=Please restart Lightroom to complete installation"),
                      "info")
end

--------------------------------------------------------------------------------
-- Version helper
--------------------------------------------------------------------------------
function Updates.version()
    local v = Info.VERSION
    return string.format("%s.%s.%s", v.major, v.minor, v.revision)
end

--------------------------------------------------------------------------------
-- Check for update
--------------------------------------------------------------------------------
function Updates.check(force)
    local current = Updates.version()
    logger.logMessage("Running version " .. (Info.VERSION.display or current))
    if not force and not prefs.checkForUpdates then return end
    local latest = getLatestVersion()
    if not latest then return end
    local currentNorm = current:gsub("^v", "")
    local latestNorm = latest.tag_name and latest.tag_name:gsub("^v", "") or ""
    if currentNorm ~= latestNorm then
        logger.logMessage("Offering update from " .. current .. " to " .. latest.tag_name)
        LrFunctionContext.callWithContext("downloadAndInstall", downloadAndInstall, latest)
        return
    end
    return current
end

--------------------------------------------------------------------------------
-- Force update
--------------------------------------------------------------------------------
function Updates.forceUpdate()
    LrTasks.startAsyncTask(function()
        local v = Updates.check(true)
        if v then
            LrDialogs.message(
                LOC("$$$/iNat/NoUpdates=No updates available"),
                string.format(LOC("$$$/iNat/MostRecent=You have the most recent version of the iNaturalist Identifier Plugin, %s"), v),
                "info"
            )
        end
    end)
end

return Updates

--[[
============================================================
iNaturalist Lightroom Plugin Updater (Cross-Platform)
------------------------------------------------------------
Functional Description:
This script securely updates the iNaturalist Identifier Lightroom plugin
by downloading the latest plugin ZIP from GitHub and replacing the existing
plugin while keeping a backup copy of the old version.

Modules and Scripts Used:
- LrPrefs
- LrDialogs
- LrFileUtils
- LrFunctionContext
- LrPathUtils
- LrHttp
- LrTasks
- Logger.lua
- Info.lua
- json.lua

Calling Scripts:
- AnimalIdentifier.lua
- PluginInfoProvider.lua

Numbered Steps:
1. Retrieve latest release metadata from GitHub
2. Identify the plugin ZIP asset in the release
3. Download the plugin ZIP to a temporary location
4. Extract the plugin ZIP into a temporary folder
5. Backup current plugin
6. Remove old plugin
7. Install new plugin
8. Cleanup temporary files
============================================================
]]

local logger = require("Logger")
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
}

------------------------------------------------------------
-- Step 1: Get latest release metadata from GitHub
------------------------------------------------------------
local function getLatestRelease()
    local url = Updates.baseUrl .. "repos/" .. Updates.repo .. "/releases/latest"
    local headers = {
        { field = "User-Agent", value = Updates.repo .. "/" .. Updates.version() },
        { field = "X-GitHub-Api-Version", value = "2022-11-28" },
    }
    logger.logMessage("[Step 1] Sending GET request to GitHub API: " .. url)
    local data, respHeaders = LrHttp.get(url, headers)
    if respHeaders.error or respHeaders.status ~= 200 then
        logger.logMessage("[Step 1] ERROR: GitHub API request failed, status: " .. tostring(respHeaders.status))
        LrDialogs.message(LOC("$$$/iNat/PluginName=iNaturalist Identification"),
                          "ERROR: Failed to retrieve latest release metadata from GitHub.",
                          "critical")
        return nil
    end
    logger.logMessage("[Step 1] GitHub response received, decoding JSON")
    local success, release = pcall(json.decode, data)
    if not success then
        logger.logMessage("[Step 1] ERROR: Failed to decode GitHub JSON response")
        LrDialogs.message(LOC("$$$/iNat/PluginName=iNaturalist Identification"),
                          "ERROR: Failed to decode GitHub release metadata.",
                          "critical")
        return nil
    end
    logger.logMessage("[Step 1] Latest release found: " .. release.tag_name)
    return release
end

------------------------------------------------------------
-- Step 2: Find plugin ZIP asset in release
------------------------------------------------------------
local function findPluginZipAsset(release)
    if not release or not release.assets then return nil end
    for _, asset in ipairs(release.assets) do
        if asset.name:match("^iNaturalist_Identifier%.lrplugin") and asset.name:match("%.zip$") then
            logger.logMessage("[Step 2] Found plugin ZIP asset: " .. asset.name)
            return asset.browser_download_url
        end
    end
    logger.logMessage("[Step 2] ERROR: Plugin ZIP asset not found in release assets")
    return nil
end

------------------------------------------------------------
-- Step 3: Download ZIP
------------------------------------------------------------
local function downloadZip(url, zipPath)
    logger.logMessage("[Step 3] Downloading plugin ZIP from: " .. url)
    local data, headers = LrHttp.get(url)
    if headers.error then
        logger.logMessage("[Step 3] ERROR downloading ZIP: " .. tostring(headers.error))
        LrDialogs.message(LOC("$$$/iNat/PluginName=iNaturalist Identification"),
                          "ERROR: Failed to download plugin ZIP.",
                          "critical")
        return false
    end
    local f = io.open(zipPath, "wb")
    if not f then
        logger.logMessage("[Step 3] ERROR: Cannot write ZIP file to disk: " .. zipPath)
        return false
    end
    f:write(data)
    f:close()
    logger.logMessage("[Step 3] Plugin ZIP successfully downloaded to: " .. zipPath)
    return true
end

------------------------------------------------------------
-- Step 4: Extract ZIP
------------------------------------------------------------
local function shellquote(path)
    return '"' .. path .. '"'
end

local function extractZip(zipPath, tmpDir)
    logger.logMessage("[Step 4] Extracting ZIP to temporary directory: " .. tmpDir)
    LrFileUtils.createAllDirectories(tmpDir)

    local cmd = "tar -xf " .. shellquote(zipPath) .. " -C " .. shellquote(tmpDir)
    logger.logMessage("[Step 4] Executing command: " .. cmd)
    local ret = LrTasks.execute(cmd)
    if ret ~= 0 then
        logger.logMessage("[Step 4] ERROR extracting ZIP, return code: " .. tostring(ret))
        return nil
    end

    local pluginDir = LrPathUtils.child(tmpDir, "iNaturalist_Identifier.lrplugin")
    if LrFileUtils.exists(pluginDir) then
        logger.logMessage("[Step 4] Extracted plugin directory found: " .. pluginDir)
        return pluginDir
    end

    logger.logMessage("[Step 4] ERROR: Plugin directory not found in extracted ZIP")
    return nil
end

------------------------------------------------------------
-- Step 5: Backup current plugin
------------------------------------------------------------
local function backupCurrentPlugin(pluginPath)
    local v = Updates.version()
    local backupPath = pluginPath .. "-" .. v
    logger.logMessage("[Step 5] Creating backup of current plugin: " .. backupPath)
    local ok = LrFileUtils.copy(pluginPath, backupPath)
    if not ok then
        logger.logMessage("[Step 5] ERROR: Failed to backup current plugin")
        return nil
    end
    return backupPath
end

------------------------------------------------------------
-- Step 6 & 7: Replace old plugin with new plugin
------------------------------------------------------------
local function replacePlugin(pluginPath, newPluginPath)
    logger.logMessage("[Step 6] Removing old plugin: " .. pluginPath)
    LrFileUtils.delete(pluginPath)

    logger.logMessage("[Step 7] Installing new plugin")
    local ok = LrFileUtils.move(newPluginPath, pluginPath)
    if not ok then
        logger.logMessage("[Step 7] ERROR: Failed to install new plugin")
        return false
    end
    return true
end

------------------------------------------------------------
-- Step 8: Cleanup temporary files
------------------------------------------------------------
local function cleanup(zipPath, tmpDir)
    logger.logMessage("[Step 8] Cleaning up temporary files")
    if LrFileUtils.exists(zipPath) then LrFileUtils.delete(zipPath) end
    if LrFileUtils.exists(tmpDir) then LrFileUtils.delete(tmpDir) end
end

------------------------------------------------------------
-- Orchestration: Download and install latest plugin
------------------------------------------------------------
local function downloadAndInstall(ctx, release)
    local pluginPath = _PLUGIN.path
    local parentDir = LrPathUtils.parent(pluginPath)
    local zipPath = LrPathUtils.child(parentDir, "download.zip")
    local tmpDir = LrPathUtils.child(LrPathUtils.getStandardFilePath("temp"), "iNatTmp")

    local url = findPluginZipAsset(release)
    if not url then return end
    if not downloadZip(url, zipPath) then return end

    local extractedPlugin = extractZip(zipPath, tmpDir)
    if not extractedPlugin then return end

    if not backupCurrentPlugin(pluginPath) then return end

    if not replacePlugin(pluginPath, extractedPlugin) then return end

    cleanup(zipPath, tmpDir)

    LrDialogs.message(LOC("$$$/iNat/PluginName=iNaturalist Identification"),
                      "iNaturalist Identifier updated. Please restart Lightroom to complete installation.",
                      "info")
end

------------------------------------------------------------
-- Version helpers
------------------------------------------------------------
function Updates.version()
    local v = Info.VERSION
    return string.format("%s.%s.%s", v.major, v.minor, v.revision)
end

function Updates.getCurrentVersion()
    return Updates.version()
end

function Updates.getLatestGitHubVersion()
    local latest = getLatestRelease()
    if latest then return latest.tag_name end
    return nil
end

------------------------------------------------------------
-- Check for updates
------------------------------------------------------------
function Updates.check(force)
    local current = Updates.version()
    logger.logMessage("[Check] Current plugin version: " .. (Info.VERSION.display or current))
    if not force and not prefs.checkForUpdates then return end

    local latest = getLatestRelease()
    if not latest then return end

    local currentNorm = current:gsub("^v", "")
    local latestNorm = latest.tag_name and latest.tag_name:gsub("^v", "") or ""

    if currentNorm ~= latestNorm then
        logger.logMessage("[Check] Update available: " .. current .. " → " .. latest.tag_name)
        LrFunctionContext.callWithContext("downloadAndInstall", downloadAndInstall, latest)
        return
    end

    return current
end

function Updates.forceUpdate()
    LrTasks.startAsyncTask(function()
        local v = Updates.check(true)
        if v then
            LrDialogs.message(LOC("$$$/iNat/PluginName=iNaturalist Identification"),
                              "No updates available. You already have the most recent version (" .. v .. ")",
                              "info")
        end
    end)
end

return Updates

--------------------------------------------------------------------------------
-- iNaturalist Publish Plugin Updater
-- Functional Description (English):
-- This script checks the latest release of the "lr-inaturalist-publish" plugin
-- from GitHub, downloads the "Source code (zip)" file, extracts it, keeps only
-- the "iNaturalist_Identifier.lrplugin" folder, creates a backup of the existing
-- plugin directory ("iNaturalist_Identifier.lrpluginbackup"), and replaces the
-- existing plugin with the new version.
--
-- This updater runs inside the Adobe Lightroom plugin environment.
--
-- Modules used:
--   - logger.lua          : Custom logging utility
--   - LrPrefs             : Lightroom preferences API
--   - LrDialogs           : Lightroom dialog API
--   - LrFileUtils         : Lightroom file operations API
--   - LrFunctionContext   : Lightroom context manager
--   - LrPathUtils         : Lightroom path utilities
--   - LrHttp              : Lightroom HTTP client
--   - LrTasks             : Lightroom task utilities
--   - Info.lua            : Contains plugin version information
--   - json.lua            : JSON encoding/decoding
--
-- Script(s) that use this updater:
--   - Any Lightroom plugin module requiring automatic updates of
--     the iNaturalist Publish Plugin.
--
-- Numbered Steps:
--   1. Check for updates
--   2. Retrieve latest release metadata from GitHub
--   3. Find the "Source code (zip)" asset URL
--   4. Download the zip file to a temporary directory
--   5. Extract the zip content
--   6. Keep only the "iNaturalist_Identifier.lrplugin" folder
--   7. Backup the existing plugin folder
--   8. Replace the plugin with the new version
--------------------------------------------------------------------------------

-- Step 0: Import required modules
local logger = require("logger")  -- Custom logger module
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
    repo = "rcloran/lr-inaturalist-publish",
    actionPrefKey = "doNotShowUpdatePrompt",
}

--------------------------------------------------------------------------------
-- Step 1: Detect platform
--------------------------------------------------------------------------------
local function detectPlatform()
    if WIN_ENV then
        return "windows"
    else
        return "unix"
    end
end

--------------------------------------------------------------------------------
-- Step 2: Retrieve latest release metadata
--------------------------------------------------------------------------------
local function getLatestVersion()
    local url = Updates.baseUrl .. "repos/" .. Updates.repo .. "/releases/latest"
    local headers = {
        { field = "User-Agent", value = Updates.repo .. "/" .. Updates.version() },
        { field = "X-GitHub-Api-Version", value = "2022-11-28" },
    }
    logger.logMessage("[Step 2] Requesting latest release metadata from: " .. url)
    local data, respHeaders = LrHttp.get(url, headers)
    logger.logMessage("[Step 2] HTTP status: " .. tostring(respHeaders.status))
    logger.logMessage("[Step 2] Response body: " .. tostring(data))

    if respHeaders.error or respHeaders.status ~= 200 then
        return
    end

    local success, release = pcall(json.decode, data)
    if not success then
        logger.logMessage("[Step 2] Failed to parse JSON release data")
        return
    end

    logger.logMessage("[Step 2] Found latest release: " .. release.tag_name)
    return release
end

--------------------------------------------------------------------------------
-- Step 3: Find the "Source code (zip)" asset
--------------------------------------------------------------------------------
local function findSourceZipAsset(release)
    for _, asset in ipairs(release.assets or {}) do
        if asset.name and asset.name:match("Source code") then
            logger.logMessage("[Step 3] Found Source code (zip) asset: " .. asset.browser_download_url)
            return asset.browser_download_url
        end
    end
    -- If GitHub doesn't list "Source code" in assets, fallback to tarball_url or zipball_url
    if release.zipball_url then
        logger.logMessage("[Step 3] Fallback to release.zipball_url: " .. release.zipball_url)
        return release.zipball_url
    end
    return nil
end

--------------------------------------------------------------------------------
-- Step 4: Download the zip file
--------------------------------------------------------------------------------
local function download(url, filename)
    logger.logMessage("[Step 4] Downloading from: " .. url)
    local data, headers = LrHttp.get(url)
    logger.logMessage("[Step 4] HTTP status: " .. tostring(headers.status))
    if headers.error or headers.status ~= 200 then
        error("Download failed from URL: " .. url)
    end

    local f = io.open(filename, "wb")
    f:write(data)
    f:close()
    logger.logMessage("[Step 4] File saved to: " .. filename)
end

--------------------------------------------------------------------------------
-- Step 5: Extract zip and keep only target folder
--------------------------------------------------------------------------------
local function extract(filename, workdir)
    local platform = detectPlatform()
    logger.logMessage("[Step 5] Detected platform: " .. platform)
    local cmd
    if platform == "unix" then
        cmd = "tar -C " .. '"' .. workdir .. '"' .. " -xf " .. '"' .. filename .. '"'
    else
        cmd = 'powershell -Command "Expand-Archive -Force ' ..
              '"' .. filename .. '" ' ..
              '"' .. workdir .. '"'
    end
    logger.logMessage("[Step 5] Executing extraction command: " .. cmd)
    local ret = LrTasks.execute(cmd)
    if ret ~= 0 then
        error("Extraction failed on " .. platform .. " platform")
    end

    -- Keep only iNaturalist_Identifier.lrplugin
    local keptFolder = nil
    for path in LrFileUtils.directoryEntries(workdir) do
        if LrFileUtils.isDirectory(path) then
            if path:find("iNaturalist_Identifier%.lrplugin$") then
                logger.logMessage("[Step 5] Keeping plugin folder: " .. path)
                keptFolder = path
            else
                logger.logMessage("[Step 5] Deleting extraneous folder: " .. path)
                LrFileUtils.delete(path)
            end
        elseif LrFileUtils.exists(path) then
            logger.logMessage("[Step 5] Deleting extraneous file: " .. path)
            LrFileUtils.delete(path)
        end
    end

    if not keptFolder then
        error("Plugin folder 'iNaturalist_Identifier.lrplugin' not found in extracted archive")
    end
end

--------------------------------------------------------------------------------
-- Step 6 & 7: Backup old plugin and install new version
--------------------------------------------------------------------------------
local function install(workdir, pluginPath)
    local newPluginPath = LrPathUtils.child(workdir, "iNaturalist_Identifier.lrplugin")
    if not LrFileUtils.exists(newPluginPath) then
        error("Expected plugin folder not found: " .. newPluginPath)
    end

    local backupPath = LrPathUtils.child(LrPathUtils.parent(pluginPath), "iNaturalist_Identifier.lrpluginbackup")

    logger.logMessage("[Step 7] Creating backup of current plugin")
    if LrFileUtils.exists(pluginPath) then
        if LrFileUtils.exists(backupPath) then
            logger.logMessage("[Step 7] Removing old backup: " .. backupPath)
            LrFileUtils.delete(backupPath)
        end
        logger.logMessage("[Step 7] Copying current plugin to backup: " .. backupPath)
        LrFileUtils.copy(pluginPath, backupPath)
    else
        logger.logMessage("[Step 7] No existing plugin found, skipping backup")
    end

    if LrFileUtils.exists(pluginPath) then
        logger.logMessage("[Step 7] Removing existing plugin: " .. pluginPath)
        LrFileUtils.delete(pluginPath)
    end

    logger.logMessage("[Step 8] Installing new plugin from: " .. newPluginPath)
    LrFileUtils.copy(newPluginPath, pluginPath)
end

--------------------------------------------------------------------------------
-- Step 9: Download and install workflow
--------------------------------------------------------------------------------
local function downloadAndInstall(ctx, release)
    local workdir = LrFileUtils.chooseUniqueFileName(_PLUGIN.path)
    ctx:addCleanupHandler(function()
        LrFileUtils.delete(workdir)
    end)
    if not LrFileUtils.createDirectory(workdir) then
        error("Cannot create temporary directory")
    end

    local zip = LrPathUtils.child(workdir, "download.zip")
    local url = findSourceZipAsset(release)
    if not url then
        error("Could not find source zip asset")
    end

    download(url, zip)
    extract(zip, workdir)
    install(workdir, _PLUGIN.path)
end

--------------------------------------------------------------------------------
-- Step 10: Version & update check
--------------------------------------------------------------------------------
function Updates.version()
    local v = Info.VERSION
    return string.format("%s.%s.%s", v.major, v.minor, v.revision)
end

function Updates.check(force)
    local current = "v" .. Updates.version()
    logger.logMessage("[Step 10] Running version: " .. current)

    if not force and not prefs.checkForUpdates then
        return
    end

    local latest = getLatestVersion()
    if not latest then return end

    if current ~= latest.tag_name then
        logger.logMessage("[Step 10] Offering update from " .. current .. " to " .. latest.tag_name)
        LrFunctionContext.callWithContext("downloadAndInstall", downloadAndInstall, latest)
        LrDialogs.message(LOC("$$$/iNat/UpdateComplete=Update complete"), LOC("$$$/iNat/RestartLightroom=Please restart Lightroom"), "info")
    else
        LrDialogs.message(LOC("$$$/iNat/NoUpdates=No updates available"), LOC("$$$/iNat/CurrentVersion=You have the most recent version"), "info")
    end
end

function Updates.forceUpdate()
    LrTasks.startAsyncTask(function()
        Updates.check(true)
    end)
end

return Updates

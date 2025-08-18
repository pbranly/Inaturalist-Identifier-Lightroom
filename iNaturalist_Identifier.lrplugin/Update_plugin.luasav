--------------------------------------------------------------------------------
-- iNaturalist Lightroom Plugin Updater (Windows & cross-platform)
-- Functional Description:
--   This script securely updates the iNaturalist Identifier Lightroom plugin
--   by downloading the latest release from GitHub and replacing the existing
--   plugin while keeping a backup copy of the old version.
--
-- Steps:
--   1. Retrieve latest release metadata from GitHub
--   2. Construct ZIP download URL
--   3. Download ZIP to a temporary location
--   4. Extract the ZIP into a safe temporary folder using 'tar' (Windows/Linux)
--   5. Verify that the plugin directory exists in the extracted files
--   6. Make a backup copy of the current plugin
--   7. Remove the old plugin
--   8. Move the extracted plugin into place
--   9. Cleanup temporary files
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
    logger.logMessage("[1] Sending GET request to GitHub API: " .. url)
    local data, respHeaders = LrHttp.get(url, headers)
    if respHeaders.error or respHeaders.status ~= 200 then
        logger.logMessage("[1] ERROR: GitHub API request failed: " .. tostring(respHeaders.status))
        return nil
    end
    local success, release = pcall(json.decode, data)
    if not success then
        logger.logMessage("[1] ERROR: Failed to decode GitHub JSON response")
        return nil
    end
    logger.logMessage("[1] Latest release found: " .. release.tag_name)
    return release
end

--------------------------------------------------------------------------------
-- Step 2: Construct ZIP URL
--------------------------------------------------------------------------------
local function findSourceZipAsset(release)
    if not release or not release.tag_name then
        return nil
    end
    local url = "https://github.com/pbranly/Inaturalist-Identifier-Lightroom/archive/refs/tags/"
                .. release.tag_name .. ".zip"
    logger.logMessage("[2] Constructed ZIP URL: " .. url)
    return url
end

--------------------------------------------------------------------------------
-- Step 3: Download ZIP
--------------------------------------------------------------------------------
local function downloadZip(url, zipPath)
    logger.logMessage("[3] Downloading ZIP from " .. url)
    local data, headers = LrHttp.get(url)
    if headers.error then
        logger.logMessage("[3] ERROR downloading ZIP: " .. tostring(headers.error))
        return false
    end
    local f = io.open(zipPath, "wb")
    if not f then
        logger.logMessage("[3] ERROR writing file: " .. zipPath)
        return false
    end
    f:write(data)
    f:close()
    logger.logMessage("[3] ZIP successfully downloaded to: " .. zipPath)
    return true
end

--------------------------------------------------------------------------------
-- Step 4: Extract ZIP using tar (Windows 10+ / Linux compatible)
--------------------------------------------------------------------------------
local function shellquote(path)
    -- quote path safely for command line
    return '"' .. path .. '"'
end

local function extractZip(zipPath, tmpDir)
    logger.logMessage("[4] Extracting ZIP to temporary directory: " .. tmpDir)
    LrFileUtils.createAllDirectories(tmpDir)

    local cmd = "tar -xf " .. shellquote(zipPath) .. " -C " .. shellquote(tmpDir)
    logger.logMessage("[4] Executing command: " .. cmd)
    local ret = LrTasks.execute(cmd)
    if ret ~= 0 then
        logger.logMessage("[4] ERROR extracting ZIP, return code: " .. tostring(ret))
        return nil
    end

    -- Verify plugin directory exists in extracted files
    for path in LrFileUtils.directoryEntries(tmpDir) do
        if path:find("Inaturalist%-Identifier%-Lightroom%-") then
            local pluginDir = LrPathUtils.child(path, "iNaturalist_Identifier.lrplugin")
            if LrFileUtils.exists(pluginDir) then
                logger.logMessage("[4] Extracted plugin directory found: " .. pluginDir)
                return pluginDir
            end
        end
    end

    logger.logMessage("[4] ERROR: Plugin directory not found in extracted ZIP")
    return nil
end

--------------------------------------------------------------------------------
-- Step 5: Backup current plugin
--------------------------------------------------------------------------------
local function backupCurrentPlugin(pluginPath)
    local v = Updates.version()
    local backupPath = pluginPath .. "-" .. v
    logger.logMessage("[5] Creating backup copy of current plugin: " .. backupPath)
    local ok = LrFileUtils.copy(pluginPath, backupPath)
    if not ok then
        logger.logMessage("[5] ERROR: Failed to backup current plugin")
        return nil
    end
    return backupPath
end

--------------------------------------------------------------------------------
-- Step 6 & 7: Replace old plugin with new plugin
--------------------------------------------------------------------------------
local function replacePlugin(pluginPath, newPluginPath)
    logger.logMessage("[6] Removing old plugin: " .. pluginPath)
    LrFileUtils.delete(pluginPath)

    logger.logMessage("[7] Installing new plugin")
    local ok = LrFileUtils.move(newPluginPath, pluginPath)
    if not ok then
        logger.logMessage("[7] ERROR: Failed to install new plugin")
        return false
    end
    return true
end

--------------------------------------------------------------------------------
-- Step 8: Cleanup temporary files
--------------------------------------------------------------------------------
local function cleanup(zipPath, tmpDir)
    logger.logMessage("[8] Cleaning up temporary files")
    if LrFileUtils.exists(zipPath) then
        LrFileUtils.delete(zipPath)
    end
    if LrFileUtils.exists(tmpDir) then
        LrFileUtils.delete(tmpDir)
    end
end

--------------------------------------------------------------------------------
-- Orchestration: Download and install latest plugin
--------------------------------------------------------------------------------
local function downloadAndInstall(ctx, release)
    local pluginPath = _PLUGIN.path
    local parentDir = LrPathUtils.parent(pluginPath)
    local zipPath = LrPathUtils.child(parentDir, "download.zip")
    local tmpDir = LrPathUtils.child(LrPathUtils.getStandardFilePath("temp"), "iNatTmp")

    local url = findSourceZipAsset(release)
    if not url then return end
    if not downloadZip(url, zipPath) then return end

    local extractedPlugin = extractZip(zipPath, tmpDir)
    if not extractedPlugin then return end

    if not backupCurrentPlugin(pluginPath) then return end

    if not replacePlugin(pluginPath, extractedPlugin) then return end

    cleanup(zipPath, tmpDir)

    LrDialogs.message("iNaturalist Identifier updated",
                      "Please restart Lightroom to complete installation",
                      "info")
end

--------------------------------------------------------------------------------
-- Version helpers
--------------------------------------------------------------------------------
function Updates.version()
    local v = Info.VERSION
    return string.format("%s.%s.%s", v.major, v.minor, v.revision)
end

function Updates.getCurrentVersion()
    return Updates.version()
end

function Updates.getLatestGitHubVersion()
    local latest = getLatestVersion()
    if latest then return latest.tag_name end
    return nil
end

--------------------------------------------------------------------------------
-- Check for updates
--------------------------------------------------------------------------------
function Updates.check(force)
    local current = Updates.version()
    logger.logMessage("Current plugin version: " .. (Info.VERSION.display or current))
    if not force and not prefs.checkForUpdates then return end

    local latest = getLatestVersion()
    if not latest then return end

    local currentNorm = current:gsub("^v", "")
    local latestNorm = latest.tag_name and latest.tag_name:gsub("^v", "") or ""

    if currentNorm ~= latestNorm then
        logger.logMessage("Update available: " .. current .. " → " .. latest.tag_name)
        LrFunctionContext.callWithContext("downloadAndInstall", downloadAndInstall, latest)
        return
    end

    return current
end

function Updates.forceUpdate()
    LrTasks.startAsyncTask(function()
        local v = Updates.check(true)
        if v then
            LrDialogs.message("No updates available",
                              "You already have the most recent version (" .. v .. ")",
                              "info")
        end
    end)
end

return Updates

--------------------------------------------------------------------------------
-- iNaturalist Identifier Plugin Updater
-- Functional description (English):
-- This script checks the latest release of the plugin on GitHub, downloads the
-- corresponding source code zip archive, extracts it into a temporary directory,
-- keeps only the "iNaturalist_Identifier.lrplugin" folder, backs up the current
-- installed plugin into "iNaturalist_Identifier.lrpluginbackup", and installs the
-- newly downloaded version into the plugin folder used by Lightroom.
--
-- Steps:
-- 1. Query the GitHub API to find the latest release tag for the repository.
-- 2. Construct the direct download URL for the source code zip file.
-- 3. Download the zip archive into a temporary directory.
-- 4. Extract the zip archive into the temporary directory.
-- 5. Keep only "iNaturalist_Identifier.lrplugin" in that directory.
-- 6. Backup the currently installed plugin to "iNaturalist_Identifier.lrpluginbackup".
-- 7. Replace the installed plugin with the new one from the temporary directory.
-- 8. Log each action with detailed English messages via logger.lua.
--
-- Modules and scripts used:
--  - logger.lua : Custom logging module.
--  - Info.lua   : Provides plugin version information.
--  - json.lua   : JSON parsing.
--  - LrPrefs, LrDialogs, LrFileUtils, LrFunctionContext, LrPathUtils,
--    LrHttp, LrTasks : Lightroom SDK modules.
--------------------------------------------------------------------------------

local logger = require("logger")  -- custom logger.lua
local prefs = import("LrPrefs").prefsForPlugin()
local LrDialogs = import("LrDialogs")
local LrFileUtils = import("LrFileUtils")
local LrFunctionContext = import("LrFunctionContext")
local LrPathUtils = import("LrPathUtils")
local LrHttp = import("LrHttp")
local LrTasks = import("LrTasks")

local Info = require("Info")
local json = require("json")

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------
local Updates = {
    baseUrl = "https://api.github.com/",
    repo = "pbranly/Inaturalist-Identifier-Lightroom",
    actionPrefKey = "doNotShowUpdatePrompt",
}

--------------------------------------------------------------------------------
-- Step 1: Get the latest release metadata from GitHub
--------------------------------------------------------------------------------
local function getLatestVersion()
    local url = Updates.baseUrl .. "repos/" .. Updates.repo .. "/releases/latest"
    local headers = {
        { field = "User-Agent", value = Updates.repo .. "/" .. Updates.version() },
        { field = "X-GitHub-Api-Version", value = "2022-11-28" },
    }

    logger.logMessage("[Step 1] Sending HTTP GET to: " .. url)
    local data, respHeaders = LrHttp.get(url, headers)

    if respHeaders.error or respHeaders.status ~= 200 then
        logger.logMessage("[Step 1] ERROR: Failed to get latest release, status=" .. tostring(respHeaders.status))
        return
    end

    logger.logMessage("[Step 1] Response received: " .. data)

    local success, release = pcall(json.decode, data)
    if not success then
        logger.logMessage("[Step 1] ERROR: JSON decode failed")
        return
    end

    logger.logMessage("[Step 1] Found latest release: " .. release.tag_name)
    return release
end

--------------------------------------------------------------------------------
-- Step 2: Build the download URL for the source zip
--------------------------------------------------------------------------------
local function findSourceZipAsset(release)
    if not release or not release.tag_name then
        logger.logMessage("[Step 2] ERROR: Release or tag_name missing")
        return nil
    end
    local url = "https://github.com/" .. Updates.repo .. "/archive/refs/tags/" 
                .. release.tag_name .. ".zip"
    logger.logMessage("[Step 2] Constructed source zip URL: " .. url)
    return url
end

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------
local function shellquote(s)
    if MAC_ENV then
        s = s:gsub("'", "'\\''")
        return "'" .. s .. "'"
    else
        return '"' .. s .. '"'
    end
end

--------------------------------------------------------------------------------
-- Step 3: Download the zip file
--------------------------------------------------------------------------------
local function download(url, filename)
    logger.logMessage("[Step 3] Downloading from: " .. url)
    local data, headers = LrHttp.get(url)
    if headers.error then
        logger.logMessage("[Step 3] ERROR during download")
        return false
    end

    local f = io.open(filename, "wb")
    f:write(data)
    f:close()
    logger.logMessage("[Step 3] File written to: " .. filename)
    return true
end

--------------------------------------------------------------------------------
-- Step 4: Extract the zip file
--------------------------------------------------------------------------------
local function extract(filename, workdir)
    local cmd = "unzip -o " .. shellquote(filename) .. " -d " .. shellquote(workdir)
    logger.logMessage("[Step 4] Executing: " .. cmd)
    local ret = LrTasks.execute(cmd)
    if ret ~= 0 then
        error("[Step 4] Could not extract downloaded release file")
    end
    logger.logMessage("[Step 4] Extraction completed")
end

--------------------------------------------------------------------------------
-- Step 5: Keep only iNaturalist_Identifier.lrplugin directory
--------------------------------------------------------------------------------
local function cleanupWorkdir(workdir)
    logger.logMessage("[Step 5] Cleaning workdir, keeping only iNaturalist_Identifier.lrplugin")

    for entry in LrFileUtils.directoryEntries(workdir) do
        if entry:find("iNaturalist_Identifier.lrplugin$") then
            logger.logMessage("[Step 5] Keeping: " .. entry)
        else
            logger.logMessage("[Step 5] Removing: " .. entry)
            LrFileUtils.delete(entry)
        end
    end
end

--------------------------------------------------------------------------------
-- Step 6 + 7: Backup and Install
--------------------------------------------------------------------------------
local function install(workdir, pluginPath)
    local newPluginPath = LrPathUtils.child(workdir, "iNaturalist_Identifier.lrplugin")
    if not LrFileUtils.exists(newPluginPath) then
        error("[Step 6] ERROR: iNaturalist_Identifier.lrplugin not found in extracted files")
    end

    local backupPath = pluginPath .. "backup"
    logger.logMessage("[Step 6] Backing up current plugin from " .. pluginPath .. " to " .. backupPath)
    if LrFileUtils.exists(pluginPath) then
        if LrFileUtils.exists(backupPath) then
            LrFileUtils.delete(backupPath)
        end
        LrFileUtils.move(pluginPath, backupPath)
    end

    logger.logMessage("[Step 7] Installing new plugin from " .. newPluginPath .. " to " .. pluginPath)
    LrFileUtils.move(newPluginPath, pluginPath)
end

--------------------------------------------------------------------------------
-- Main installation orchestration
--------------------------------------------------------------------------------
local function downloadAndInstall(ctx, release)
    local workdir = LrFileUtils.chooseUniqueFileName(_PLUGIN.path)
    ctx:addCleanupHandler(function()
        LrFileUtils.delete(workdir)
    end)
    local r = LrFileUtils.createDirectory(workdir)
    if not r then
        error("[Main] Cannot create temporary directory")
    end
    local zip = LrPathUtils.child(workdir, "download.zip")

    local url = findSourceZipAsset(release)
    if not url then return end

    if not download(url, zip) then return end
    extract(zip, workdir)
    cleanupWorkdir(workdir)
    install(workdir, _PLUGIN.path)
end

--------------------------------------------------------------------------------
-- Dialog for update proposal
--------------------------------------------------------------------------------
local function showUpdateDialog(release, force)
    if release.tag_name ~= prefs.lastUpdateOffered then
        LrDialogs.resetDoNotShowFlag(Updates.actionPrefKey)
        prefs.lastUpdateOffered = release.tag_name
    end

    local info = "An update is available for the iNaturalist Identifier Plugin. Would you like to download it now?"
    if release.body and #release.body > 0 then
        info = info .. "\n\n" .. release.body
    end

    local actionPrefKey = Updates.actionPrefKey
    if force then
        actionPrefKey = nil
    end

    local toDo = LrDialogs.promptForActionWithDoNotShow({
        message = LOC("$$$/iNat/PluginName=iNaturalist Identifier Plugin update available"),
        info = info,
        actionPrefKey = actionPrefKey,
        verbBtns = {
            { label = LOC("$$$/iNat/Download=Download"), verb = "download" },
            { label = LOC("$$$/iNat/Ignore=Ignore"), verb = "ignore" },
        },
    })
    if toDo == "download" then
        if LrTasks.execute("unzip -v") == 0 then
            LrFunctionContext.callWithContext("downloadAndInstall", downloadAndInstall, release)
            LrDialogs.message(LOC("$$$/iNat/Installed=Update installed"), LOC("$$$/iNat/Restart=Please restart Lightroom"), "info")
        else
            LrHttp.openUrlInBrowser(findSourceZipAsset(release))
        end
    else
        logger.logMessage("[Dialog] User response: " .. tostring(toDo))
    end
end

--------------------------------------------------------------------------------
-- Version handling
--------------------------------------------------------------------------------
function Updates.version()
    local v = Info.VERSION
    return string.format("%s.%s.%s", v.major, v.minor, v.revision)
end

function Updates.check(force)
    local current = Updates.version()
    logger.logMessage("Running version " .. (Info.VERSION.display or current))

    if not force and not prefs.checkForUpdates then
        return
    end

    local latest = getLatestVersion()
    if not latest then
        return
    end

    -- Normalize both: remove leading "v"
    local currentNorm = current:gsub("^v", "")
    local latestNorm = latest.tag_name and latest.tag_name:gsub("^v", "") or ""

    if currentNorm ~= latestNorm then
        logger.logMessage("Offering update from " .. current .. " to " .. latest.tag_name)
        showUpdateDialog(latest, force)
        return
    end

    return current
end

function Updates.forceUpdate()
    LrTasks.startAsyncTask(function()
        local v = Updates.check(true)
        if v then
            LrDialogs.message(
                LOC("$$$/iNat/NoUpdate=No updates available"),
                string.format("You have the most recent version of the iNaturalist Identifier Plugin, %s", v),
                "info"
            )
        end
    end)
end

return Updates

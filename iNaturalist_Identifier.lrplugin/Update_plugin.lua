--------------------------------------------------------------------------------
-- iNaturalist Identifier Lightroom Plugin - Updater Script
--
-- Functional Description (in English):
-- This script checks for the latest release of the plugin from the GitHub
-- repository "pbranly/Inaturalist-Identifier-Lightroom". It downloads the
-- corresponding "Source code (zip)" archive for the tag marked as "latest".
-- The script then extracts only the "iNaturalist_Identifier.lrplugin" folder
-- into a temporary directory. Before installation, the current plugin is
-- backed up to "iNaturalist_Identifier.lrpluginbackup". Finally, the new
-- plugin version is copied into the working directory and replaces the old one.
--
-- Detailed steps:
-- 1. Define repository and preferences
-- 2. Fetch metadata of the latest release from GitHub API
-- 3. Build the correct download URL for the tagged source archive
-- 4. Download the zip file into a system temporary directory
-- 5. Extract the archive into the temporary directory
-- 6. Locate the "iNaturalist_Identifier.lrplugin" folder
-- 7. Backup the current plugin into "iNaturalist_Identifier.lrpluginbackup"
-- 8. Copy the new plugin folder into the Lightroom plugins directory
-- 9. Clean temporary files and notify user
--------------------------------------------------------------------------------

local logger = require("logger")  -- use logger.lua
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
    repo = "pbranly/Inaturalist-Identifier-Lightroom",   -- switched to your repo
    actionPrefKey = "doNotShowUpdatePrompt",
}

--------------------------------------------------------------------------------
-- Helper: Get temporary directory (cross-platform)
--------------------------------------------------------------------------------
local function getTempDir()
    local sep = package.config:sub(1,1)
    if sep == "\\" then
        return os.getenv("TEMP") or "C:\\Temp"
    else
        return "/tmp"
    end
end

--------------------------------------------------------------------------------
-- Step 2: Get latest release metadata from GitHub API
--------------------------------------------------------------------------------
local function getLatestVersion()
    local url = Updates.baseUrl .. "repos/" .. Updates.repo .. "/releases/latest"
    local headers = {
        { field = "User-Agent", value = Updates.repo .. "/" .. Updates.version() },
        { field = "X-GitHub-Api-Version", value = "2022-11-28" },
    }

    logger.logMessage("[Step 2] Sending request to GitHub API: " .. url)
    local data, respHeaders = LrHttp.get(url, headers)

    if respHeaders.error or respHeaders.status ~= 200 then
        logger.logMessage("[Step 2] ERROR: GitHub API request failed with status " ..
            tostring(respHeaders.status) .. " error: " .. tostring(respHeaders.error))
        return
    end

    logger.logMessage("[Step 2] GitHub API response: " .. data)
    local success, release = pcall(json.decode, data)
    if not success then
        logger.logMessage("[Step 2] ERROR: Could not decode GitHub API response")
        return
    end

    logger.logMessage("[Step 2] Found latest release tag: " .. release.tag_name)
    return release
end

--------------------------------------------------------------------------------
-- Step 3: Build source zip URL from tag
--------------------------------------------------------------------------------
local function findSourceZipAsset(release)
    if not release or not release.tag_name then
        logger.logMessage("[Step 3] ERROR: Release or tag_name missing")
        return nil
    end
    local url = "https://github.com/pbranly/Inaturalist-Identifier-Lightroom/archive/refs/tags/" 
                .. release.tag_name .. ".zip"
    logger.logMessage("[Step 3] Constructed source zip URL: " .. url)
    return url
end

--------------------------------------------------------------------------------
-- Step 4: Download the zip file
--------------------------------------------------------------------------------
local function download(url, filename)
    logger.logMessage("[Step 4] Downloading file: " .. url)
    local data, headers = LrHttp.get(url)
    if headers.error then
        logger.logMessage("[Step 4] ERROR: Download failed - " .. tostring(headers.error))
        return false
    end

    local f = io.open(filename, "wb")
    f:write(data)
    f:close()
    logger.logMessage("[Step 4] File downloaded to: " .. filename)
    return true
end

--------------------------------------------------------------------------------
-- Step 5: Extract archive
--------------------------------------------------------------------------------
local function extract(filename, workdir)
    local cmd = "unzip -o " .. shellquote(filename) .. " -d " .. shellquote(workdir)
    logger.logMessage("[Step 5] Executing extraction command: " .. cmd)
    local ret = LrTasks.execute(cmd)
    if ret ~= 0 then
        error("[Step 5] Could not extract downloaded release file")
    end
end

--------------------------------------------------------------------------------
-- Step 6-7: Install plugin with backup
--------------------------------------------------------------------------------
local function install(workdir, pluginPath)
    local newPluginPath = nil
    for path in LrFileUtils.directoryEntries(workdir) do
        if path:find("iNaturalist_Identifier%.lrplugin$") then
            newPluginPath = path
        end
    end
    if not newPluginPath then
        error("[Step 6] Expected plugin folder not found in extracted archive")
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
        logger.logMessage("[Step 7] Removing existing plugin directory: " .. pluginPath)
        LrFileUtils.delete(pluginPath)
    end

    logger.logMessage("[Step 7] Copying new plugin from " .. newPluginPath .. " to " .. pluginPath)
    LrFileUtils.copy(newPluginPath, pluginPath)
    logger.logMessage("[Step 7] New plugin installed successfully")
end

--------------------------------------------------------------------------------
-- Step 8: Full update workflow
--------------------------------------------------------------------------------
local function downloadAndInstall(ctx, release)
    local tempDir = getTempDir()
    local workdir = LrPathUtils.child(tempDir, LrFileUtils.chooseUniqueFileName("iNatUpdateWorkdir"))
    ctx:addCleanupHandler(function()
        LrFileUtils.delete(workdir)
    end)
    local r = LrFileUtils.createDirectory(workdir)
    if not r then
        error("Cannot create temporary directory: " .. workdir)
    end
    logger.logMessage("[Step 8] Using temporary directory: " .. workdir)

    local zip = LrPathUtils.child(workdir, "download.zip")
    local url = findSourceZipAsset(release)
    download(url, zip)
    extract(zip, workdir)
    install(workdir, _PLUGIN.path)
end

--------------------------------------------------------------------------------
-- Update dialog
--------------------------------------------------------------------------------
local function showUpdateDialog(release, force)
    if release.tag_name ~= prefs.lastUpdateOffered then
        LrDialogs.resetDoNotShowFlag(Updates.actionPrefKey)
        prefs.lastUpdateOffered = release.tag_name
    end

    local info = LOC("$$$/iNat/UpdateMessage=An update is available for the iNaturalist Identifier Plugin. Would you like to download it now?")
    if release.body and #release.body > 0 then
        info = info .. "\n\n" .. release.body
    end

    local toDo = LrDialogs.promptForActionWithDoNotShow({
        message = LOC("$$$/iNat/PluginName=iNaturalist Identifier Plugin update available"),
        info = info,
        actionPrefKey = Updates.actionPrefKey,
        verbBtns = {
            { label = LOC("$$$/iNat/Download=Download"), verb = "download" },
            { label = LOC("$$$/iNat/Ignore=Ignore"), verb = "ignore" },
        },
    })
    if toDo == "download" then
        LrFunctionContext.callWithContext("downloadAndInstall", downloadAndInstall, release)
        LrDialogs.message(
            LOC("$$$/iNat/UpdateInstalled=Plugin update installed"),
            LOC("$$$/iNat/Restart=Please restart Lightroom"),
            "info"
        )
    else
        logger.logMessage("[Dialog] Update dialog response: " .. tostring(toDo))
    end
end

--------------------------------------------------------------------------------
-- Public functions
--------------------------------------------------------------------------------
function Updates.version()
    local v = Info.VERSION
    return string.format("%s.%s.%s", v.major, v.minor, v.revision)
end

function Updates.check(force)
    local current = "v" .. Updates.version()
    logger.logMessage("Running " .. (Info.VERSION.display or current))

    if not force and not prefs.checkForUpdates then
        return
    end

    local latest = getLatestVersion()
    if not latest then
        return
    end

    if current ~= latest.tag_name then
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
                LOC("$$$/iNat/NoUpdates=No updates available"),
                string.format("You have the most recent version of the iNaturalist Identifier Plugin, %s", v),
                "info"
            )
        end
    end)
end

return Updates

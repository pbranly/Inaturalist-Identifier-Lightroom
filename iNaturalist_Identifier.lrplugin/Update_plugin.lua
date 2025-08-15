--------------------------------------------------------------------------------
-- Lightroom Plugin: iNaturalist Publish Plugin - Auto Update Script
-- Author: Adapted for Philippe
-- Date: 2025-08-15
--------------------------------------------------------------------------------
-- FUNCTIONAL DESCRIPTION:
-- This script checks for the latest release of the "lr-inaturalist-publish" 
-- project on GitHub, downloads the "Source code (zip)" asset, extracts it 
-- into a system temporary directory, keeps only the 
-- "iNaturalist_Identifier.lrplugin" folder, replaces the currently installed 
-- plugin with the new version, and prompts the user through Lightroom dialogs.
--------------------------------------------------------------------------------
-- MODULES USED:
--   - logger.lua (custom logging utility)
--   - json.lua   (JSON parsing)
--   - Info.lua   (plugin version info)
--   - Lightroom SDK modules:
--       LrPrefs, LrDialogs, LrFileUtils, LrFunctionContext, LrPathUtils,
--       LrHttp, LrTasks
--------------------------------------------------------------------------------
-- SCRIPTS USING THIS SCRIPT:
--   - This update script is part of the iNaturalist Publish Plugin and is 
--     called when the plugin checks for updates.
--------------------------------------------------------------------------------
-- NUMBERED STEPS:
--   1. Get latest release info from GitHub API.
--   2. Identify and select "Source code (zip)" asset.
--   3. Create a system temporary working directory.
--   4. Download the selected zip file.
--   5. Extract its contents to the temp directory.
--   6. Keep only "iNaturalist_Identifier.lrplugin" folder.
--   7. Replace old plugin with the new version.
--   8. Notify the user and clean up temporary files.
--------------------------------------------------------------------------------
-- DETAILED DESCRIPTION OF EACH STEP:
--   Step 1: Send GET request to GitHub API for the latest release of the target repo.
--   Step 2: From the assets list, find the one named "Source code (zip)".
--   Step 3: Create a unique working directory inside the OS temp folder.
--   Step 4: Download the zip asset into the working directory.
--   Step 5: Extract the zip using system tools (tar for Unix, PowerShell for Windows).
--   Step 6: Delete all files/folders except "iNaturalist_Identifier.lrplugin".
--   Step 7: Backup the current plugin folder and replace it with the extracted one.
--   Step 8: Inform the user of success or errors and remove temp files.
--------------------------------------------------------------------------------

local logger = require("logger")  -- Custom logger
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
-- Helper: Detect OS
--------------------------------------------------------------------------------
local function detectPlatform()
    local sep = package.config:sub(1,1)
    if sep == "\\" then
        return "windows"
    else
        return "unix"
    end
end

--------------------------------------------------------------------------------
-- Helper: Get system temp directory
--------------------------------------------------------------------------------
local function getTempDir()
    if detectPlatform() == "windows" then
        return os.getenv("TEMP") or "C:\\Temp"
    else
        return "/tmp"
    end
end

--------------------------------------------------------------------------------
-- Step 1: Get latest release info
--------------------------------------------------------------------------------
local function getLatestVersion()
    local url = Updates.baseUrl .. "repos/" .. Updates.repo .. "/releases/latest"
    local headers = {
        { field = "User-Agent", value = Updates.repo .. "/" .. Updates.version() },
        { field = "X-GitHub-Api-Version", value = "2022-11-28" },
    }
    logger.logMessage("[Step 1] Sending GET request to: " .. url)
    local data, respHeaders = LrHttp.get(url, headers)
    logger.logMessage("[Step 1] Response status: " .. tostring(respHeaders.status))
    logger.logMessage("[Step 1] Response body: " .. tostring(data))

    if respHeaders.error or respHeaders.status ~= 200 then
        logger.logMessage("[Step 1] Error retrieving latest version info")
        return
    end

    local success, release = pcall(json.decode, data)
    if not success then
        logger.logMessage("[Step 1] JSON decode failed")
        return
    end

    logger.logMessage("[Step 1] Found latest release: " .. release.tag_name)
    return release
end

--------------------------------------------------------------------------------
-- Step 2: Find "Source code (zip)" asset
--------------------------------------------------------------------------------
local function findSourceZipAsset(release)
    for _, asset in ipairs(release.assets or {}) do
        if asset.name and asset.name:lower():find("source code %(zip%)") then
            logger.logMessage("[Step 2] Found Source code (zip) asset: " .. asset.browser_download_url)
            return asset
        end
    end
    logger.logMessage("[Step 2] No 'Source code (zip)' asset found")
end

--------------------------------------------------------------------------------
-- Helper: Shell quoting
--------------------------------------------------------------------------------
local function shellquote(s)
    if detectPlatform() == "unix" then
        s = s:gsub("'", "'\\''")
        return "'" .. s .. "'"
    else
        return '"' .. s .. '"'
    end
end

--------------------------------------------------------------------------------
-- Step 4: Download asset
--------------------------------------------------------------------------------
local function download(asset, filename)
    logger.logMessage("[Step 4] Downloading asset from: " .. asset.browser_download_url)
    local data, headers = LrHttp.get(asset.browser_download_url)
    logger.logMessage("[Step 4] Download HTTP status: " .. tostring(headers.status))
    if headers.error then
        error("Download failed: " .. tostring(headers.error))
    end
    local f = io.open(filename, "wb")
    f:write(data)
    f:close()
    logger.logMessage("[Step 4] Download saved to: " .. filename)
end

--------------------------------------------------------------------------------
-- Step 5 & 6: Extract and keep only plugin folder
--------------------------------------------------------------------------------
local function extract(filename, workdir)
    local platform = detectPlatform()
    local cmd
    if platform == "unix" then
        cmd = "tar -C " .. shellquote(workdir) .. " -xf " .. shellquote(filename)
    else
        cmd = 'powershell -Command "Expand-Archive -Force ' ..
              '"' .. filename .. '" ' ..
              '"' .. workdir .. '"'
    end
    logger.logMessage("[Step 5] Executing extraction: " .. cmd)
    local ret = LrTasks.execute(cmd)
    if ret ~= 0 then
        error("Extraction failed")
    end

    -- Keep only iNaturalist_Identifier.lrplugin
    logger.logMessage("[Step 6] Cleaning extracted files")
    local keptFolder = nil
    for path in LrFileUtils.directoryEntries(workdir) do
        if LrFileUtils.isDirectory(path) then
            if path:find("iNaturalist_Identifier%.lrplugin$") then
                logger.logMessage("[Step 6] Keeping: " .. path)
                keptFolder = path
            else
                logger.logMessage("[Step 6] Deleting folder: " .. path)
                LrFileUtils.delete(path)
            end
        else
            logger.logMessage("[Step 6] Deleting file: " .. path)
            LrFileUtils.delete(path)
        end
    end
    if not keptFolder then
        error("Plugin folder not found after extraction")
    end
end

--------------------------------------------------------------------------------
-- Step 7: Install plugin
--------------------------------------------------------------------------------
local function install(workdir, pluginPath)
    local newPluginPath = LrPathUtils.child(workdir, "iNaturalist_Identifier.lrplugin")
    if not LrFileUtils.exists(newPluginPath) then
        error("Expected plugin folder not found: " .. newPluginPath)
    end
    local scratch = LrFileUtils.chooseUniqueFileName(pluginPath)
    logger.logMessage("[Step 7] Backing up old plugin to: " .. scratch)
    LrFileUtils.move(pluginPath, scratch)
    logger.logMessage("[Step 7] Installing new plugin from: " .. newPluginPath)
    LrFileUtils.move(newPluginPath, pluginPath)
end

--------------------------------------------------------------------------------
-- Download, extract, install sequence
--------------------------------------------------------------------------------
local function downloadAndInstall(ctx, release)
    local asset = findSourceZipAsset(release)
    if not asset then
        LrDialogs.message(LOC("$$$/iNat/NoAssetFound=No Source code (zip) found in release"), "", "error")
        return
    end

    local tempDir = getTempDir()
    local workdir = LrPathUtils.child(tempDir, LrFileUtils.chooseUniqueFileName("iNatUpdateWorkdir"))
    ctx:addCleanupHandler(function()
        LrFileUtils.delete(workdir)
    end)
    if not LrFileUtils.createDirectory(workdir) then
        error("Cannot create temp directory: " .. workdir)
    end
    logger.logMessage("[Step 3] Using temp directory: " .. workdir)

    local zip = LrPathUtils.child(workdir, "download.zip")
    download(asset, zip)
    extract(zip, workdir)
    install(workdir, _PLUGIN.path)
end

--------------------------------------------------------------------------------
-- Show update dialog
--------------------------------------------------------------------------------
local function showUpdateDialog(release, force)
    local info = LOC("$$$/iNat/UpdateAvailable=An update is available for the iNaturalist Publish Plugin.")
    if release.body and #release.body > 0 then
        info = info .. "\n\n" .. release.body
    end

    local toDo = LrDialogs.promptForActionWithDoNotShow({
        message = LOC("$$$/iNat/UpdatePromptTitle=iNaturalist Publish Plugin update available"),
        info = info,
        actionPrefKey = force and nil or Updates.actionPrefKey,
        verbBtns = {
            { label = LOC("$$$/iNat/Download=Download"), verb = "download" },
            { label = LOC("$$$/iNat/Ignore=Ignore"), verb = "ignore" },
        },
    })
    if toDo == "download" then
        LrFunctionContext.callWithContext("downloadAndInstall", downloadAndInstall, release)
        LrDialogs.message(LOC("$$$/iNat/UpdateInstalled=Update installed"), LOC("$$$/iNat/PleaseRestart=Please restart Lightroom"), "info")
    else
        logger.logMessage("[Dialog] User chose: " .. tostring(toDo))
    end
end

--------------------------------------------------------------------------------
-- Version function
--------------------------------------------------------------------------------
function Updates.version()
    local v = Info.VERSION
    return string.format("%s.%s.%s", v.major, v.minor, v.revision)
end

--------------------------------------------------------------------------------
-- Main check function
--------------------------------------------------------------------------------
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
    else
        logger.logMessage("Already up to date")
    end
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
                string.format(LOC("$$$/iNat/MostRecent=You have the most recent version: %s"), v),
                "info"
            )
        end
    end)
end

return Updates

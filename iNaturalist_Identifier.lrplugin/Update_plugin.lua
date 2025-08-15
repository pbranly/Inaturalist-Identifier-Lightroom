--[[
===============================================================================
iNaturalist Publish Plugin - Update Module
===============================================================================

FUNCTIONAL DESCRIPTION:
This script checks the latest release of the "iNaturalist Publish Plugin" from
GitHub, downloads the "Source code (zip)" asset, extracts it to a temporary
system directory, and installs it by replacing the current plugin directory.

It logs each step in detail using logger.lua, including HTTP requests and
responses, command executions, and file operations.

===============================================================================
MODULES USED:
- logger.lua         : Custom logging utility for detailed logs
- LrPrefs            : Lightroom SDK preferences API
- LrDialogs          : Lightroom SDK dialog boxes
- LrFileUtils        : Lightroom SDK file operations
- LrFunctionContext  : Lightroom SDK execution context handling
- LrPathUtils        : Lightroom SDK path handling
- LrHttp             : Lightroom SDK HTTP requests
- LrTasks            : Lightroom SDK background tasks
- Info.lua           : Plugin metadata (version, etc.)
- json.lua           : JSON encoding/decoding

===============================================================================
SCRIPTS USING THIS MODULE:
- main.lua           : Main entry point of the Lightroom plugin
- menu.lua           : Menu integration for checking and forcing updates

===============================================================================
WORKFLOW STEPS:
1. Retrieve latest release info from GitHub API.
2. Locate the "Source code (zip)" asset in the release.
3. Create a unique temporary directory in the system temp folder.
4. Download the asset into this directory.
5. Extract the zip file (tar on Unix/macOS, PowerShell on Windows).
6. Replace the current plugin folder with the extracted one.
7. Notify the user and log all details.

===============================================================================
STEP DESCRIPTIONS:
1. getLatestVersion() → Sends HTTP GET to GitHub API and parses JSON.
2. findSourceZip()    → Searches release assets for the correct "Source code (zip)".
3. getTempDir()       → Detects OS and returns system temp directory path.
4. download()         → Downloads the zip file and writes it to disk.
5. extract()          → Uses tar or PowerShell to extract the archive.
6. install()          → Moves extracted plugin into place, backing up old one.
7. showUpdateDialog() → Displays update dialog with actions for user.

===============================================================================
]]

local logger = require("logger")
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

-- Detect OS platform
local function detectPlatform()
    local sep = package.config:sub(1,1)
    if sep == "\\" then
        return "windows"
    else
        return "unix"
    end
end

-- Return system temp directory
local function getTempDir()
    local platform = detectPlatform()
    if platform == "windows" then
        return os.getenv("TEMP") or "C:\\Temp"
    else
        return "/tmp"
    end
end

-- Step 1: Get latest release info
local function getLatestVersion()
    local url = Updates.baseUrl .. "repos/" .. Updates.repo .. "/releases/latest"
    local headers = {
        { field = "User-Agent", value = Updates.repo .. "/" .. Updates.version() },
        { field = "X-GitHub-Api-Version", value = "2022-11-28" },
    }
    logger.logMessage("HTTP GET: " .. url)
    local data, respHeaders = LrHttp.get(url, headers)

    if respHeaders.error or respHeaders.status ~= 200 then
        logger.logMessage("Error fetching release info: " .. (respHeaders.error or ("HTTP " .. tostring(respHeaders.status))))
        return
    end

    logger.logMessage("GitHub API response: " .. (data or "nil"))
    local success, release = pcall(json.decode, data)
    if not success then
        logger.logMessage("Error decoding JSON release data")
        return
    end

    logger.logMessage("Found latest release: " .. (release.tag_name or "unknown"))
    return release
end

-- Step 2: Find "Source code (zip)" asset
local function findSourceZip(release)
    for _, asset in ipairs(release.assets or {}) do
        if asset.name and asset.name:lower():find("source code") and asset.name:lower():find("zip") then
            logger.logMessage("Found source zip: " .. asset.browser_download_url)
            return asset.browser_download_url
        end
    end
    -- Fallback: Sometimes GitHub's "Source code (zip)" is not listed in assets but in release
    if release.zipball_url then
        logger.logMessage("Using zipball_url: " .. release.zipball_url)
        return release.zipball_url
    end
    logger.logMessage("Source zip not found in release assets")
end

-- Shell quote helper
local function shellquote(s)
    if detectPlatform() == "unix" then
        s = s:gsub("'", "'\\''")
        return "'" .. s .. "'"
    else
        return '"' .. s .. '"'
    end
end

-- Step 4: Download file
local function download(url, filename)
    logger.logMessage("Downloading from: " .. url)
    local data, headers = LrHttp.get(url)
    logger.logMessage("HTTP Response status: " .. tostring(headers.status))
    if headers.error then
        logger.logMessage("Download error: " .. headers.error)
        return false
    end

    if LrFileUtils.exists(filename) and not LrFileUtils.isWritable(filename) then
        error("Cannot write to download file: " .. filename)
    end

    local f = io.open(filename, "wb")
    f:write(data)
    f:close()
    logger.logMessage("File downloaded to: " .. filename)
end

-- Step 5: Extract zip
local function extract(filename, workdir)
    local platform = detectPlatform()
    logger.logMessage("Detected platform: " .. platform)
    local cmd
    if platform == "unix" then
        cmd = "tar -C " .. shellquote(workdir) .. " -xf " .. shellquote(filename)
    else
        cmd = 'powershell -Command "Expand-Archive -Force ' ..
              '"' .. filename .. '" ' ..
              '"' .. workdir .. '"'
    end
    logger.logMessage("Executing extraction command: " .. cmd)
    local ret = LrTasks.execute(cmd)
    if ret ~= 0 then
        error("Extraction failed on " .. platform .. " platform")
    end
    logger.logMessage("Extraction completed in folder: " .. workdir)
end

-- Step 6: Install plugin
local function install(workdir, pluginPath)
    local newPluginPath = nil
    for path in LrFileUtils.directoryEntries(workdir) do
        if path:find("%.lrplugin$") then
            newPluginPath = path
        end
    end
    local scratch = LrFileUtils.chooseUniqueFileName(pluginPath)
    logger.logMessage("Backing up old plugin to: " .. scratch)
    LrFileUtils.move(pluginPath, scratch)
    logger.logMessage("Installing new plugin from: " .. (newPluginPath or "nil"))
    LrFileUtils.move(newPluginPath, pluginPath)
end

-- Step 3,4,5,6 combined
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
    logger.logMessage("Using temporary directory: " .. workdir)

    local zip = LrPathUtils.child(workdir, "download.zip")
    local url = findSourceZip(release)
    if not url then
        LrDialogs.message(LOC("$$$/iNat/Update/NoSource=Source code zip not found"), "", "error")
        return
    end

    download(url, zip)
    extract(zip, workdir)
    install(workdir, _PLUGIN.path)
end

-- Step 7: Dialog
local function showUpdateDialog(release, force)
    if release.tag_name ~= prefs.lastUpdateOffered then
        LrDialogs.resetDoNotShowFlag(Updates.actionPrefKey)
        prefs.lastUpdateOffered = release.tag_name
    end

    local info = LOC("$$$/iNat/Update/Available=An update is available for the iNaturalist Publish Plugin. Download now?")
    if release.body and #release.body > 0 then
        info = info .. "\n\n" .. release.body
    end

    local actionPrefKey = force and nil or Updates.actionPrefKey
    local toDo = LrDialogs.promptForActionWithDoNotShow({
        message = LOC("$$$/iNat/Update/Title=iNaturalist Publish Plugin update available"),
        info = info,
        actionPrefKey = actionPrefKey,
        verbBtns = {
            { label = LOC("$$$/iNat/Update/Download=Download"), verb = "download" },
            { label = LOC("$$$/iNat/Update/Ignore=Ignore"), verb = "ignore" },
        },
    })

    if toDo == "download" then
        LrFunctionContext.callWithContext("downloadAndInstall", downloadAndInstall, release)
        LrDialogs.message(LOC("$$$/iNat/Update/Installed=Update installed"), LOC("$$$/iNat/Update/Restart=Please restart Lightroom"), "info")
    else
        logger.logMessage("Update dialog response: " .. tostring(toDo))
    end
end

function Updates.version()
    local v = Info.VERSION
    return string.format("%s.%s.%s", v.major, v.minor, v.revision)
end

function Updates.check(force)
    local current = "v" .. Updates.version()
    logger.logMessage("Running version: " .. (Info.VERSION.display or current))

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
                LOC("$$$/iNat/Update/NoUpdates=No updates available"),
                string.format(LOC("$$$/iNat/Update/MostRecent=You have the most recent version (%s)"), v),
                "info"
            )
        end
    end)
end

return Updates

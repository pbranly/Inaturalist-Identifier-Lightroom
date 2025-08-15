--[[
============================================================
Functional Description
------------------------------------------------------------
This script handles checking for updates and downloading
the latest iNaturalist Publish Plugin from GitHub. It
downloads the official "Source code (zip)" of the latest
release, extracts it, and installs it in Lightroom.

Logging is done through logger.lua, and all steps are 
logged with details, including HTTP requests and responses.

------------------------------------------------------------
Modules / Scripts Used
1. Lightroom SDK Modules:
   - LrPrefs
   - LrDialogs
   - LrFileUtils
   - LrFunctionContext
   - LrPathUtils
   - LrHttp
   - LrTasks
2. External Lua Modules:
   - json (or dkjson)
   - Info.lua (plugin version info)
   - logger.lua (custom logging module)
------------------------------------------------------------
Scripts That Use This Module
- This Updates.lua module can be invoked by:
  - Main plugin startup scripts (e.g., AnimalIdentifier.lua)
  - Manual "Check for Updates" command
------------------------------------------------------------
Numbered Steps
1. Initialize logger and preferences.
2. Define utility functions (shellquote, download, extract, install).
3. Retrieve the latest release from GitHub.
4. Identify the "Source code (zip)" asset URL.
5. Prompt user to download if an update is available.
6. Download and extract the zip file.
7. Install the extracted plugin into the plugin folder.
8. Log each step and HTTP transaction in detail.
------------------------------------------------------------
Step Descriptions
1. Load modules and plugin preferences; start logging.
2. Provide helper functions to safely quote filenames,
   download files, extract archives, and move plugin folders.
3. Use GitHub API to request the latest release; log the
   request URL, headers, and response.
4. Use the zipball_url field to identify the official
   source code zip of the release.
5. Show a prompt dialog to the user with option to
   download or ignore; use internationalized messages.
6. Download the zip to a temporary folder; log size and
   status.
7. Extract using tar; move plugin folder to the correct
   installation location; clean up temporary files.
8. Each major step logs an English message using logger.lua.
============================================================
]]

local logger = require("logger")  -- Custom logger module
local prefs = import("LrPrefs").prefsForPlugin()
local LrDialogs = import("LrDialogs")
local LrFileUtils = import("LrFileUtils")
local LrFunctionContext = import("LrFunctionContext")
local LrPathUtils = import("LrPathUtils")
local LrHttp = import("LrHttp")
local LrTasks = import("LrTasks")

local Info = require("Info")
local json = require("json") -- or dkjson

local Updates = {
    baseUrl = "https://api.github.com/",
    repo = "rcloran/lr-inaturalist-publish",
    actionPrefKey = "doNotShowUpdatePrompt",
}

------------------------------------------------------------
-- Step 1: Helper functions
------------------------------------------------------------
local function shellquote(s)
    if MAC_ENV then
        s = s:gsub("'", "'\\''")
        return "'" .. s .. "'"
    else
        return '"' .. s .. '"'
    end
end

local function download(release, filename)
    if not release.assetToDownload then
        error("No source zip available for download")
    end
    logger.logMessage("Starting download from URL: " .. release.assetToDownload.browser_download_url)

    local data, headers = LrHttp.get(release.assetToDownload.browser_download_url)
    logger.logMessage("HTTP response status: " .. tostring(headers.status or "nil"))
    logger.logMessage("HTTP response error: " .. tostring(headers.error or "none"))

    if headers.error then
        error("Download failed: " .. tostring(headers.error))
    end

    local f = io.open(filename, "wb")
    f:write(data)
    f:close()
    logger.logMessage("Downloaded zip saved to: " .. filename)
end

local function extract(filename, workdir)
    local cmd = "tar -C " .. shellquote(workdir) .. " -xf " .. shellquote(filename)
    logger.logMessage("Executing extraction command: " .. cmd)
    local ret = LrTasks.execute(cmd)
    if ret ~= 0 then
        error("Could not extract downloaded release file")
    end
    logger.logMessage("Extraction completed in folder: " .. workdir)
end

local function install(workdir, pluginPath)
    logger.logMessage("Installing plugin from: " .. workdir)
    local newPluginPath = nil
    for path in LrFileUtils.directoryEntries(workdir) do
        if path:find("%.lrplugin$") then
            newPluginPath = path
        end
    end
    if not newPluginPath then
        error("No .lrplugin folder found after extraction")
    end
    local scratch = LrFileUtils.chooseUniqueFileName(newPluginPath)
    LrFileUtils.move(pluginPath, scratch)
    LrFileUtils.move(newPluginPath, pluginPath)
    logger.logMessage("Plugin installed at: " .. pluginPath)
end

local function downloadAndInstall(ctx, release)
    local workdir = LrFileUtils.chooseUniqueFileName(_PLUGIN.path)
    logger.logMessage("Creating temporary working directory: " .. workdir)
    ctx:addCleanupHandler(function()
        LrFileUtils.delete(workdir)
        logger.logMessage("Temporary working directory deleted: " .. workdir)
    end)
    local r = LrFileUtils.createDirectory(workdir)
    if not r then
        error("Cannot create temporary directory")
    end
    local zip = LrPathUtils.child(workdir, "download.zip")

    download(release, zip)
    extract(zip, workdir)
    install(workdir, _PLUGIN.path)
end

------------------------------------------------------------
-- Step 2: Retrieve latest release
------------------------------------------------------------
local function getLatestVersion()
    local url = Updates.baseUrl .. "repos/" .. Updates.repo .. "/releases/latest"
    local headers = {
        { field = "User-Agent", value = Updates.repo .. "/" .. Updates.version() },
        { field = "X-GitHub-Api-Version", value = "2022-11-28" },
    }

    logger.logMessage("Sending HTTP GET request to: " .. url)
    local data, respHeaders = LrHttp.get(url, headers)
    logger.logMessage("HTTP response headers: " .. json.encode(respHeaders))
    logger.logMessage("HTTP response data length: " .. tostring(#(data or "")))

    if respHeaders.error or respHeaders.status ~= 200 then
        error("Failed to fetch latest release: " .. tostring(respHeaders.error or respHeaders.status))
    end

    local success, release = pcall(json.decode, data)
    if not success then
        error("Failed to decode JSON response from GitHub")
    end

    logger.logMessage("Found latest release: " .. release.tag_name)

    -- Use "Source code (zip)" (zipball_url)
    release.assetToDownload = {
        browser_download_url = release.zipball_url,
        name = release.tag_name .. "-source.zip"
    }
    return release
end

------------------------------------------------------------
-- Step 3: Show update dialog
------------------------------------------------------------
local function showUpdateDialog(release, force)
    if release.tag_name ~= prefs.lastUpdateOffered then
        LrDialogs.resetDoNotShowFlag(Updates.actionPrefKey)
        prefs.lastUpdateOffered = release.tag_name
    end

    local info = LOC("$$$/iNat/PluginUpdateMessage=An update is available for the iNaturalist Publish Plugin. Would you like to download it now?")
    if release.body and #release.body > 0 then
        info = info .. "\n\n" .. release.body
    end

    local actionPrefKey = Updates.actionPrefKey
    if force then actionPrefKey = nil end

    local toDo = LrDialogs.promptForActionWithDoNotShow({
        message = LOC("$$$/iNat/PluginUpdateTitle=iNaturalist Publish Plugin Update Available"),
        info = info,
        actionPrefKey = actionPrefKey,
        verbBtns = {
            { label = LOC("$$$/iNat/Download=Download"), verb = "download" },
            { label = LOC("$$$/iNat/Ignore=Ignore"), verb = "ignore" },
        },
    })

    if toDo == "download" then
        if not release.assetToDownload then
            LrHttp.openUrlInBrowser(release.html_url)
            return
        end

        if LrTasks.execute("tar --help") == 0 then
            LrFunctionContext.callWithContext("downloadAndInstall", downloadAndInstall, release)
            LrDialogs.message(
                LOC("$$$/iNat/PluginInstalled=iNaturalist Publish Plugin update installed"),
                LOC("$$$/iNat/RestartLightroom=Please restart Lightroom"),
                "info"
            )
        else
            LrHttp.openUrlInBrowser(release.assetToDownload.browser_download_url)
        end
    else
        logger.logMessage("User chose not to download update: " .. tostring(toDo))
    end
end

------------------------------------------------------------
-- Step 4: Plugin version and update check
------------------------------------------------------------
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

    logger.logMessage("Plugin is up-to-date: " .. current)
    return current
end

function Updates.forceUpdate()
    LrTasks.startAsyncTask(function()
        local v = Updates.check(true)
        if v then
            LrDialogs.message(
                LOC("$$$/iNat/NoUpdates=No updates available"),
                string.format(LOC("$$$/iNat/MostRecentVersion=You have the most recent version of the iNaturalist Publish Plugin, %s"), v),
                "info"
            )
        end
    end)
end

return Updates

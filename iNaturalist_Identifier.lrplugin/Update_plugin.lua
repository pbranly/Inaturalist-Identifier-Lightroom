--[[---------------------------------------------------------------------------
    iNaturalist Publish Plugin - Automatic Updater
    ------------------------------------------------
    Functional Description:
    This script checks the latest release of the "iNaturalist Publish Plugin"
    from GitHub, downloads the "Source code (zip)" file, extracts it according
    to the operating system, and installs it by replacing the current plugin
    folder. It displays internationalized messages in English and logs all
    steps in detail using logger.lua.

    Modules and scripts used:
    -------------------------
    - logger.lua  : Logging utility for detailed debug/info messages
    - json.lua    : JSON decoding of GitHub API responses
    - Info.lua    : Plugin metadata (version, name, etc.)
    - LrPrefs     : Lightroom Preferences API
    - LrDialogs   : Lightroom Dialogs API
    - LrFileUtils : Lightroom File utilities
    - LrFunctionContext : Lightroom context handling
    - LrPathUtils : Lightroom Path utilities
    - LrHttp      : Lightroom HTTP utilities
    - LrTasks     : Lightroom Task scheduling

    Scripts using this script:
    --------------------------
    - This script is typically invoked from the plugin's main menu or
      automatically during startup checks.

    Process steps:
    --------------
    1. Detect the current plugin version.
    2. Fetch the latest release metadata from GitHub.
    3. Identify the "Source code (zip)" asset download URL.
    4. Prompt the user for update installation.
    5. Create a temporary working directory.
    6. Download the ZIP file.
    7. Extract ZIP using OS-specific method.
    8. Replace the existing plugin folder with the new one.
    9. Notify the user to restart Lightroom.

    Step-by-step description:
    -------------------------
    1. **Version detection**: Reads the local plugin version from Info.lua.
    2. **GitHub API request**: Sends GET request to `releases/latest`.
    3. **Asset selection**: Chooses the asset with "Source code (zip)" in its name.
    4. **User prompt**: Asks user if they want to download & install.
    5. **Temporary directory**: Creates unique directory for download/extraction.
    6. **Download ZIP**: Saves file locally, verifying write permissions.
    7. **Extraction**: On Unix/Mac → `tar -xf`; On Windows → PowerShell `Expand-Archive`.
    8. **Installation**: Moves the extracted plugin into the current plugin location.
    9. **Completion**: Displays info dialog about successful installation.

-----------------------------------------------------------------------------]]

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

-- Detect OS type
local function detectPlatform()
    local sep = package.config:sub(1,1)
    if sep == "\\" then
        return "windows"
    else
        return "unix"
    end
end

-- Quote shell arguments
local function shellquote(s)
    if MAC_ENV then
        s = s:gsub("'", "'\\''")
        return "'" .. s .. "'"
    else
        return '"' .. s .. '"'
    end
end

-- Step 2: Fetch latest release
local function getLatestVersion()
    local url = Updates.baseUrl .. "repos/" .. Updates.repo .. "/releases/latest"
    local headers = {
        { field = "User-Agent", value = Updates.repo .. "/" .. Updates.version() },
        { field = "X-GitHub-Api-Version", value = "2022-11-28" },
    }
    logger.logMessage("Step 2: Sending GET request to: " .. url)
    local data, respHeaders = LrHttp.get(url, headers)
    logger.logMessage("HTTP Response status: " .. tostring(respHeaders.status))
    logger.logMessage("HTTP Response headers: " .. json.encode(respHeaders))
    logger.logMessage("HTTP Response body: " .. tostring(data))

    if respHeaders.error or respHeaders.status ~= 200 then
        logger.logMessage("Error fetching latest release: " .. tostring(respHeaders.error))
        return
    end

    local success, release = pcall(json.decode, data)
    if not success then
        logger.logMessage("Error decoding JSON response.")
        return
    end

    logger.logMessage("Found latest release: " .. release.tag_name)
    return release
end

-- Step 6: Download the ZIP
local function download(url, filename)
    logger.logMessage("Downloading from URL: " .. url)
    local data, headers = LrHttp.get(url)
    logger.logMessage("HTTP download status: " .. tostring(headers.status))
    if headers.error then
        logger.logMessage("Download error: " .. tostring(headers.error))
        return false
    end

    if LrFileUtils.exists(filename) and not LrFileUtils.isWritable(filename) then
        error("Cannot write to download file")
    end

    local f = io.open(filename, "wb")
    f:write(data)
    f:close()
    logger.logMessage("File downloaded to: " .. filename)
end

-- Step 7: Extract ZIP
local function extract(filename, workdir)
    local platform = detectPlatform()
    logger.logMessage("Detected platform: " .. platform)

    local cmd
    if platform == "unix" then
        cmd = "tar -C " .. shellquote(workdir) .. " -xf " .. shellquote(filename)
    elseif platform == "windows" then
        cmd = 'powershell -Command "Expand-Archive -Force ' ..
              '"' .. filename .. '" ' ..
              '"' .. workdir .. '"'
    else
        error("Unsupported platform for extraction")
    end

    logger.logMessage("Executing extraction command: " .. cmd)
    local ret = LrTasks.execute(cmd)
    if ret ~= 0 then
        error("Extraction failed on " .. platform .. " platform")
    end
    logger.logMessage("Extraction completed in folder: " .. workdir)
end

-- Step 8: Install new plugin
local function install(workdir, pluginPath)
    local newPluginPath = nil
    for path in LrFileUtils.directoryEntries(workdir) do
        if path:find("%.lrplugin$") then
            newPluginPath = path
        end
    end
    local scratch = LrFileUtils.chooseUniqueFileName(newPluginPath)
    LrFileUtils.move(pluginPath, scratch)
    LrFileUtils.move(newPluginPath, pluginPath)
    logger.logMessage("Installed new plugin from: " .. newPluginPath)
end

-- Step 5 + 6 + 7 + 8 combined
local function downloadAndInstall(ctx, release)
    local workdir = LrFileUtils.chooseUniqueFileName(_PLUGIN.path)
    ctx:addCleanupHandler(function()
        LrFileUtils.delete(workdir)
    end)
    local r = LrFileUtils.createDirectory(workdir)
    if not r then
        error("Cannot create temporary directory")
    end
    local zip = LrPathUtils.child(workdir, "download.zip")

    -- Find the "Source code (zip)" asset
    local assetUrl
    for _, asset in ipairs(release.assets or {}) do
        if asset.name and asset.name:lower():find("source code") and asset.name:lower():find("zip") then
            assetUrl = asset.browser_download_url
            break
        end
    end
    if not assetUrl then
        logger.logMessage("Could not find 'Source code (zip)' asset in release.")
        error("Asset not found")
    end

    download(assetUrl, zip)
    extract(zip, workdir)
    install(workdir, _PLUGIN.path)
end

-- Step 4: Prompt user
local function showUpdateDialog(release, force)
    if release.tag_name ~= prefs.lastUpdateOffered then
        LrDialogs.resetDoNotShowFlag(Updates.actionPrefKey)
        prefs.lastUpdateOffered = release.tag_name
    end

    local info = LOC("$$$/iNat/UpdateAvailable=An update is available for the iNaturalist Publish Plugin. Would you like to download it now?")
    if release.body and #release.body > 0 then
        info = info .. "\n\n" .. release.body
    end

    local actionPrefKey = Updates.actionPrefKey
    if force then
        actionPrefKey = nil
    end

    local toDo = LrDialogs.promptForActionWithDoNotShow({
        message = LOC("$$$/iNat/UpdateTitle=iNaturalist Publish Plugin update available"),
        info = info,
        actionPrefKey = actionPrefKey,
        verbBtns = {
            { label = LOC("$$$/iNat/Download=Download"), verb = "download" },
            { label = LOC("$$$/iNat/Ignore=Ignore"), verb = "ignore" },
        },
    })
    if toDo == "download" then
        LrFunctionContext.callWithContext("downloadAndInstall", downloadAndInstall, release)
        LrDialogs.message(LOC("$$$/iNat/UpdateInstalled=iNaturalist Publish Plugin update installed"), LOC("$$$/iNat/RestartLightroom=Please restart Lightroom"), "info")
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
    logger.logMessage("Step 1: Running " .. (Info.VERSION.display or current))

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
                string.format(LOC("$$$/iNat/MostRecent=You have the most recent version of the iNaturalist Publish Plugin, %s"), v),
                "info"
            )
        end
    end)
end

return Updates

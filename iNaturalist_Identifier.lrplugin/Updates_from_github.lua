--[[============================================================================
Updates_from_github.lua
-------------------------------------------------------------------------------
Functional Description:
This module manages version checking, downloading, and installation of updates
for the iNaturalist Publish Plugin in Adobe Lightroom. It connects to GitHub to
retrieve the latest release, compares it with the current version, and prompts
the user to install the update if available.

Features:
1. Retrieve current plugin version from Info.lua
2. Query GitHub API for latest release
3. Compare versions and prompt user
4. Download release asset
5. Extract archive using tar
6. Replace current plugin with new version
7. Log all steps and HTTP traffic
8. Display internationalized messages

Modules Used:
- LrLogger
- LrPrefs
- LrDialogs
- LrFileUtils
- LrFunctionContext
- LrPathUtils
- LrHttp
- LrTasks
- Info.lua
- json

Scripts That Use This Module:
- PluginInfoProvider.lua

Execution Steps:
1. Get current plugin version
2. Query GitHub for latest release
3. Compare versions
4. Prompt user if update is available
5. Download release asset
6. Extract archive
7. Install plugin update
8. Clean up temporary files

============================================================================]]

local logger = import("LrLogger")("lr-inaturalist-publish")
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

function Updates.version()
    local v = Info.VERSION
    local formatted = string.format("%s.%s.%s", v.major, v.minor, v.revision)
    logger:trace("[Step 1] Current plugin version: " .. formatted)
    return formatted
end

local function getLatestVersion()
    local url = Updates.baseUrl .. "repos/" .. Updates.repo .. "/releases/latest"
    local headers = {
        { field = "User-Agent", value = Updates.repo .. "/" .. Updates.version() },
        { field = "X-GitHub-Api-Version", value = "2022-11-28" },
    }

    logger:trace("[Step 2] Sending HTTP GET to GitHub: " .. url)
    for _, h in ipairs(headers) do
        logger:trace("[Step 2] Header: " .. h.field .. ": " .. h.value)
    end

    local data, respHeaders = LrHttp.get(url, headers)

    logger:trace("[Step 2] Response status: " .. tostring(respHeaders.status))
    logger:trace("[Step 2] Response body: " .. tostring(data))

    if respHeaders.error or respHeaders.status ~= 200 then
        logger:error("[Step 2] GitHub API error or unexpected status code.")
        return
    end

    local success, release = pcall(json.decode, data)
    if not success then
        logger:error("[Step 2] Failed to decode GitHub JSON response.")
        return
    end

    logger:trace("[Step 2] Found latest release tag: " .. release.tag_name)
    return release
end

local function shellquote(s)
    if MAC_ENV then
        s = s:gsub("'", "'\\''")
        return "'" .. s .. "'"
    else
        return '"' .. s .. '"'
    end
end

local function download(release, filename)
    local url = release.assets[1].browser_download_url
    logger:trace("[Step 5] Downloading asset from: " .. url)

    local data, headers = LrHttp.get(url)
    logger:trace("[Step 5] Response status: " .. tostring(headers.status))
    logger:trace("[Step 5] Response error: " .. tostring(headers.error or "none"))

    if headers.error then
        logger:error("[Step 5] Download failed.")
        return false
    end

    if LrFileUtils.exists(filename) and not LrFileUtils.isWritable(filename) then
        error("Cannot write to download file")
    end

    local f = io.open(filename, "wb")
    f:write(data)
    f:close()
    logger:trace("[Step 5] File saved to: " .. filename)
end

local function extract(filename, workdir)
    local cmd = "tar -C " .. shellquote(workdir) .. " -xf " .. shellquote(filename)
    logger:trace("[Step 6] Extracting archive with command: " .. cmd)
    local ret = LrTasks.execute(cmd)
    if ret ~= 0 then
        logger:error("[Step 6] Extraction failed.")
        error("Could not extract downloaded release file")
    end
end

local function install(workdir, pluginPath)
    logger:trace("[Step 7] Installing plugin update.")
    local newPluginPath = nil
    for path in LrFileUtils.directoryEntries(workdir) do
        if path:find("%.lrplugin$") then
            newPluginPath = path
        end
    end
    local scratch = LrFileUtils.chooseUniqueFileName(newPluginPath)
    LrFileUtils.move(pluginPath, scratch)
    LrFileUtils.move(newPluginPath, pluginPath)
    logger:trace("[Step 7] Plugin replaced successfully.")
end

local function downloadAndInstall(ctx, release)
    logger:trace("[Step 4] Preparing temporary directory for install.")
    local workdir = LrFileUtils.chooseUniqueFileName(_PLUGIN.path)
    ctx:addCleanupHandler(function()
        LrFileUtils.delete(workdir)
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

local function showUpdateDialog(release, force)
    if release.tag_name ~= prefs.lastUpdateOffered then
        LrDialogs.resetDoNotShowFlag(Updates.actionPrefKey)
        prefs.lastUpdateOffered = release.tag_name
    end

    local info = LOC("$$$/iNat/UpdateAvailable=An update is available for the iNaturalist Publish Plugin. Would you like to download it now?")
    if release.body and #release.body > 0 then
        info = info .. "\n\n" .. release.body
    end

    local actionPrefKey = force and nil or Updates.actionPrefKey

    local toDo = LrDialogs.promptForActionWithDoNotShow({
        message = LOC("$$$/iNat/UpdateTitle=iNaturalist Publish Plugin update available"),
        info = info,
        actionPrefKey = actionPrefKey,
        verbBtns = {
            { label = LOC("$$$/iNat/Download=Download"), verb = "download" },
            { label = LOC("$$$/iNat/Ignore=Ignore"), verb = "ignore" },
        },
    })

    logger:trace("[Step 3] User response: " .. toDo)

    if toDo == "download" then
        if #release.assets ~= 1 then
            LrHttp.openUrlInBrowser(release.html_url)
            return
        end

        if LrTasks.execute("tar --help") == 0 then
            LrFunctionContext.callWithContext("downloadAndInstall", downloadAndInstall, release)
            LrDialogs.message(LOC("$$$/iNat/UpdateInstalled=Update installed"), LOC("$$$/iNat/Restart=Please restart Lightroom"), "info")
        else
            LrHttp.openUrlInBrowser(release.assets[1].browser_download_url)
        end
    end
end

function Updates.check(force)
    local current = Updates.version()
    logger:debug("[Step 1] Current version: " .. current)

    if not force and not prefs.checkForUpdates then
        logger:trace("[Step 1] Update check skipped due to preferences.")
        return
    end

    local release = getLatestVersion()
    if not release then
        logger:error("[Step 2] Failed to retrieve latest release.")
        return
    end

    local latest = release.tag_name:gsub("^v", "")
    local normalizedCurrent = current:gsub("^v", "")

    if normalizedCurrent ~= latest then
        logger:trace("[Step 3] Offering update from " .. normalizedCurrent .. " to " .. latest)
        showUpdateDialog(release, force)
        return
    end

    logger:trace("[Step 3] Plugin is up to date.")
    return current
end

function Updates.forceUpdate()
    LrTasks.startAsyncTask(function()
        local v = Updates.check(true)
        if v then
            LrDialogs.message(
                LOC("$$$/iNat/NoUpdate=No updates available"),
                LOC("$$$/iNat/NoUpdate=No updates available"),
                LOC("$$$/iNat/CurrentVersion=You are already using the latest version (" .. v .. ")"),
                "info"
            )
        end
    end)
end

return Updates               
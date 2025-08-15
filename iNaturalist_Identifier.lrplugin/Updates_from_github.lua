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
    logger:trace("[Version] Plugin actuel : " .. formatted)
    return formatted
end

local function getLatestVersion()
    local url = Updates.baseUrl .. "repos/" .. Updates.repo .. "/releases/latest"
    local headers = {
        { field = "User-Agent", value = Updates.repo .. "/" .. Updates.version() },
        { field = "X-GitHub-Api-Version", value = "2022-11-28" },
    }

    logger:trace("[GitHub] Requête vers : " .. url)
    local data, respHeaders = LrHttp.get(url, headers)

    if respHeaders.error or respHeaders.status ~= 200 then
        logger:error("[GitHub] Erreur HTTP : " .. tostring(respHeaders.error or respHeaders.status))
        return nil
    end

    local success, release = pcall(json.decode, data)
    if not success or not release then
        logger:error("[GitHub] Échec du décodage JSON.")
        return nil
    end

    logger:trace("[GitHub] Dernière version : " .. release.tag_name)
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
    logger:trace("[Téléchargement] URL : " .. url)
    local data, headers = LrHttp.get(url)

    if headers.error then
        logger:error("[Téléchargement] Erreur : " .. tostring(headers.error))
        return false
    end

    local f = io.open(filename, "wb")
    if not f then
        logger:error("[Téléchargement] Impossible d'écrire dans : " .. filename)
        return false
    end

    f:write(data)
    f:close()
    logger:trace("[Téléchargement] Archive enregistrée : " .. filename)
    return true
end

local function extract(filename, workdir)
    local cmd = "tar -C " .. shellquote(workdir) .. " -xf " .. shellquote(filename)
    logger:trace("[Extraction] Commande : " .. cmd)
    local ret = LrTasks.execute(cmd)
    if ret ~= 0 then
        logger:error("[Extraction] Échec avec code : " .. tostring(ret))
        error("Extraction échouée")
    end
end

local function install(workdir, pluginPath)
    logger:trace("[Installation] Recherche du nouveau dossier plugin...")
    local newPluginPath = nil
    for path in LrFileUtils.directoryEntries(workdir) do
        if path:find("%.lrplugin$") then
            newPluginPath = path
            break
        end
    end

    if not newPluginPath then
        logger:error("[Installation] Aucun dossier .lrplugin trouvé.")
        error("Installation échouée")
    end

    local backup = LrFileUtils.chooseUniqueFileName(pluginPath .. "_backup")
    LrFileUtils.move(pluginPath, backup)
    LrFileUtils.move(newPluginPath, pluginPath)
    logger:trace("[Installation] Nouveau plugin installé.")
end

local function downloadAndInstall(ctx, release)
    local workdir = LrFileUtils.chooseUniqueFileName(_PLUGIN.path)
    ctx:addCleanupHandler(function()
        LrFileUtils.delete(workdir)
        logger:trace("[Cleanup] Dossier temporaire supprimé.")
    end)

    if not LrFileUtils.createDirectory(workdir) then
        error("Impossible de créer le dossier temporaire")
    end

    local zip = LrPathUtils.child(workdir, "download.zip")
    if not download(release, zip) then return end
    extract(zip, workdir)
    install(workdir, _PLUGIN.path)
end

local function showUpdateDialog(release, force)
    if release.tag_name ~= prefs.lastUpdateOffered then
        LrDialogs.resetDoNotShowFlag(Updates.actionPrefKey)
        prefs.lastUpdateOffered = release.tag_name
    end

    local info = LOC("$$$/iNat/UpdateAvailable=Une mise à jour est disponible.")
    if release.body and #release.body > 0 then
        info = info .. "\n\n" .. release.body
    end

    local actionPrefKey = force and nil or Updates.actionPrefKey

    local toDo = LrDialogs.promptForActionWithDoNotShow({
        message = LOC("$$$/iNat/UpdateTitle=Mise à jour disponible"),
        info = info,
        actionPrefKey = actionPrefKey,
        verbBtns = {
            { label = LOC("$$$/iNat/Download=Télécharger"), verb = "download" },
            { label = LOC("$$$/iNat/Ignore=Ignorer"), verb = "ignore" },
        },
    })

    if toDo == "download" then
        if #release.assets ~= 1 then
            LrHttp.openUrlInBrowser(release.html_url)
            return
        end

        if LrTasks.execute("tar --help") == 0 then
            LrFunctionContext.callWithContext("downloadAndInstall", downloadAndInstall, release)
            LrDialogs.message(LOC("$$$/iNat/UpdateInstalled=Mise à jour installée"), LOC("$$$/iNat/Restart=Veuillez redémarrer Lightroom"), "info")
        else
            LrHttp.openUrlInBrowser(release.assets[1].browser_download_url)
        end
    end
end

function Updates.check(force)
    local current = Updates.version()
    if not force and not prefs.checkForUpdates then
        return
    end

    local release = getLatestVersion()
    if not release then return end

    local latest = release.tag_name:gsub("^v", "")
    local normalizedCurrent = current:gsub("^v", "")

    if normalizedCurrent ~= latest then
        showUpdateDialog(release, force)
    end

    return current
end

function Updates.forceUpdate()
    LrTasks.startAsyncTask(function()
        local v = Updates.check(true)
        if v then
            LrDialogs.message(
                LOC("$$$/iNat/NoUpdate=Aucune mise à jour disponible"),
                LOC("$$$/iNat/CurrentVersion=Version actuelle : " .. v),
                "info"
            )
        end
    end)
end

function Updates.getGitHubVersionInfoAsync(callback)
    LrTasks.startAsyncTask(function()
        local release = getLatestVersion()
        local current = Updates.version():gsub("^v", "")
        local latest = release and release.tag_name:gsub("^v", "") or "unknown"

        callback({
            current = current,
            latest = latest
        })
    end)
end

return Updates               
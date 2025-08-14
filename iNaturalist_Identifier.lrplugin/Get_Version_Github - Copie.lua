--[[
============================================================
Get_Version_GitHub.lua
------------------------------------------------------------
Récupère la dernière version disponible sur GitHub et calcule
le statut par rapport à la version locale du plugin.
============================================================
--]]

local LrHttp = import "LrHttp"
local LrTasks = import "LrTasks"
local logger = require("Logger")
local currentVersion = require("Get_Current_Version").getCurrentVersion()

local M = {}

-- URL de l'API GitHub
local GITHUB_API_URL = "https://api.github.com/repos/pbranly/Inaturalist-Identifier-Lightroom/releases/latest"

-- Récupération du dernier tag depuis GitHub
function M.getLatestTag()
    logger.logMessage("[GitHub] Initiating request to GitHub API for latest release...")

    local headers = {
        { field = "User-Agent", value = "iNat-Lightroom-Plugin" }
    }

    local result, hdrs = LrHttp.get(GITHUB_API_URL, headers)

    if not result or result == "" then
        logger.logMessage("[GitHub] Empty or failed response from GitHub API.")
        return nil
    end

    local tag = result:match('"tag_name"%s*:%s*"([^"]+)"')

    if tag then
        logger.logMessage("[GitHub] Latest tag retrieved: " .. tag)
        return tag
    else
        logger.logMessage("[GitHub] Failed to parse tag_name from API response.")
        return nil
    end
end

-- Comparaison version
function M.isNewerThanLocal(tag)
    return tag > currentVersion
end

function M.isSameAsLocal(tag)
    return tag == currentVersion
end

-- Renvoie toutes les infos de statut
function M.getVersionStatus()
    local tag = M.getLatestTag()
    local statusIcon, statusText

    if not tag then
        tag = "Unable to retrieve GitHub version"
        statusIcon = "❓"
        statusText = LOC("$$$/iNaturalist/VersionStatus/Unknown=GitHub version unknown")
    else
        if M.isNewerThanLocal(tag) then
            statusIcon = "⚠️"
            statusText = LOC("$$$/iNaturalist/VersionStatus/Outdated=Plugin outdated")
        elseif M.isSameAsLocal(tag) then
            statusIcon = "✅"
            statusText = LOC("$$$/iNaturalist/VersionStatus/UpToDate=Plugin up-to-date")
        else
            statusIcon = "ℹ️"
            statusText = LOC("$$$/iNaturalist/VersionStatus/Newer=Plugin newer than GitHub")
        end
    end

    return {
        githubTag = tag,
        currentVersion = currentVersion,
        statusIcon = statusIcon,
        statusText = statusText
    }
end

return M

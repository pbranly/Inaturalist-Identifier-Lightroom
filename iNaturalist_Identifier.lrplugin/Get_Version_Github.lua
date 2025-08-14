-- Get_Version_Github.lua
local LrHttp  = import "LrHttp"
local LrTasks = import "LrTasks"
local logger  = require("Logger")
local currentVersion = require("Get_Current_Version").getCurrentVersion()

local M = {}
local GITHUB_API_URL = "https://api.github.com/repos/pbranly/Inaturalist-Identifier-Lightroom/releases/latest"

-- Parse version string "vX.Y.Z" or "X.Y.Z"
local function parseVersion(ver)
    if not ver then return {0,0,0} end
    ver = ver:gsub("^v","")
    local maj,min,rev = ver:match("^(%d+)%.(%d+)%.(%d+)")
    return { tonumber(maj) or 0, tonumber(min) or 0, tonumber(rev) or 0 }
end

local function isNewer(v1,v2)
    for i=1,3 do
        if v1[i]>v2[i] then return true end
        if v1[i]<v2[i] then return false end
    end
    return false
end

local function isSame(v1,v2)
    return v1[1]==v2[1] and v1[2]==v2[2] and v1[3]==v2[3]
end

-- Async fetch of GitHub latest tag
function M.getLatestTagAsync(callback)
    LrTasks.startAsyncTask(function()
        logger.logMessage("[GitHub] Fetching latest release from GitHub...")
        local headers = { { field = "User-Agent", value = "iNat-Lightroom-Plugin" } }
        local body = LrHttp.get(GITHUB_API_URL, headers)
        local tag = nil
        if body then
            tag = body:match('"tag_name"%s*:%s*"([^"]+)"')
        end
        callback(tag)
    end)
end

-- Build status object
function M.getVersionStatusAsync(callback)
    M.getLatestTagAsync(function(tag)
        local statusIcon, statusText
        local localParsed = parseVersion(currentVersion)

        if not tag then
            tag = "Unable to retrieve GitHub version"
            statusIcon = "❓"
            statusText = "GitHub version unknown"
        else
            local ghParsed = parseVersion(tag)
            if isNewer(ghParsed, localParsed) then
                statusIcon = "⚠️"
                statusText = "Plugin outdated"
            elseif isSame(ghParsed, localParsed) then
                statusIcon = "✅"
                statusText = "Plugin up-to-date"
            else
                statusIcon = "ℹ️"
                statusText = "Plugin newer than GitHub"
            end
        end

        callback({
            githubTag = tag,
            currentVersion = currentVersion,
            statusIcon = statusIcon,
            statusText = statusText
        })
    end)
end

return M

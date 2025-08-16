--[[
=====================================================================
Functional Description
---------------------------------------------------------------------
This module checks the latest available plugin version on GitHub and 
compares it to the currently installed version.

It provides two main functions:
1. getLatestTagAsync(callback) - Asynchronously retrieves the latest 
   GitHub release tag.
2. getVersionStatusAsync(callback) - Compares the latest GitHub 
   version with the current plugin version and returns a status object.

Comparison logic:
- Plugin outdated
- Plugin up-to-date
- Local plugin newer than GitHub
- GitHub version unknown

Modules and Scripts Used:
- Lightroom SDK:
    * LrHttp   → HTTP GET requests
    * LrTasks  → Async task execution
    * LrLocalization → for LOC()
- Internal Modules:
    * Logger.lua
    * Get_Current_Version.lua

Scripts That Use This Script:
- Plugin Manager UI dialog
- Auto-update / version-checking features
=====================================================================
]]

local LrHttp        = import "LrHttp"
local LrTasks       = import "LrTasks"
local logger        = require("Logger")
local currentVersion = require("Get_Current_Version").getCurrentVersion()

-- Robust LOC
local LrLocalization = import 'LrLocalization'
local LOC = (LrLocalization and LrLocalization.LOC) or function(s) return s:gsub("%$%$%$/.-=", "") end

local M = {}
local GITHUB_API_URL = "https://api.github.com/repos/pbranly/Inaturalist-Identifier-Lightroom/releases/latest"

-- Step 3: Parse version string "vX.Y.Z" or "X.Y.Z"
local function parseVersion(ver)
    logger.logMessage("[Step 3] Parsing version string: " .. tostring(ver))
    if not ver then return {0,0,0} end
    ver = ver:gsub("^v","")
    local maj,min,rev = ver:match("^(%d+)%.(%d+)%.(%d+)")
    return { tonumber(maj) or 0, tonumber(min) or 0, tonumber(rev) or 0 }
end

-- Step 4: Compare if v1 is newer than v2
local function isNewer(v1,v2)
    logger.logMessage(string.format("[Step 4] Comparing if %s is newer than %s", table.concat(v1,"."), table.concat(v2,".")))
    for i=1,3 do
        if v1[i]>v2[i] then return true end
        if v1[i]<v2[i] then return false end
    end
    return false
end

-- Step 5: Check if versions are the same
local function isSame(v1,v2)
    logger.logMessage(string.format("[Step 5] Checking if %s is same as %s", table.concat(v1,"."), table.concat(v2,".")))
    return v1[1]==v2[1] and v1[2]==v2[2] and v1[3]==v2[3]
end

-- Step 6: Async fetch of GitHub latest tag with detailed logging
function M.getLatestTagAsync(callback)
    logger.logMessage("[Step 6] Starting async fetch of latest GitHub tag.")
    LrTasks.startAsyncTask(function()
        logger.logMessage("[GitHub] URL: " .. GITHUB_API_URL)

        local headers_in = { { field = "User-Agent", value = "iNat-Lightroom-Plugin" } }
        for _, h in ipairs(headers_in) do
            logger.logMessage(string.format("[GitHub] Request header: %s = %s", h.field, h.value))
        end

        local body, headers_out, status_code = LrHttp.get(GITHUB_API_URL, headers_in)

        logger.logMessage("[GitHub] HTTP status code: " .. tostring(status_code))

        if headers_out then
            logger.logMessage("[GitHub] Response headers:")
            for _, h in ipairs(headers_out) do
                logger.logMessage(string.format("   %s = %s", tostring(h.field), tostring(h.value)))
            end
        else
            logger.logMessage("[GitHub] No response headers received.")
        end

        local tag = nil
        if body then
            logger.logMessage("[GitHub] Raw body received:")
            logger.logMessage(body)

            -- Try to parse JSON tag_name
            tag = body:match('"tag_name"%s*:%s*"v?([%d%.]+)"')
            logger.logMessage("[GitHub] Parsed tag_name: " .. tostring(tag))
        else
            logger.logMessage("[GitHub] No response body received.")
        end

        callback(tag)
    end)
end

-- Step 7: Compare GitHub version with local version
function M.getVersionStatusAsync(callback)
    logger.logMessage("[Step 7] Getting version status comparison.")
    M.getLatestTagAsync(function(tag)
        local statusIcon, statusText
        local localParsed = parseVersion(currentVersion)

        if not tag then
            tag = LOC("$$$/iNat/GitHubVersionError=Unable to retrieve GitHub version")
            statusIcon = "❓"
            statusText = LOC("$$$/iNat/GitHubVersionUnknown=GitHub version unknown")
        else
            local ghParsed = parseVersion(tag)
            if isNewer(ghParsed, localParsed) then
                statusIcon = "⚠️"
                statusText = LOC("$$$/iNat/PluginOutdated=Plugin outdated")
            elseif isSame(ghParsed, localParsed) then
                statusIcon = "✅"
                statusText = LOC("$$$/iNat/PluginUpToDate=Plugin up-to-date")
            else
                statusIcon = "ℹ️"
                statusText = LOC("$$$/iNat/PluginNewerThanGitHub=Plugin newer than GitHub")
            end
        end

        logger.logMessage(string.format(
            "[GitHub] %s %s — %s %s",
            LOC("$$$/iNat/PluginCurrentVersion=Plugin current version"),
            currentVersion,
            LOC("$$$/iNat/LatestGithubVersion=Latest GitHub version"),
            tag
        ))
        logger.logMessage(string.format("[GitHub] Status: %s - %s", statusIcon, statusText))

        callback({
            githubTag = tag,
            currentVersion = currentVersion,
            statusIcon = statusIcon,
            statusText = statusText
        })
    end)
end

-- Step 8: Return API table
return M

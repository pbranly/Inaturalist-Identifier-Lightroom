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

The comparison logic determines whether:
- The plugin is outdated.
- The plugin is up-to-date.
- The local plugin version is newer than the GitHub release.
- The GitHub version could not be retrieved.

Modules and Scripts Used:
- Lightroom SDK:
    * LrHttp   → HTTP GET requests to GitHub API.
    * LrTasks  → Asynchronous task execution.
    * LrLocalization → for LOC()
- Internal Modules:
    * Logger.lua               → Logging operations.
    * Get_Current_Version.lua  → Provides the installed plugin version.

Scripts That Use This Script:
- Plugin Manager UI dialog (for displaying GitHub vs local version).
- Any auto-update or version-checking feature.

Execution Steps:
1. Import required modules and logger.
2. Define GitHub API endpoint URL.
3. Create a version parsing function.
4. Create a version comparison function (isNewer).
5. Create a version equality function (isSame).
6. Define getLatestTagAsync() to fetch latest GitHub version.
7. Define getVersionStatusAsync() to compare and return status.
8. Return public API table.
=====================================================================
]]

local LrHttp  = import "LrHttp"
local LrTasks = import "LrTasks"
local logger  = require("Logger")
local currentVersion = require("Get_Current_Version").getCurrentVersion()

-- Robust LOC: use Lightroom LOC if available, else fallback stripping key
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

-- Step 4: Check if v1 is newer than v2
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

-- Step 6: Async fetch of GitHub latest tag
function M.getLatestTagAsync(callback)
    logger.logMessage("[Step 6] Starting async fetch of latest GitHub tag.")
    LrTasks.startAsyncTask(function()
        logger.logMessage("[GitHub] Sending request to: " .. GITHUB_API_URL)
        local headers = { { field = "User-Agent", value = "iNat-Lightroom-Plugin" } }
        local body = LrHttp.get(GITHUB_API_URL, headers)
        local tag = nil
        if body then
            tag = body:match('"tag_name"%s*:%s*"([^"]+)"')
            logger.logMessage("[GitHub] Latest tag retrieved: " .. tostring(tag))
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

        -- Log line displaying current vs latest GitHub version
        logger.logMessage(string.format(
            "[GitHub] %s %s — %s %s",
            LOC("$$$/iNat/PluginCurrentVersion=Plugin current version"),
            currentVersion,
            LOC("$$$/iNat/LatestGithubVersion=Latest GitHub version"),
            tag
        ))

        -- Log line for status
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

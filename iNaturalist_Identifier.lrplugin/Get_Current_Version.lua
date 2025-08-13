--[[
============================================================
Functional Description
------------------------------------------------------------
This module handles retrieval and comparison of plugin versions
between the local Lightroom plugin installation and the latest
release available on GitHub.

It consolidates all logic related to:
1. Contacting GitHub's API to retrieve the latest release tag.
2. Comparing the retrieved tag with the local plugin version.
3. Returning a complete status package (tag, version, icon, text)
   to be directly consumed by the plugin's Preferences dialog.

By centralizing the status calculation here, we:
- Avoid duplicating the same status indicator logic in the UI.
- Simplify maintenance if comparison rules or display logic change.
- Keep UI scripts focused solely on layout and event handling.

============================================================
Modules Used:
------------------------------------------------------------
1. LrHttp               : Performs HTTP GET requests to GitHub API.
2. Logger               : Writes debug and activity messages to log.txt.
3. Get_Current_Version  : Retrieves the local plugin's version number.
============================================================
--]]

local LrHttp  = import "LrHttp"
local logger  = require("Logger")
local currentVersion = require("Get_Current_Version").getCurrentVersion()

local M = {}

-- URL for the GitHub REST API endpoint returning the latest release info
local GITHUB_API_URL =
    "https://api.github.com/repos/pbranly/Inaturalist-Identifier-Lightroom/releases/latest"

--[[
------------------------------------------------------------
getLatestTag()
------------------------------------------------------------
Fetches the latest GitHub release tag_name using a synchronous
HTTP GET request. This method is blocking, meaning Lightroom
will wait until GitHub responds or times out.

Returns:
- tag (string) if successfully retrieved, e.g., "v1.2.3"
- nil if retrieval or parsing failed
------------------------------------------------------------
--]]
function M.getLatestTag()
    logger.logMessage("[GitHub] Initiating request to GitHub API for latest release...")

    local headers = {
        { field = "User-Agent", value = "iNat-Lightroom-Plugin" }
    }

    local body, hdrs = LrHttp.get(GITHUB_API_URL, headers)

    if not body or body == "" then
        logger.logMessage("[GitHub] Empty or failed response from GitHub API.")
        return nil
    end

    -- Extract "tag_name": "value" from JSON manually
    local tag = body:match('"tag_name"%s*:%s*"([^"]+)"')

    if tag then
        logger.logMessage("[GitHub] Latest tag retrieved: " .. tag)
        return tag
    else
        logger.logMessage("[GitHub] Failed to parse tag_name from API response.")
        return nil
    end
end

--[[
------------------------------------------------------------
Version Comparison Utilities
------------------------------------------------------------
These helper functions provide explicit comparisons between
a retrieved GitHub version tag and the local plugin version.

Notes:
- Comparison is lexicographical, so ensure versions are
  consistent in format (e.g., "v1.2.3").
------------------------------------------------------------
--]]
function M.isNewerThanLocal(tag)
    return tag > currentVersion
end

function M.isSameAsLocal(tag)
    return tag == currentVersion
end

--[[
------------------------------------------------------------
getVersionStatus()
------------------------------------------------------------
Retrieves the latest GitHub tag, compares it to the local version,
and returns a table containing:
    githubTag      : The latest GitHub release tag or an error string
    currentVersion : The local plugin version string
    statusIcon     : Emoji indicator ("✅", "⚠️", "ℹ️", "❓")
    statusText     : Localized description of the status

This centralizes:
- Status calculation
- Icon selection
- Localized status messages

This way, the UI code just displays the returned values.
------------------------------------------------------------
--]]
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

--[[
============================================================
Functional Description
------------------------------------------------------------
This module retrieves the latest version tag of the plugin
from GitHub, compares it to the currently installed local
version, and returns a detailed status result.

It is intended to be called both:
1. During the plugin Preferences dialog initialization.
2. When the user explicitly presses the "Version GitHub" button.

The returned status object includes:
- The GitHub latest version tag.
- The local plugin version string.
- An icon indicating the status.
- A human-readable status text.

============================================================
Modules Used:
------------------------------------------------------------
1. LrHttp
   - Performs the HTTP GET request to GitHub's REST API.

2. Logger
   - Writes detailed debug and activity messages to log.txt.
   - Helps trace network calls and decision-making steps.

3. Get_Current_Version
   - Retrieves the local plugin's version number in string form.
   - Example: "0.1.6"

============================================================
Dependent Scripts:
------------------------------------------------------------
1. PluginInfoProvider.lua
   - Displays the current and latest GitHub versions in the UI.
   - Uses getVersionStatus() to fetch both versions and status.

2. Get_Current_Version.lua
   - Supplies the local plugin version string to compare.

============================================================
Version Comparison Rules:
------------------------------------------------------------
- If GitHub version > local version → "⚠️ Plugin outdated"
- If GitHub version == local version → "✅ Plugin up-to-date"
- If GitHub version < local version → "ℹ️ Plugin newer than GitHub"
- If GitHub API request fails → "❓ GitHub version unknown"

============================================================
Step-by-Step Logic:
------------------------------------------------------------
1. Fetch the local plugin version from Get_Current_Version.lua.
2. Send an HTTP GET request to GitHub's latest release API endpoint.
3. Extract the "tag_name" value from the JSON response.
4. Remove any leading "v" from the tag.
5. Parse both GitHub and local versions into numeric {major, minor, revision}.
6. Compare versions numerically, not lexicographically.
7. Select the appropriate status icon and status text.
8. Return a status table with all relevant data for the UI.

============================================================
Logging:
------------------------------------------------------------
- Each major step is logged to the Logger module with a prefix:
  [GitHub] for API operations
  [VersionCompare] for comparison logic
- Logs include raw data (tag_name, parsed versions) to help debugging.

============================================================
--]]

-----------------------------------
--  Step 0 : Imports and Constants
-----------------------------------
local LrHttp  = import "LrHttp"
local logger  = require("Logger")
local currentVersion = require("Get_Current_Version").getCurrentVersion()

local M = {}

-- GitHub REST API endpoint for the latest release info
local GITHUB_API_URL =
    "https://api.github.com/repos/pbranly/Inaturalist-Identifier-Lightroom/releases/latest"

-----------------------------------
--  Step 1 : Version Parsing Utils
-----------------------------------

-- Parse a version string into a numeric table {major, minor, revision}
local function parseVersion(ver)
    logger.logMessage("[VersionCompare] Parsing version string: " .. tostring(ver))
    if not ver then return {0,0,0} end
    ver = ver:gsub("^v", "") -- remove leading "v" if present
    local maj, min, rev = ver:match("^(%d+)%.(%d+)%.(%d+)")
    maj, min, rev = tonumber(maj) or 0, tonumber(min) or 0, tonumber(rev) or 0
    logger.logMessage(string.format("[VersionCompare] Parsed numeric version: %d.%d.%d", maj, min, rev))
    return { maj, min, rev }
end

-- Compare if v1 is newer than v2
local function isNewer(v1, v2)
    for i=1,3 do
        if v1[i] > v2[i] then return true end
        if v1[i] < v2[i] then return false end
    end
    return false
end

-- Compare if v1 is exactly the same as v2
local function isSame(v1, v2)
    return v1[1] == v2[1] and v1[2] == v2[2] and v1[3] == v2[3]
end

-----------------------------------
--  Step 2 : Fetch GitHub Version
-----------------------------------
function M.getLatestTag()
    logger.logMessage("[GitHub] Step 2.1 - Initiating request to GitHub API for latest release...")

    local headers = {
        { field = "User-Agent", value = "iNat-Lightroom-Plugin" }
    }

    local body, hdrs = LrHttp.get(GITHUB_API_URL, headers)

    if not body or body == "" then
        logger.logMessage("[GitHub] Step 2.2 - Empty or failed response from GitHub API.")
        return nil
    end

    logger.logMessage("[GitHub] Step 2.3 - Raw JSON response received.")
    logger.logMessage(body)

    -- Extract "tag_name" value from JSON
    local tag = body:match('"tag_name"%s*:%s*"([^"]+)"')

    if tag then
        logger.logMessage("[GitHub] Step 2.4 - Latest tag retrieved: " .. tag)
        return tag
    else
        logger.logMessage("[GitHub] Step 2.5 - Failed to parse tag_name from API response.")
        return nil
    end
end

-----------------------------------
--  Step 3 : Version Status Builder
-----------------------------------
function M.getVersionStatus()
    logger.logMessage("[VersionCompare] Step 3.1 - Starting version comparison process.")

    local tag = M.getLatestTag()
    local statusIcon, statusText

    -- Parse local version
    local currentParsed = parseVersion(currentVersion)

    if not tag then
        -- GitHub version retrieval failed
        tag = "Unable to retrieve GitHub version"
        statusIcon = "❓"
        statusText = LOC("$$$/iNaturalist/VersionStatus/Unknown=GitHub version unknown")
        logger.logMessage("[VersionCompare] Step 3.2 - GitHub version unknown.")
    else
        -- Parse GitHub version
        local githubParsed = parseVersion(tag)

        -- Compare GitHub vs Local
        if isNewer(githubParsed, currentParsed) then
            statusIcon = "⚠️"
            statusText = LOC("$$$/iNaturalist/VersionStatus/Outdated=Plugin outdated")
            logger.logMessage(string.format("[VersionCompare] Step 3.3 - GitHub version %s is newer than local %s.", tag, currentVersion))
        elseif isSame(githubParsed, currentParsed) then
            statusIcon = "✅"
            statusText = LOC("$$$/iNaturalist/VersionStatus/UpToDate=Plugin up-to-date")
            logger.logMessage(string.format("[VersionCompare] Step 3.4 - Local version %s is the same as GitHub %s.", currentVersion, tag))
        else
            statusIcon = "ℹ️"
            statusText = LOC("$$$/iNaturalist/VersionStatus/Newer=Plugin newer than GitHub")
            logger.logMessage(string.format("[VersionCompare] Step 3.5 - Local version %s is newer than GitHub %s.", currentVersion, tag))
        end
    end

    logger.logMessage("[VersionCompare] Step 3.6 - Returning status object to UI.")

    return {
        githubTag = tag,
        currentVersion = currentVersion,
        statusIcon = statusIcon,
        statusText = statusText
    }
end

return M

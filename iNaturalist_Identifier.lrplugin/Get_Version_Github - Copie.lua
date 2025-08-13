--[[
Get_Version_GitHub.lua

This module handles version management for the iNaturalist Lightroom plugin.
It retrieves the latest release tag from GitHub and compares it with the local plugin version.

📦 Required Lua modules:
- PluginVersion.lua → Defines the local plugin version
- Logger.lua        → Logs detailed messages to log.txt

📋 Steps:
1. Load local version and HTTP module
2. Fetch latest GitHub release tag using LrHttp
3. Parse tag into version structure
4. Compare remote and local versions
5. Return version info as string
]]

-- [Step 1] Load required modules
local PluginVersion = require("PluginVersion")
local logger        = require("Logger")
local LrHttp        = import("LrHttp")

-- [Step 2] Define module
local M = {}

-- [Step 3] Fetch latest GitHub release tag using LrHttp
function M.getLatestTag()
    logger.logMessage("[GitHub] Initiating request to GitHub API for latest release...")

    local url = "https://api.github.com/repos/pbranly/Inaturalist-Identifier-Lightroom/releases/latest"
    local response = LrHttp.get(url)

    if not response or response == "" then
        logger.logMessage("[GitHub] Empty or failed response from GitHub API.")
        return nil, nil
    end

    local tag = response:match('"tag_name"%s*:%s*"([^"]+)"')
    local html_url = response:match('"html_url"%s*:%s*"([^"]+)"')

    if tag and html_url then
        logger.logMessage("[GitHub] Retrieved tag: " .. tag)
        logger.logMessage("[GitHub] Release URL: " .. html_url)
        return tag, html_url
    else
        logger.logMessage("[GitHub] Failed to parse tag_name or html_url from response.")
        return nil, nil
    end
end

-- [Step 4] Parse a tag string like "0.1.5" into a version table
function M.parseTag(tag)
    logger.logMessage("[GitHub] Parsing tag: " .. tostring(tag))
    local major, minor, revision = tag:match("(%d+)%.(%d+)%.(%d+)")
    if not major then
        logger.logMessage("[GitHub] Invalid tag format. Expected format: X.Y.Z")
        return nil
    end

    local parsed = {
        major = tonumber(major),
        minor = tonumber(minor),
        revision = tonumber(revision),
        build = 0 -- GitHub does not provide build number
    }

    logger.logMessage(string.format("[GitHub] Parsed version: %d.%d.%d.%d", parsed.major, parsed.minor, parsed.revision, parsed.build))
    return parsed
end

-- [Step 5] Convert a version table into a comparable number
local function toNumber(v)
    return v.major * 1000000 + v.minor * 10000 + v.revision * 100 + v.build
end

-- [Step 6] Compare if GitHub version is newer than local
function M.isNewerThanLocal(tag)
    logger.logMessage("[GitHub] Comparing remote version with local version...")
    local remote = M.parseTag(tag)
    if not remote then
        logger.logMessage("[GitHub] Remote version parsing failed.")
        return false
    end

    local result = toNumber(remote) > toNumber(PluginVersion)
    logger.logMessage("[GitHub] isNewerThanLocal: " .. tostring(result))
    return result
end

-- [Step 7] Compare if GitHub version is older than local
function M.isOlderThanLocal(tag)
    logger.logMessage("[GitHub] Comparing if remote version is older than local...")
    local remote = M.parseTag(tag)
    if not remote then
        logger.logMessage("[GitHub] Remote version parsing failed.")
        return false
    end

    local result = toNumber(remote) < toNumber(PluginVersion)
    logger.logMessage("[GitHub] isOlderThanLocal: " .. tostring(result))
    return result
end

-- [Step 8] Compare if GitHub version is equal to local
function M.isSameAsLocal(tag)
    logger.logMessage("[GitHub] Comparing if remote version is equal to local...")
    local remote = M.parseTag(tag)
    if not remote then
        logger.logMessage("[GitHub] Remote version parsing failed.")
        return false
    end

    local result = toNumber(remote) == toNumber(PluginVersion)
    logger.logMessage("[GitHub] isSameAsLocal: " .. tostring(result))
    return result
end

-- [Step 9] Return local version as string
function M.getLocalVersionString()
    local v = PluginVersion
    local versionString = string.format("%d.%d.%d.%d", v.major, v.minor, v.revision, v.build)
    logger.logMessage("[GitHub] Local version string: " .. versionString)
    return versionString
end

return M
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
5. Format and return version info as string
]]


local PluginVersion = require("PluginVersion")
local logger        = require("Logger")
local LrHttp        = import("LrHttp")
local LrTasks       = import("LrTasks")

local M = {}

--[[
    Fetch latest GitHub release asynchronously.
    @param callback: function(tag, html_url) called when request finishes
]]
function M.getLatestTagAsync(callback)
    local url = "https://api.github.com/repos/pbranly/Inaturalist-Identifier-Lightroom/releases/latest"
    logger.logMessage("[GitHub] Initiating async request to GitHub API for latest release...")
    logger.logMessage("[GitHub] URL: " .. url)

    -- Mandatory GitHub User-Agent header
    local headers = { { field = "User-Agent", value = "iNat-Lightroom-Plugin" } }
    for i,h in ipairs(headers) do
        logger.logMessage(string.format("[GitHub] Header %d: %s = %s", i, h.field, h.value))
    end

    -- Start asynchronous task
    LrTasks.startAsyncTask(function()
        local response, metadata
        local ok, err = pcall(function()
            response, metadata = LrHttp.get(url, headers)
        end)

        if not ok then
            logger.logMessage("[GitHub] LrHttp.get() failed: " .. tostring(err))
            callback(nil, nil)
            return
        end

        if not response or response == "" then
            logger.logMessage("[GitHub] Empty response body.")
            if metadata then
                for k,v in pairs(metadata) do
                    logger.logMessage(string.format("[GitHub] Metadata[%s] = %s", tostring(k), tostring(v)))
                end
            end
            callback(nil, nil)
            return
        end

        logger.logMessage(string.format("[GitHub] Response length: %d chars", #response))
        logger.logMessage("[GitHub] Response preview: " .. response:sub(1,200) .. "...")

        local tag = response:match('"tag_name"%s*:%s*"([^"]+)"')
        local html_url = response:match('"html_url"%s*:%s*"([^"]+)"')

        if tag and html_url then
            logger.logMessage("[GitHub] Parsed tag_name: " .. tag)
            logger.logMessage("[GitHub] Parsed html_url: " .. html_url)
            callback(tag, html_url)
        else
            logger.logMessage("[GitHub] Failed to parse tag_name or html_url.")
            callback(nil, nil)
        end
    end)
end

-- Parse tag like "0.1.5" into version table
function M.parseTag(tag)
    logger.logMessage("[GitHub] Parsing tag: " .. tostring(tag))
    local major, minor, revision = tag:match("(%d+)%.(%d+)%.(%d+)")
    if not major then
        logger.logMessage("[GitHub] Invalid tag format. Expected X.Y.Z, got: " .. tostring(tag))
        return nil
    end

    local parsed = {
        major = tonumber(major),
        minor = tonumber(minor),
        revision = tonumber(revision),
        build = 0
    }
    logger.logMessage(string.format("[GitHub] Parsed version: %d.%d.%d.%d", parsed.major, parsed.minor, parsed.revision, parsed.build))
    return parsed
end

local function toNumber(v)
    local num = v.major * 1000000 + v.minor * 10000 + v.revision * 100 + v.build
    logger.logMessage(string.format("[GitHub] toNumber: %d.%d.%d.%d => %d", v.major, v.minor, v.revision, v.build, num))
    return num
end

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

function M.getLocalVersionString()
    local v = PluginVersion
    local versionString = string.format("%d.%d.%d.%d", v.major, v.minor, v.revision, v.build)
    logger.logMessage("[GitHub] Local version string: " .. versionString)
    return versionString
end

function M.getLocalVersionFormatted()
    local formatted = "Current plugin version: " .. M.getLocalVersionString()
    logger.logMessage("[GitHub] Formatted local version: " .. formatted)
    return formatted
end

return M

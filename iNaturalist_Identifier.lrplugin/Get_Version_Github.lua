-- Get_Version_GitHub.lua
--[[
============================================================
Functional Description:
------------------------------------------------------------
This module handles version management for the iNaturalist Lightroom plugin.
It retrieves the latest release tag from GitHub and compares it with the local plugin version.

Modules/Dependencies:
------------------------------------------------------------
- PluginVersion.lua
- Logger.lua
- Lightroom SDK modules: LrHttp, LrTasks
============================================================
--]]

local PluginVersion = require("PluginVersion")
local logger        = require("Logger")
local LrHttp        = import("LrHttp")
local LrTasks       = import("LrTasks")

local M = {}

-- Helper: convert version table to number for comparison
local function toNumber(v)
    return v.major * 1000000 + v.minor * 10000 + v.revision * 100 + v.build
end

-- Parse tag like "0.1.5" into version table
function M.parseTag(tag)
    if not tag then return nil end
    local major, minor, revision = tag:match("(%d+)%.(%d+)%.(%d+)")
    if not major then return nil end
    return {
        major = tonumber(major),
        minor = tonumber(minor),
        revision = tonumber(revision),
        build = 0
    }
end

-- Compare remote tag with local version
function M.isNewerThanLocal(tag)
    local remote = M.parseTag(tag)
    if not remote then return false end
    return toNumber(remote) > toNumber(PluginVersion)
end

function M.isOlderThanLocal(tag)
    local remote = M.parseTag(tag)
    if not remote then return false end
    return toNumber(remote) < toNumber(PluginVersion)
end

function M.isSameAsLocal(tag)
    local remote = M.parseTag(tag)
    if not remote then return false end
    return toNumber(remote) == toNumber(PluginVersion)
end

function M.getLocalVersionString()
    local v = PluginVersion
    return string.format("%d.%d.%d.%d", v.major, v.minor, v.revision, v.build)
end

function M.getLocalVersionFormatted()
    return "Current plugin version: " .. M.getLocalVersionString()
end

-- Separate function for HTTP request to GitHub
local function fetchGitHubRelease(url, headers, callback)
    local response, metadata
    local function safeGet()
        response, metadata = LrHttp.get(url, headers)
    end

    local ok, err = pcall(safeGet)
    if not ok then
        logger.logMessage("[GitHub] LrHttp.get() failed: " .. tostring(err))
        callback(nil, nil)
        return
    end

    if not response or response == "" then
        logger.logMessage("[GitHub] Empty response body.")
        callback(nil, nil)
        return
    end

    local tag = response:match('"tag_name"%s*:%s*"([^"]+)"')
    local html_url = response:match('"html_url"%s*:%s*"([^"]+)"')

    callback(tag, html_url)
end

-- Public async function to get latest GitHub tag
function M.getLatestTagAsync(callback)
    local url = "https://api.github.com/repos/pbranly/Inaturalist-Identifier-Lightroom/releases/latest"
    local headers = { { field = "User-Agent", value = "iNat-Lightroom-Plugin" } }

    logger.logMessage("[GitHub] Initiating async request to GitHub API...")

    LrTasks.startAsyncTask(function()
        fetchGitHubRelease(url, headers, callback)
    end)
end

return M

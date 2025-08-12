--[[
=====================================================================================
 Script       : check_plugin_version.lua
 Purpose      : Compare current plugin version (from Info.lua) with latest release 
                version on GitHub and notify user if a newer version is available.

 Functional Overview:
 This script reads the plugin version from Info.lua and fetches the latest release
 version from the GitHub releases API. It compares the major, minor, and revision 
 numbers. If the GitHub release version is newer, it shows an internationalized 
 notification with the latest version number.

 Dependencies:
 - Lightroom SDK modules: LrHttp, LrTasks, LrDialogs, LrApplication
 - Access to Info.lua in the same directory or via proper require path
 - Internet connection to access GitHub API

 Workflow Steps:
 1. Load the current plugin version from Info.lua.
 2. Make an HTTP GET request to GitHub API for the latest release data.
 3. Parse the JSON response and extract the 'tag_name' field.
 4. Parse both current and latest versions into numeric major, minor, revision.
 5. Compare versions in order: major, minor, revision.
 6. If GitHub version is newer, display a message with the new version number.
 7. Log all main steps and any errors encountered.

=====================================================================================
--]]

-- Lightroom SDK modules
local LrHttp    = import "LrHttp"
local LrTasks   = import "LrTasks"
local LrDialogs = import "LrDialogs"
local logger    = require("Logger")  -- Assumed custom logger module for logging

-- Load Info.lua to get current plugin version
local info = require("Info")

-- Helper function: parse version string "0.1.4" -> major=0, minor=1, revision=4
local function parseVersion(versionString)
    local major, minor, revision = versionString:match("^(%d+)%.(%d+)%.(%d+)")
    if major and minor and revision then
        return tonumber(major), tonumber(minor), tonumber(revision)
    else
        return nil, nil, nil
    end
end

-- Helper function: compare versions
-- returns true if v2 > v1
local function isNewerVersion(v1, v2)
    -- v1 and v2 are tables {major, minor, revision}
    if v2[1] > v1[1] then return true end
    if v2[1] < v1[1] then return false end
    if v2[2] > v1[2] then return true end
    if v2[2] < v1[2] then return false end
    if v2[3] > v1[3] then return true end
    return false
end

-- Main function to check plugin version
local function checkVersion()

    -- Step 1: Get current plugin version from Info.lua
    logger.log("Reading current plugin version from Info.lua")
    local currentVersionTable = info.VERSION or {}
    local currentVersionStr = string.format("%d.%d.%d",
        currentVersionTable.major or 0,
        currentVersionTable.minor or 0,
        currentVersionTable.revision or 0)
    local currentVersion = {currentVersionTable.major or 0, currentVersionTable.minor or 0, currentVersionTable.revision or 0}

    logger.log("Current plugin version: " .. currentVersionStr)

    -- Step 2: HTTP GET latest release info from GitHub API
    local url = "https://api.github.com/repos/pbranly/Inaturalist-Identifier-Lightroom/releases/latest"
    logger.log("Fetching latest release info from GitHub API: " .. url)

    local success, response, headers = pcall(LrHttp.get, url)

    if not success or not response then
        logger.log("Failed to fetch GitHub release info: " .. tostring(response))
        return
    end

    -- Step 3: Parse JSON response
    local json = require("json")  -- JSON decoder assumed available
    local ok, releaseInfo = pcall(json.decode, response)
    if not ok or not releaseInfo or not releaseInfo.tag_name then
        logger.log("Failed to parse GitHub JSON response or missing tag_name.")
        return
    end

    local latestVersionStr = releaseInfo.tag_name
    logger.log("Latest version string from GitHub: " .. tostring(latestVersionStr))

    -- Step 4: Parse latest version string (may start with 'v', remove it)
    if latestVersionStr:sub(1,1) == "v" or latestVersionStr:sub(1,1) == "V" then
        latestVersionStr = latestVersionStr:sub(2)
    end

    local major, minor, revision = parseVersion(latestVersionStr)
    if not major then
        logger.log("Failed to parse latest version number from tag: " .. tostring(latestVersionStr))
        return
    end

    local latestVersion = {major, minor, revision}

    -- Step 5: Compare current and latest versions
    if isNewerVersion(currentVersion, latestVersion) then
        -- Step 6: Show message to user about new version availability
        logger.log(string.format("New version detected: %s (current: %s)", latestVersionStr, currentVersionStr))

        -- Internationalized message with version number
        LrDialogs.message(
            LOC("$$$/iNat/VersionCheck/Title=Update available"),
            LOC("$$$/iNat/VersionCheck/Message=New version available: ^1", latestVersionStr),
            "info"
        )
    else
        logger.log("Plugin is up to date. Current version: " .. currentVersionStr)
    end
end

-- Step 7: Run the version check asynchronously
LrTasks.startAsyncTask(function()
    checkVersion()
end)

-- Export function for external use if needed
return {
    checkVersion = checkVersion
}

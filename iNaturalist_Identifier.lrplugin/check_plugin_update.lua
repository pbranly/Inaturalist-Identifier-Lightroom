--[[
=====================================================================================
 Script       : check_plugin_update.lua
 Purpose      : Compare local plugin version with latest GitHub release version
 Author       : Philippe

 Functional Overview:
 This script reads the plugin version from Info.lua and compares
 only major, minor, and revision numbers with the latest GitHub
 release of the plugin. If a newer version is found, it logs the
 event and shows an internationalized message inviting the user
 to download the new version with a direct link to the .zip archive.

 Workflow Steps:
 1. Load the current plugin version from Info.lua.
 2. Fetch the latest release information from GitHub API.
 3. Parse the version from the latest release tag.
 4. Compare major, minor, revision numbers with local version.
 5. If the latest is newer, log and show an invitation message
    with the download link of the zip.
 6. Otherwise, log that no new version is available.

 Dependencies:
 - Lightroom SDK modules: LrHttp, LrTasks, LrDialogs
 - JSON decode module (json)
 - Info.lua available and returns VERSION table
=====================================================================================
--]]

local LrHttp = import "LrHttp"
local LrTasks = import "LrTasks"
local LrDialogs = import "LrDialogs"
local json = require("json")
local LOC = LOC
local logger = require("Logger")

-- Step 1: Load local plugin version from Info.lua
local info = import("Info")
local localVersion = info.VERSION or { major=0, minor=0, revision=0 }

-- Function to parse version string "x.y.z" into table {major, minor, revision}
local function parseVersionString(versionString)
    local major, minor, revision = versionString:match("(%d+)%.(%d+)%.(%d+)")
    return {
        major = tonumber(major) or 0,
        minor = tonumber(minor) or 0,
        revision = tonumber(revision) or 0,
    }
end

-- Function to compare versions: returns true if v2 > v1
local function isVersionNewer(v1, v2)
    if v2.major > v1.major then return true end
    if v2.major < v1.major then return false end
    if v2.minor > v1.minor then return true end
    if v2.minor < v1.minor then return false end
    if v2.revision > v1.revision then return true end
    return false
end

-- Step 2-6: Check latest GitHub release and compare
local function checkForUpdate()
    LrTasks.startAsyncTask(function()
        logger.log("Checking latest plugin version on GitHub...")

        local url = "https://api.github.com/repos/pbranly/Inaturalist-Identifier-Lightroom/releases/latest"
        local result, headers = LrHttp.get(url)

        if not result then
            logger.log("Failed to fetch latest release info from GitHub.")
            return
        end

        local success, parsed = pcall(json.decode, result)
        if not success or not parsed then
            logger.log("Failed to parse GitHub release JSON: " .. tostring(result))
            return
        end

        local tagName = parsed.tag_name or ""
        local downloadUrl = parsed.zipball_url or ""

        logger.log("Latest GitHub release tag: " .. tagName)

        local latestVersion = parseVersionString(tagName)

        if isVersionNewer(localVersion, latestVersion) then
            logger.log(string.format(
                "New version detected: local %d.%d.%d, latest %d.%d.%d",
                localVersion.major, localVersion.minor, localVersion.revision,
                latestVersion.major, latestVersion.minor, latestVersion.revision
            ))

            -- Step 5: Show message inviting user to download new version
            local messageTitle = LOC("$$$/iNat/Update/NewVersionAvailable=New plugin version available!")
            local messageBody = LOC(
                "$$$/iNat/Update/DownloadPrompt=Version %1% is available.\nDownload it here:\n%2%",
                tagName,
                downloadUrl
            )

            LrDialogs.message(messageTitle, messageBody, "info")
        else
            logger.log("No new version available. Current version is up-to-date.")
        end
    end)
end

return {
    checkForUpdate = checkForUpdate
}

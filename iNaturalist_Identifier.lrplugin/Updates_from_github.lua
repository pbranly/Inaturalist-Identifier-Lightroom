--[[============================================================================
Updates_from_github.lua
-------------------------------------------------------------------------------
Functional Description:
This module manages version checking and update logic for the iNaturalist Publish Plugin
used in Adobe Lightroom. It connects to GitHub to retrieve the latest release version,
compares it with the current plugin version, and returns both values asynchronously.

Features:
1. Retrieve current plugin version from Info.lua
2. Query GitHub API for latest release version
3. Compare current and latest versions
4. Return version info to calling script
5. Log all steps and HTTP traffic using Logger.lua
6. Display messages using internationalized LOC strings

Modules and Scripts Used:
- LrLogger         : For detailed logging
- LrPrefs          : Access plugin preferences
- LrHttp           : Perform HTTP requests
- LrTasks          : Run asynchronous tasks
- dkjson           : Decode JSON responses
- Info.lua         : Contains plugin version metadata

Scripts That Use This Module:
- PluginInfoProvider.lua : Displays version info and triggers update logic

Execution Steps:
1. Start GitHub version check asynchronously
2. Retrieve current plugin version from Info.lua
3. Build GitHub API request URL and headers
4. Send HTTP GET request to GitHub
5. Log request and response details
6. Decode JSON response from GitHub
7. Extract latest version tag
8. Return current and latest version to callback

============================================================================]]

-- Import required modules
local logger = import("LrLogger")("lr-inaturalist-publish") -- Logger instance
local prefs = import("LrPrefs").prefsForPlugin()            -- Plugin preferences
local LrHttp = import("LrHttp")                             -- HTTP module
local LrTasks = import("LrTasks")                           -- Async task runner

local Info = require("Info")                                -- Plugin version metadata
local json = require("json")                              -- JSON decoder

-- Define module table
local Updates = {
    baseUrl = "https://api.github.com/",                    -- GitHub API base URL
    repo = "pbranly/Inaturalist-Identifier-Lightroom",      -- GitHub repository
    actionPrefKey = "doNotShowUpdatePrompt",                -- Key for suppressing update dialog
}

-- Step 2: Retrieve current plugin version from Info.lua
function Updates.version()
    local v = Info.VERSION
    local formatted = string.format("%s.%s.%s", v.major, v.minor, v.revision)
    logger:trace("[Step 2] Current plugin version retrieved: " .. formatted)
    return formatted
end

-- Step 1: Start GitHub version check asynchronously
function Updates.getGitHubVersionInfoAsync(callback)
    LrTasks.startAsyncTask(function()
        logger:trace("[Step 1] Starting GitHub version check")

        -- Step 2: Get current version
        local currentVersion = "v" .. Updates.version()

        -- Step 3: Build GitHub API request
        local url = Updates.baseUrl .. "repos/" .. Updates.repo .. "/releases/latest"
        local headers = {
            { field = "User-Agent", value = Updates.repo .. "/" .. Updates.version() },
            { field = "X-GitHub-Api-Version", value = "2022-11-28" },
        }

        logger:trace("[Step 3] Sending HTTP GET to GitHub: " .. url)
        for _, h in ipairs(headers) do
            logger:trace("[Step 3] Header: " .. h.field .. ": " .. h.value)
        end

        -- Step 4: Send HTTP request
        local body, responseHeaders = LrHttp.get(url, headers)

        -- Step 5: Log response details
        logger:trace("[Step 5] GitHub response status: " .. tostring(responseHeaders.status))
        logger:trace("[Step 5] GitHub response error: " .. tostring(responseHeaders.error or "none"))
        logger:trace("[Step 5] GitHub response body: " .. tostring(body))

        -- Step 6: Handle errors
        if responseHeaders.error or responseHeaders.status ~= 200 then
            logger:error("[Step 6] GitHub API error or unexpected status code.")
            callback({ current = currentVersion, latest = "Error fetching version" })
            return
        end

        -- Step 7: Decode JSON response
        local success, release = pcall(json.decode, body)
        if not success or not release.tag_name then
            logger:error("[Step 7] Failed to decode GitHub JSON response.")
            callback({ current = currentVersion, latest = "Invalid response" })
            return
        end

        -- Step 8: Extract latest version tag
        logger:trace("[Step 8] Latest GitHub version retrieved: " .. release.tag_name)

        -- Step 9: Return version info to callback
        callback({
            current = currentVersion,
            latest = release.tag_name
        })
    end)
end

-- Return module
return Updates
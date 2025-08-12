--[[ 
=====================================================================================
 Script       : check_plugin_update.lua
 Purpose      : Compare local plugin version from Info.lua with the latest GitHub release
 Author       : Philippe (adapted by ChatGPT)

 Functional Overview:
 This script loads the local plugin version declared in Info.lua,
 fetches the latest release version from GitHub API, compares
 major, minor, and revision numbers, then shows a localized message
 to the user if a newer version is available.

 Workflow Steps:
 1. Load Info.lua as a Lua module to get the local version table.
 2. Fetch the latest GitHub release information from GitHub API.
 3. Extract and normalize version numbers from GitHub tag string.
 4. Compare local and remote versions number-by-number.
 5. Display an internationalized message if an update is available.
 6. Log all key actions and errors in English for debugging.

 Dependencies:
 - Lightroom SDK: LrHttp, LOC
 - JSON decoding library (assumed available as `json`)
=====================================================================================
--]]

-- Lightroom SDK modules
local LrHttp = import "LrHttp"
local LOC = import "LrDialogs".message -- assuming LOC is available globally in Lightroom SDK
local json = require("json")  -- or your JSON decoder

-- Logger utility for debugging (print to console)
local function log(message)
    -- You can replace this with a proper logger if available
    print("[check_plugin_update] " .. message)
end

--[[
 Step 1: Load Info.lua file as a Lua module to get local version table
 Parameters:
   path (string) - path to Info.lua file
 Returns:
   table or nil, string error message
--]]
local function loadInfoLua(path)
    log("Loading Info.lua from: " .. tostring(path))
    local chunk, err = loadfile(path)
    if not chunk then
        log("Failed to load Info.lua: " .. tostring(err))
        return nil, "Failed to load Info.lua: " .. tostring(err)
    end
    local info = chunk()
    log("Info.lua loaded successfully.")
    return info
end

--[[
 Step 4: Compare local version table and GitHub version string
 Parameters:
   localVersionTable (table) - with fields major, minor, revision
   githubVersionStr (string) - version string like "0.1.5"
 Returns:
   boolean - true if GitHub version is newer
--]]
local function isGitHubVersionNewer(localVersionTable, githubVersionStr)
    local maj, min, rev = githubVersionStr:match("(%d+)%.(%d+)%.(%d+)")
    maj = tonumber(maj)
    min = tonumber(min)
    rev = tonumber(rev)
    if not (maj and min and rev) then
        log("GitHub version string parsing failed: " .. tostring(githubVersionStr))
        return false
    end

    local lmaj = localVersionTable.major or 0
    local lmin = localVersionTable.minor or 0
    local lrev = localVersionTable.revision or 0

    log(string.format("Comparing versions: local %d.%d.%d vs GitHub %d.%d.%d", lmaj, lmin, lrev, maj, min, rev))

    if maj > lmaj then return true end
    if maj < lmaj then return false end

    if min > lmin then return true end
    if min < lmin then return false end

    if rev > lrev then return true end

    return false
end

--[[
 Step 2: Fetch latest release version from GitHub API
 Returns:
   string (version like "0.1.5") or nil if failed
--]]
local function getLatestVersionFromGitHub()
    local url = "https://api.github.com/repos/pbranly/Inaturalist-Identifier-Lightroom/releases/latest"
    log("Fetching latest GitHub release info...")
    local response, hdrs = LrHttp.get(url)
    if not response then
        log("Failed to get response from GitHub API.")
        return nil
    end
    local success, parsed = pcall(json.decode, response)
    if not success or not parsed then
        log("Failed to parse GitHub API JSON response.")
        return nil
    end
    local tag = parsed.tag_name or ""
    log("Latest GitHub version tag: " .. tostring(tag))
    return tag:gsub("^v", "") -- remove leading 'v' if present
end

--[[
 Step 5 & 6: Main check function
 Parameters:
   pathToInfoLua (string) - path to Info.lua
 Displays localized message if a new version is available.
--]]
local function checkForPluginUpdate(pathToInfoLua)
    local info, err = loadInfoLua(pathToInfoLua)
    if not info then
        log("Error loading Info.lua: " .. tostring(err))
        return
    end

    local localVersion = info.VERSION
    if not localVersion then
        log("Local version info missing in Info.lua")
        return
    end

    local latestVersion = getLatestVersionFromGitHub()
    if not latestVersion then
        log("Could not retrieve latest version from GitHub")
        return
    end

    if isGitHubVersionNewer(localVersion, latestVersion) then
        -- Localized message to user
        local title = LOC("$$$/iNat/Update/Title=Plugin Update")
        local message = LOC("$$$/iNat/Update/NewVersionAvailable=New version available")
        LrDialogs.message(title, message)
        log("New version available: " .. latestVersion)
    else
        log("Plugin is up to date.")
    end
end

-- Replace with actual path to your Info.lua file
local pathToInfoLua = "/path/to/your/plugin/Info.lua"
checkForPluginUpdate(pathToInfoLua)

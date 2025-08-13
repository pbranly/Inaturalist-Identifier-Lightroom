--[[
============================================================
Get_Current_Version.lua

This module provides the current version of the iNaturalist
Lightroom plugin in a readable string format (major.minor.revision).

It reads the version from PluginVersion.lua and formats it.
============================================================
]]

-- Import the PluginVersion table
local pluginVersion = require("PluginVersion")

-- Function to return the current version as a string
local function getCurrentVersion()
    -- Format as "major.minor.revision"
    local versionString = string.format("%d.%d.%d",
        pluginVersion.major or 0,
        pluginVersion.minor or 0,
        pluginVersion.revision or 0
    )
    return versionString
end

-- Return the function so it can be called externally
return {
    getCurrentVersion = getCurrentVersion
}

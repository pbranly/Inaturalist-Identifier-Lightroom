-- Get_Current_Version.lua
local PluginVersion = require("PluginVersion")

local currentVersion = string.format(
    "%d.%d.%d",
    tonumber(PluginVersion.major) or 0,
    tonumber(PluginVersion.minor) or 0,
    tonumber(PluginVersion.revision) or 0
)

return {
    getCurrentVersion = function() return currentVersion end,
    versionString = currentVersion
}

--[[
PluginVersion.lua

This module defines the current version of the iNaturalist Lightroom plugin.
It is used for version comparison against the latest GitHub release.

📋 Structure:
- major:    Major version number (breaking changes)
- minor:    Minor version number (new features)
- revision: Bug fixes or small improvements
- build:    Internal build number (optional)

This file is read by:
- Get_Version_GitHub.lua → for comparison and display
- PluginInfoProvider.lua → for UI display
]]

return {
    major = 0,
    minor = 1,
    revision = 8,
    build = 0
}

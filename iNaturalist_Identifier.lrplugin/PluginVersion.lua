--[[
    PluginVersion.lua
    -----------------
    Purpose:
        This module stores and manages the plugin's version information 
        in a structured way. It is used to keep track of changes, 
        ensure compatibility, and display version details in the UI or logs.

    Structure:
        - major     : Major version number — incremented for significant feature changes or incompatible updates.
        - minor     : Minor version number — incremented for smaller features or enhancements that remain backward-compatible.
        - revision  : Revision number — incremented for bug fixes, patches, or small adjustments.
        - build     : Optional build number — can be used for internal tracking, CI builds, or deployment identifiers.

    Functions:
        - asString(v):
            Converts the version table into a human-readable string format.
            Example:
                Input:  { major = 1, minor = 4, revision = 7 }
                Output: "1.4.7"
            This makes it easy to log or display the version in dialogs, 
            metadata, or exported files.

    Usage:
        local version = require("PluginVersion")
        print(version.asString(version))   -- Outputs something like: 0.1.2
        logger.logMessage("Plugin version: " .. version.asString(version))

    Notes:
        - The 'build' field is not currently used in the asString() output, 
          but it can be included if a more precise versioning scheme is needed.
        - Keeping version numbers centralized here makes maintenance and 
          consistency easier across the entire plugin codebase.
]]
return {
    major = 0,
    minor = 1,
    revision = 2,
    build = 0,

    asString = function(v)
        return string.format("%d.%d.%d", v.major, v.minor, v.revision)
    end
}

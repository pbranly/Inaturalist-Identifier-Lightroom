--[[
=====================================================================================
 File        : Info.lua
 Purpose     : Main plugin descriptor for the iNaturalist Lightroom Export Plugin

 Description :
 -------------
 This file defines the plugin metadata and integration points with the Adobe Lightroom SDK.
 It registers the plugin with Lightroom as an *Export Plugin*, adds a custom menu item 
 under "File > Export", and links the core logic to the script `AnimalIdentifier.lua`.

 Functional Overview:
 --------------------
 - Displays a localized plugin name ("Identification iNaturalist") in the Lightroom UI.
 - Declares the plugin type as "export", which allows it to export photos and metadata.
 - Binds the main functionality to a menu item that triggers `AnimalIdentifier.lua`.
 - Specifies SDK version compatibility to ensure proper operation.
 - Registers a plugin info panel (via `PluginInfoProvider.lua`) for settings or user guidance.
 - Declares a unique identifier (`LrToolkitIdentifier`) for Lightroom to manage plugin state.

 Compatibility:
 --------------
 ✅ Lightroom Classic 10.0 and above  
 ❌ Not compatible with Lightroom CC or Mobile  

 Author:
 -------
 Philippe (or your name)
=====================================================================================
--]]

return {
    -- Display name in Lightroom (localized)
    LrPluginName = LOC("$$$/iNat/PluginName=Identification iNaturalist"),

    -- Unique identifier for the plugin
    LrToolkitIdentifier = "com.example.iNaturalistBirdIdentifier",

    -- Supported Lightroom SDK versions
    LrSdkVersion = 14.0,
    LrSdkMinimumVersion = 10.0,

    -- Link to plugin information website
    LrPluginInfoUrl = "https://www.inaturalist.org",

    -- Script launched from the "File > Export" menu
    LrExportMenuItems = {
        {
            title = LOC("$$$/iNat/MenuItem=Identify wildlife via iNaturalist"),
            file = "AnimalIdentifier.lua",  -- Updated: now launching AnimalIdentifier.lua
        },
    },

    -- Interface for the Plugin Manager (shown in Lightroom’s Plugin Manager panel)
    LrPluginInfoProvider = "PluginInfoProvider.lua",

    -- Declare the plugin type (must be "export" for export-style plugins)
    LrPluginType = "export",

    -- Versioning information (displayed in Plugin Manager or for diagnostics)
    VERSION = {
        major = 0,
        minor = 0,
        revision = 1,
        build = 3,
    },
}

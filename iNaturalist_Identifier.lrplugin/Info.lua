--[[
=====================================================================================
 Script       : Info.lua (Plugin Manifest)
 Purpose      : Define metadata and configuration for the iNaturalist Lightroom plugin
 Author       : Philippe

 Functional Overview:
 This manifest file provides Lightroom with essential information about the plugin,
 including its name, version, capabilities, and entry points. It enables Lightroom
 to register the plugin correctly and expose its functionality through the UI.

 Key Features:
 - Declares the plugin as an "export" type, allowing it to be triggered from the
   "File > Export" menu.
 - Specifies the main script (`AnimalIdentifier.lua`) that initiates the species identification
   workflow using the iNaturalist API.
 - Provides localized display names and menu labels via the `LOC()` function.
 - Includes a link to the iNaturalist website for user reference.
 - Registers a custom Plugin Manager interface via `PluginInfoProvider.lua`.
 - Defines SDK compatibility and plugin versioning for maintenance and updates.

 Usage Notes:
 - This file must reside at the root of the plugin folder.
 - Lightroom reads this file during plugin installation and startup.
 - All referenced scripts (e.g., `main.lua`, `PluginInfoProvider.lua`) must exist
   and be correctly implemented for the plugin to function.
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
            file = "AnimalIdentifier.lua",
        },
    },

    -- Interface for the Plugin Manager
    LrPluginInfoProvider = "PluginInfoProvider.lua",

    -- Plugin type
    LrPluginType = "export",

    -- Plugin version number
    VERSION = {
        major = 0,
        minor = 0,
        revision = 1,
        build = 2,
    },
}
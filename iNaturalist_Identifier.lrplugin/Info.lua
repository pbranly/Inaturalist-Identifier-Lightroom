--[[
=====================================================================================
 File        : Info.lua
 Purpose     : Main plugin descriptor for the iNaturalist Lightroom Export Plugin

 Description:
 ------------
 This file provides the metadata and integration points required by the Adobe Lightroom SDK.
 It tells Lightroom:
   • What the plugin is called (localized name).
   • What type of plugin it is (export plugin).
   • Where to find its main functionality.
   • Which SDK versions it supports.
   • How to open its settings panel in the Plugin Manager.
   • Which menu entries to add in the Lightroom UI.

 Functional Overview:
 --------------------
 - Displays a localized plugin name ("Identification iNaturalist") in Lightroom’s interface.
 - Declares the plugin type as "export", enabling it to handle export actions.
 - Adds a custom export menu item that runs the `AnimalIdentifier.lua` script.
 - Declares compatibility with Lightroom SDK 10.0 and later.
 - Provides a plugin info provider script (`PluginInfoProvider.lua`) for custom settings.
 - Links to a plugin info web page or GitHub releases page.
 - Uses a unique toolkit identifier so Lightroom can track and manage the plugin.

 Compatibility:
 --------------
 ✅ Compatible: Lightroom Classic 10.0 and above  
 ❌ Not compatible: Lightroom CC (Cloud-based) or Lightroom Mobile

 Author:
 -------
 Philippe
=====================================================================================
--]]

-- Import version information from a dedicated module
local PluginVersion = require("PluginVersion")

-- Main plugin descriptor table returned to Lightroom
return {
    -- Localized name displayed in Lightroom's Plugin Manager
    LrPluginName = LOC("$$$/iNat/PluginName=Identification iNaturalist"),

    -- Unique internal identifier for Lightroom to track the plugin
    LrToolkitIdentifier = "com.example.iNaturalistBirdIdentifier",

    -- Supported Lightroom SDK versions
    LrSdkVersion = 14.0,        -- Current tested version
    LrSdkMinimumVersion = 10.0, -- Minimum required version

    -- Web link for plugin information or latest release
    LrPluginInfoUrl = "https://github.com/pbranly/Inaturalist-Identifier-Lightroom/releases/latest", -- Can be updated if needed

    -- Define export menu items (shown under File > Export)
    LrExportMenuItems = {
        {
            title = LOC("$$$/iNat/MenuItem=Identify wildlife via iNaturalist"),
            file = "AnimalIdentifier.lua", -- Script triggered when menu item is selected
        },
    },

    -- Plugin Manager integration (custom settings and information panel)
    LrPluginInfoProvider = "PluginInfoProvider.lua",

    -- Declare plugin type as "export"
    LrPluginType = "export",

    -- Plugin version information (used in Plugin Manager and logs)
    VERSION = PluginVersion,
}

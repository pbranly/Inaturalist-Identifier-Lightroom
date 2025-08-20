--[[
============================================================
Functional Description
------------------------------------------------------------
This `Info.lua` script defines the metadata and main configuration
for a Lightroom plugin that identifies wildlife using the 
iNaturalist platform.

This is a Lightroom SDK-specific Lua configuration file that:
1. Declares the plugin name, unique identifier, and supported 
   Lightroom SDK versions.
2. Provides a URL for plugin information.
3. Defines menu items in Lightroom and specifies the main script
   to run when selected.
4. Specifies additional scripts such as the plugin information
   provider for the Plugin Manager.
5. Declares the plugin type and version.

------------------------------------------------------------
Numbered Steps
1. Declare the plugin name displayed in Lightroom.
2. Define the plugin's unique Toolkit Identifier.
3. Specify the supported Lightroom SDK versions.
4. Provide the plugin information URL.
5. Declare the menu item under "File > Export" and link it to 
   the main script.
6. Specify the information provider script for the Plugin Manager.
7. Define the plugin type.
8. Set the plugin version.

------------------------------------------------------------
Called scripts
- main.lua (main script launched via the Export menu)
- PluginInfoProvider.lua (script for displaying plugin information
  in Lightroom's Plugin Manager)

------------------------------------------------------------
Calling script
- Lightroom (host application) via its internal SDK plugin 
  loading engine.
============================================================
]]

return {
    -- [Step 1] Display name in Lightroom (localized)
    LrPluginName = LOC("$$$/iNat/PluginName=iNaturalist Identification"),

    -- [Step 2] Unique identifier for the plugin
    LrToolkitIdentifier = "com.example.iNaturalistBirdIdentifier",

    -- [Step 3] Supported Lightroom SDK versions
    LrSdkVersion = 14.0,
    LrSdkMinimumVersion = 10.0,

    -- [Step 4] Link to plugin information website
    LrPluginInfoUrl = "https://www.inaturalist.org",

    -- [Step 5] Script launched from the "File > Export" menu
    LrExportMenuItems = {
        {
            title = LOC("$$$/iNat/MenuItem=Identify wildlife via iNaturalist"),
            file = "main.lua",
        },
    },

	 
    -- [Step 6] Interface for the Plugin Manager
    LrPluginInfoProvider = "PluginInfoProvider.lua",

    -- [Step 7] Plugin type
    LrPluginType = "export",

    -- [Step 8] Plugin version number
    VERSION = {
        major = 1,
        minor = 1,
        revision = 11,
        build = 0,
    },
}

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
            file = "main.lua",
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

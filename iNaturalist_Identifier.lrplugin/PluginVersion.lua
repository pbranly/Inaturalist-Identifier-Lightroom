-- PluginVersion.lua
return {
    major = 0,
    minor = 0,
    revision = 1,
    build = 3,

    asString = function(v)
        return string.format("%d.%d.%d", v.major, v.minor, v.revision)
    end
}

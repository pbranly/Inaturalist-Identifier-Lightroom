-- PluginVersion.lua
return {
    major = 0,
    minor = 1,
    revision = 2,
    build = 0,

    asString = function(v)
        return string.format("%d.%d.%d", v.major, v.minor, v.revision)
    end
}

local M = {}

function M.getLatestTag()
    local handle = io.popen("curl -s https://api.github.com/repos/pbranly/Inaturalist-Identifier-Lightroom/releases/latest")
    local result = handle:read("*a")
    handle:close()

    local tag = result:match('"tag_name"%s*:%s*"([^"]+)"')
    local url = result:match('"html_url"%s*:%s*"([^"]+)"')

    if tag and url then
        return tag, url
    else
        return nil, nil
    end
end

return M
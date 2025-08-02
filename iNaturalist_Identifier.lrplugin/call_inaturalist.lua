local LrHttp = import("LrHttp")
local LrFileUtils = import("LrFileUtils")
local LrPathUtils = import("LrPathUtils")
local LOC = import("LrLocalization").locale
local json = require("json") -- Make sure json.lua is included in your plugin

local M = {}

function M.identify(imagePath, token)
    local boundary = "----LightroomFormBoundary123456"

    -- Read the image file
    local imageData = LrFileUtils.readFile(imagePath)
    if not imageData then
        return nil, LOC("$$$/iNat/Error/ImageRead=Unable to read image: ") .. imagePath
    end

    -- Build the multipart/form-data request manually
    local body = table.concat({
        "--" .. boundary,
        'Content-Disposition: form-data; name="image"; filename="tempo.jpg"',
        "Content-Type: image/jpeg",
        "",
        imageData,
        "--" .. boundary .. "--",
        ""
    }, "\r\n")

    -- Prepare HTTP headers
    local headers = {
        { field = "Authorization", value = "Bearer " .. token },
        { field = "User-Agent", value = "LightroomBirdIdentifier/1.0" },
        { field = "Content-Type", value = "multipart/form-data; boundary=" .. boundary },
        { field = "Accept", value = "application/json" }
    }

    -- Send the POST request to the iNaturalist API
    local result, hdrs = LrHttp.post("https://api.inaturalist.org/v1/computervision/score_image", body, headers)

    if not result then
        return nil, LOC("$$$/iNat/Error/NoAPIResponse=API error: No response")
    end

    -- Try to decode the JSON response
    local success, parsed = pcall(json.decode, result)
    if not success or not parsed then
        return nil, LOC("$$$/iNat/Error/InvalidJSON=API error: Failed to decode JSON response: ") .. tostring(result)
    end

    local results = parsed.results or {}
    if #results == 0 then
        return LOC("$$$/iNat/Result/None=🕊️ No animal recognized.")
    end

    -- Normalize scores for display
    local max_score = 0
    for _, r in ipairs(results) do
        local s = tonumber(r.combined_score) or 0
        if s > max_score then max_score = s end
    end
    if max_score == 0 then max_score = 1 end

    -- Build result output
    local output = { LOC("$$$/iNat/Result/Header=🕊️ Recognized specie:\n") }
    for _, result in ipairs(results) do
        local taxon = result.taxon or {}
        local name_fr = taxon.preferred_common_name or LOC("$$$/iNat/Result/UnknownName=Unknown")
        local name_latin = taxon.name or LOC("$$$/iNat/Result/UnknownName=Unknown")
        local raw_score = tonumber(result.combined_score) or 0
        local normalized = math.floor((raw_score / max_score) * 1000 + 0.5) / 10
        table.insert(output, string.format("- %s (%s) : %.1f%%", name_fr, name_latin, normalized))
    end

    return table.concat(output, "\n")
end

return M

-- Step 1: Read JPEG image content from disk
local imageData = LrFileUtils.readFile(imagePath)
if not imageData then
    return nil, LOC("$$$/iNat/Error/ImageRead=Unable to read image: ") .. imagePath
end

-- Step 2: Construct multipart/form-data HTTP body with the image
local body = table.concat({
    "--" .. boundary,
    'Content-Disposition: form-data; name="image"; filename="tempo.jpg"',
    "Content-Type: image/jpeg",
    "",
    imageData,
    "--" .. boundary .. "--",
    ""
}, "\r\n")

-- Step 3: Build HTTP headers for the request
local headers = {
    { field = "Authorization", value = "Bearer " .. token },
    { field = "User-Agent", value = "LightroomBirdIdentifier/1.0" },
    { field = "Content-Type", value = "multipart/form-data; boundary=" .. boundary },
    { field = "Accept", value = "application/json" }
}

-- Step 4: Send POST request to iNaturalist's AI scoring endpoint
local result, hdrs = LrHttp.post("https://api.inaturalist.org/v1/computervision/score_image", body, headers)

-- Step 5: Handle HTTP/network error
if not result then
    return nil, LOC("$$$/iNat/Error/NoAPIResponse=API error: No response")
end

-- Step 6: Decode JSON response from the API
local success, parsed = pcall(json.decode, result)
if not success or not parsed then
    return nil, LOC("$$$/iNat/Error/InvalidJSON=API error: Failed to decode JSON response: ") .. tostring(result)
end

-- Step 7: Extract species results from the parsed response
local results = parsed.results or {}
if #results == 0 then
    return LOC("$$$/iNat/Result/None=🕊️ No specie recognized.")
end

-- Step 8: Normalize confidence scores relative to the highest score
local max_score = 0
for _, r in ipairs(results) do
    local s = tonumber(r.combined_score) or 0
    if s > max_score then max_score = s end
end
if max_score == 0 then max_score = 1  -- Prevent division by zero

-- Step 9: Format output string with species names and normalized confidence percentages
local output = { LOC("$$$/iNat/Result/Header=🕊️ Recognized species:") }
table.insert(output, "")  -- Add spacing line

for _, result in ipairs(results) do
    local taxon = result.taxon or {}
    local name_fr = taxon.preferred_common_name or LOC("$$$/iNat/Result/UnknownName=Unknown")
    local name_latin = taxon.name or LOC("$$$/iNat/Result/UnknownName=Unknown")
    local raw_score = tonumber(result.combined_score) or 0
    local normalized = math.floor((raw_score / max_score) * 1000 + 0.5) / 10  -- Round to 1 decimal
    table.insert(output, string.format("- %s (%s) : %.1f%%", name_fr, name_latin, normalized))
end

-- Step 10: Return the formatted result string
return table.concat(output, "\n")
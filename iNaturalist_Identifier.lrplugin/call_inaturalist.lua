--[[
=====================================================================================
 Script       : call_inaturalist.lua
 Purpose      : Identify animal species from a JPEG image using iNaturalist's AI API
 Author       : Philippe

 Functional Overview:
 This script sends a JPEG image to iNaturalist's computer vision API and returns
 a formatted list of species predictions with confidence scores. It handles image
 reading, HTTP request construction, response parsing, and result formatting.

 Workflow Steps:
 1. Reads the JPEG image from disk using Lightroom's file utilities.
 2. Constructs a multipart/form-data HTTP body containing the image.
 3. Builds appropriate HTTP headers including authorization and content type.
 4. Sends a POST request to iNaturalist's AI scoring endpoint.
 5. Handles network or API errors gracefully.
 6. Parses the JSON response returned by the API.
 7. Extracts species prediction results from the parsed response.
 8. Normalizes confidence scores relative to the highest score.
 9. Formats the species names and confidence percentages into a readable string.
10. Returns the final formatted result string for display or logging.

 Key Features:
 - Uses Lightroom SDK modules: LrFileUtils, LrHttp
 - Supports localization via LOC() strings
 - Normalizes scores to provide relative confidence percentages
 - Handles missing data and API errors with user-friendly messages

 Dependencies:
 - Lightroom SDK: LrFileUtils, LrHttp
 - JSON decoding library (assumed available as `json`)
 - Token must be a valid iNaturalist API token (Bearer format)

 Notes:
 - The image must be in JPEG format and accessible via `imagePath`
 - The token should be retrieved and validated before calling this script
=====================================================================================
--]]

-- Simple logger (à adapter si besoin)
local logger = {}
function logger.log(msg)
    -- Par exemple print ou écriture fichier :
    -- print("[call_inaturalist] " .. msg)
end

-- Step 1: Read JPEG image content from disk
logger.log("Reading image from path: " .. tostring(imagePath))
local imageData = LrFileUtils.readFile(imagePath)
if not imageData then
    logger.log("Failed to read image: " .. tostring(imagePath))
    return nil, LOC("$$$/iNat/Error/ImageRead=Unable to read image: ") .. imagePath
end

-- Step 2: Construct multipart/form-data HTTP body with the image
logger.log("Constructing multipart/form-data body for image upload.")
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
logger.log("HTTP headers prepared with Authorization and Content-Type.")

-- Step 4: Send POST request to iNaturalist's AI scoring endpoint
logger.log("Sending POST request to iNaturalist API endpoint.")
local result, hdrs = LrHttp.post("https://api.inaturalist.org/v1/computervision/score_image", body, headers)

-- Step 5: Handle HTTP/network error
if not result then
    logger.log("API call failed: no response received.")
    return nil, LOC("$$$/iNat/Error/NoAPIResponse=API error: No response")
end

-- Step 6: Decode JSON response from the API
logger.log("Decoding JSON response from API.")
local success, parsed = pcall(json.decode, result)
if not success or not parsed then
    logger.log("Failed to decode JSON response: " .. tostring(result))
    return nil, LOC("$$$/iNat/Error/InvalidJSON=API error: Failed to decode JSON response: ") .. tostring(result)
end

-- Step 7: Extract species results from the parsed response
local results = parsed.results or {}
if #results == 0 then
    logger.log("No species recognized in API response.")
    return LOC("$$$/iNat/Result/None=🕊️ No specie recognized.")
end

-- Step 8: Normalize confidence scores relative to the highest score
logger.log("Normalizing confidence scores for recognized species.")
local max_score = 0
for _, r in ipairs(results) do
    local s = tonumber(r.combined_score) or 0
    if s > max_score then max_score = s end
end
if max_score == 0 then max_score = 1  -- Prevent division by zero
    logger.log("Max score was zero, adjusted to 1 to avoid division by zero.")
end

-- Step 9: Format output string with species names and normalized confidence percentages
logger.log("Formatting results for output.")
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
logger.log("Returning formatted species recognition results.")
return table.concat(output, "\n")

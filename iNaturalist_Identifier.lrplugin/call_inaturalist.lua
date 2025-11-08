--[[
=====================================================================================
 Script       : call_inaturalist.lua
 Author       : Philippe
 Purpose      : Identify species from a JPEG image using iNaturalist's AI API
=====================================================================================
Functional Description (English)
------------------------------------------------------------
This module `call_inaturalist.lua` is responsible for performing species identification
from a JPEG image exported from Lightroom by sending it to iNaturalist's AI scoring API.
It performs the following main functions:

1. Reads the JPEG image from disk.
2. Constructs a multipart/form-data HTTP body containing the image.
3. Prepares HTTP headers with authorization token and content type.
4. Sends a POST request to iNaturalist's computer vision API.
5. Handles API errors or network issues.
6. Parses the JSON response returned by the API.
7. Extracts species predictions from the response.
8. Formats species names and confidence scores into a Lightroom-friendly string.
9. Returns the formatted result string for display or logging.

Modules and Scripts Used:
- LrFileUtils (Lightroom SDK)
- LrHttp (Lightroom SDK)
- LrTasks (Lightroom SDK)
- json (JSON decoding)
- logger.lua (custom logging module)

Calling Scripts:
- selectAndTagResults.lua
- AnimalIdentifier.lua

Numbered Steps with English Description:
1. Read image from disk and verify file contents.
2. Construct multipart/form-data body with a unique boundary.
3. Build HTTP headers including Authorization Bearer token.
4. Send POST request to iNaturalist API and receive response.
5. Handle errors if the API call fails or returns no data.
6. Decode JSON response and validate parsing.
7. Extract recognized species from JSON results.
8. Format species names and raw confidence scores into a readable string.
9. Return the final formatted string via callback for display or logging.
=====================================================================================
]]

local LrFileUtils = import("LrFileUtils")
local LrHttp = import("LrHttp")
local LrTasks = import("LrTasks")
local json = require("json")
local logger = require("Logger")

-- Normalize accented characters to basic ASCII for Lightroom compatibility
local function normalizeAccents(str)
	str = str:gsub("à", "a")
		:gsub("â", "a")
		:gsub("é", "e")
		:gsub("è", "e")
		:gsub("ê", "e")
		:gsub("ô", "o")
		:gsub("ù", "u")
		:gsub("û", "u")
		:gsub("ç", "c")
		:gsub("ï", "i")
		:gsub("ë", "e")
	return str
end

-- Main asynchronous identification function
local function identifyAsync(imagePath, token, callback)
	LrTasks.startAsyncTask(function()
		-- Step 1: Read image
		logger.logMessage("[Step 1] Reading image: " .. tostring(imagePath))
		local imageData = LrFileUtils.readFile(imagePath)
		if not imageData then
			logger.logMessage("[Step 1] Failed to read image: " .. tostring(imagePath))
			callback(nil, "Unable to read image: " .. imagePath)
			return
		end
		logger.logMessage("[Step 1] Image read successfully (" .. #imageData .. " bytes)")

		-- Step 2: Construct multipart/form-data
		local boundary = "----LightroomBoundary" .. tostring(math.random(1000000))
		local body = table.concat({
			"--" .. boundary,
			'Content-Disposition: form-data; name="image"; filename="tempo.jpg"',
			"Content-Type: image/jpeg",
			"",
			imageData,
			"--" .. boundary .. "--",
			"",
		}, "\r\n")
		logger.logMessage("[Step 2] Multipart/form-data body constructed, boundary: " .. boundary)

		-- Step 3: HTTP headers
		local headers = {
			{ field = "Authorization", value = "Bearer " .. token },
			{ field = "User-Agent", value = "LightroomBirdIdentifier/1.0" },
			{ field = "Content-Type", value = "multipart/form-data; boundary=" .. boundary },
			{ field = "Accept", value = "application/json" },
		}
		logger.logMessage("[Step 3] HTTP headers prepared.")

		-- Step 4: POST to iNaturalist API
		logger.logMessage("[Step 4] Sending POST request to iNaturalist API.")
		local result, _ = LrHttp.post("https://api.inaturalist.org/v1/computervision/score_image", body, headers)
		if not result then
			logger.logMessage("[Step 5] API call failed: no response.")
			callback(nil, "API error: No response")
			return
		end
		logger.logMessage("[Step 5] API response received (" .. tostring(#result) .. " bytes)")

		-- Step 6: Decode JSON
		local success, parsed = pcall(json.decode, result)
		if not success or not parsed then
			logger.logMessage("[Step 6] Failed to decode JSON: " .. tostring(result))
			callback(nil, "API error: Invalid JSON")
			return
		end
		logger.logMessage("[Step 6] JSON decoded successfully.")

		-- Step 7: Extract species predictions
		local results = parsed.results or {}
		if #results == 0 then
			logger.logMessage("[Step 7] No species recognized.")
			callback("🕊️ No species recognized.")
			return
		end
		logger.logMessage("[Step 7] Number of predictions received: " .. #results)

		-- Step 8: Format results with raw scores (Lightroom-compatible)
		local output = { "🕊️ Recognized species:" }
		table.insert(output, "")
		for _, r in ipairs(results) do
			local taxon = r.taxon or {}
			local name_fr = normalizeAccents(taxon.preferred_common_name or "Unknown")
			local name_latin = taxon.name or "Unknown"
			local raw_score = tonumber(r.combined_score) or 0
			local line = string.format("- %s (%s) : %.3f", name_fr, name_latin, raw_score)
			table.insert(output, line)
			logger.logMessage("[Step 8] Recognized: " .. line)
		end

		-- Step 9: Return final formatted results
		logger.logMessage("[Step 9] Returning final formatted species recognition results.")
		callback(table.concat(output, "\n"))
	end)
end

-- Export module
return {
	identifyAsync = identifyAsync,
}

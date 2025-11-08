--[[============================================================
TokenUpdater.lua
------------------------------------------------------------
Gère le token iNaturalist pour le plugin Lightroom.
============================================================]]

-- Step 1: Lightroom SDK imports
local LrPrefs = import("LrPrefs")
local LrDialogs = import("LrDialogs")
local LrView = import("LrView")
local LrTasks = import("LrTasks")

local logger = require("Logger")

-- Detect platform in a Lightroom-safe way using _PLUGIN.path
local WIN_ENV = false
local MAC_ENV = false
do
	local pluginPath = (_PLUGIN and _PLUGIN.path) or ""
	if pluginPath ~= "" then
		-- If path contains backslash, assume Windows
		if pluginPath:find("\\") then
			WIN_ENV = true
		-- If path starts with '/', assume macOS / Unix-like
		elseif pluginPath:sub(1, 1) == "/" then
			MAC_ENV = true
		end
	end
end

-- Step 2: Function to check if token is fresh (<24h old)
local function isTokenFresh()
	local prefs = LrPrefs.prefsForPlugin()
	if not prefs.token or prefs.token == "" then
		return false
	end
	local timestamp = prefs.tokenTimestamp or 0
	local age = os.time() - timestamp
	logger.logMessage("[TokenUpdater] Token age in seconds: " .. tostring(age))
	return age <= 24 * 3600
end

-- Step 3: Function to get token status text for UI display
local function getTokenStatusText()
	local prefs = LrPrefs.prefsForPlugin()
	if not prefs.token or prefs.token == "" then
		return LOC("$$$/iNat/TokenStatus/None=No token available.")
	end
	if isTokenFresh() then
		return LOC("$$$/iNat/TokenStatus/Valid=Token is fresh and valid (less than 24h old).")
	else
		return LOC("$$$/iNat/TokenStatus/Expired=Token expired. Please refresh.")
	end
end

-- Step 4: Function to run token update UI
local function runUpdateTokenScript()
	LrTasks.startAsyncTask(function()
		local prefs = LrPrefs.prefsForPlugin()
		local f = LrView.osFactory()
		local props = { token = prefs.token or "" }

		-- Function to open token generation page
		local function openTokenPage()
			local url = "https://www.inaturalist.org/users/api_token"
			local openCommand
			if WIN_ENV then
				openCommand = 'start "" "' .. url .. '"'
			elseif MAC_ENV then
				openCommand = 'open "' .. url .. '"'
			else
				openCommand = 'xdg-open "' .. url .. '"'
			end
			logger.logMessage("[TokenUpdater] Opening token page with command: " .. openCommand)
			-- Exécute la commande d'ouverture
			LrTasks.execute(openCommand)
		end

		-- Modal UI
		local contents = f:column({
			bind_to_object = props,
			spacing = f:control_spacing(),

			f:static_text({
				title = LOC(
					"$$$/iNat/TokenDialog/Instruction=Please paste your iNaturalist token (valid for 24 hours):"
				),
				width = 400,
			}),

			f:edit_field({
				value = LrView.bind("token"),
				width_in_chars = 80,
			}),

			f:push_button({
				title = LOC("$$$/iNat/TokenDialog/OpenPage=Open token generation page"),
				action = openTokenPage,
			}),

			f:push_button({
				title = LOC("$$$/iNat/TokenDialog/Save=Save token"),
				action = function()
					prefs.token = props.token
					prefs.tokenTimestamp = os.time()
					logger.logMessage(
						"[TokenUpdater] Token saved. Timestamp updated to " .. tostring(prefs.tokenTimestamp)
					)
					LrDialogs.message(LOC("$$$/iNat/TokenDialog/Saved=Token successfully saved."))
				end,
			}),
		})

		LrDialogs.presentModalDialog({
			title = LOC("$$$/iNat/TokenDialog/Title=iNaturalist Token Setup"),
			contents = contents,
		})
	end)
end

-- Step 6: Export functions
return {
	runUpdateTokenScript = runUpdateTokenScript,
	isTokenFresh = isTokenFresh,
	getTokenStatusText = getTokenStatusText,
}

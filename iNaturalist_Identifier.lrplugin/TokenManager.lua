--[[
=====================================================================================
 Script       : TokenManager.lua
 Purpose      : Manage iNaturalist API token within Lightroom plugin (UI + Validation)
 Author       : Philippe

 Functional Overview:
 ---------------------
 - Provides a Lightroom-native UI to enter and save the token.
 - Opens iNaturalist token generation page in default browser.
 - Stores token persistently via Lightroom preferences.
 - Validates token format and expiration (JWT standard).
 - Can be called from anywhere in the plugin to prompt user if needed.

 Key Features:
 -------------
 - Modal dialog for token input and saving
 - Cross-platform URL opening
 - Decodes JWT token payload to check "exp" timestamp
 - Asynchronous execution for smooth UX
 - Graceful error handling
 - Self-contained: replaces old `update_token.lua` and `VerificationToken.lua`

 Dependencies:
 -------------
 - Lightroom SDK: LrPrefs, LrDialogs, LrView, LrTasks
 - Platform detection: WIN_ENV, MAC_ENV
 - Localization via LOC()
=====================================================================================
--]]

-- Lightroom SDK modules
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrView    = import "LrView"
local LrTasks   = import "LrTasks"

-- UI factory and plugin preferences
local f     = LrView.osFactory()
local prefs = LrPrefs.prefsForPlugin()

-- Property table for UI binding
local props = {
    token = prefs.token or ""
}

--------------------------------------------------------------------------------
-- Function: openTokenPage
-- Purpose : Opens iNaturalist token generation page in default browser
--------------------------------------------------------------------------------
local function openTokenPage()
    local url = "https://www.inaturalist.org/users/api_token"
    LrTasks.startAsyncTask(function()
        local openCommand
        if WIN_ENV then
            openCommand = 'start "" "' .. url .. '"'
        elseif MAC_ENV then
            openCommand = 'open "' .. url .. '"'
        else
            openCommand = 'xdg-open "' .. url .. '"'
        end
        LrTasks.execute(openCommand)
    end)
end

--------------------------------------------------------------------------------
-- Function: decodeBase64Url
-- Purpose : Decodes base64url-encoded string (used in JWT tokens)
--------------------------------------------------------------------------------
local function decodeBase64Url(input)
    -- Replace URL-safe chars
    input = input:gsub('-', '+'):gsub('_', '/')
    -- Add padding if needed
    local pad = #input % 4
    if pad > 0 then
        input = input .. string.rep('=', 4 - pad)
    end
    -- Decode
    return LrTasks.decodeBase64(input)
end

--------------------------------------------------------------------------------
-- Function: isTokenValid
-- Purpose : Checks token presence, format, and expiration date (JWT exp claim)
--------------------------------------------------------------------------------
local function isTokenValid(token)
    if not token or token == "" then
        return false, LOC("$$$/iNat/Error/TokenMissing=Token is missing.")
    end

    -- JWT tokens have 3 parts separated by "."
    local header, payload = token:match("([^%.]+)%.([^%.]+)%.")
    if not payload then
        return false, LOC("$$$/iNat/Error/TokenFormat=Invalid token format.")
    end

    -- Decode payload JSON
    local payloadJson = decodeBase64Url(payload)
    if not payloadJson then
        return false, LOC("$$$/iNat/Error/TokenDecode=Unable to decode token payload.")
    end

    -- Extract "exp" field (Unix timestamp)
    local exp = payloadJson:match('"exp"%s*:%s*(%d+)')
    if not exp then
        return false, LOC("$$$/iNat/Error/TokenNoExp=Token expiration field missing.")
    end

    exp = tonumber(exp)
    if not exp then
        return false, LOC("$$$/iNat/Error/TokenExpInvalid=Invalid expiration format.")
    end

    -- Compare with current time
    local now = os.time()
    if now >= exp then
        return false, LOC("$$$/iNat/Error/TokenExpired=Token has expired.")
    end

    return true
end

--------------------------------------------------------------------------------
-- Function: showTokenDialog
-- Purpose : Shows modal dialog for token entry
--------------------------------------------------------------------------------
local function showTokenDialog()
    local contents = f:column {
        bind_to_object = props,
        spacing = f:control_spacing(),

        f:static_text {
            title = LOC("$$$/iNat/TokenDialog/Instruction=Please paste your iNaturalist token (valid for 24 hours):"),
            width = 400
        },

        f:edit_field {
            value = LrView.bind("token"),
            width_in_chars = 50
        },

        f:push_button {
            title = LOC("$$$/iNat/TokenDialog/OpenPage=Open token generation page"),
            action = openTokenPage
        },

        f:push_button {
            title = LOC("$$$/iNat/TokenDialog/Save=Save token"),
            action = function()
                prefs.token = props.token
                LrDialogs.message(LOC("$$$/iNat/TokenDialog/Saved=Token successfully saved."))
            end
        }
    }

    LrDialogs.presentModalDialog {
        title = LOC("$$$/iNat/TokenDialog/Title=iNaturalist Token Setup"),
        contents = contents
    }
end

--------------------------------------------------------------------------------
-- Exported functions
--------------------------------------------------------------------------------
return {
    showTokenDialog = showTokenDialog,
    isTokenValid    = isTokenValid
}

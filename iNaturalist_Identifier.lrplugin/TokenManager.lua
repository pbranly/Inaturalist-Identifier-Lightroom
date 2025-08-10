--[[
=====================================================================================
 Script       : TokenManager.lua
 Purpose      : Manage iNaturalist API token within Lightroom plugin (UI + Validation)
 Author       : Philippe
=====================================================================================
--]]

-- Lightroom SDK modules
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrView    = import "LrView"
local LrTasks   = import "LrTasks"

-- Simple logger (remplace si besoin par ton Logger complet)
local logger = require("Logger") or {}
function logger.log(msg)
    -- print("[TokenManager] " .. msg) -- activer pour debug console
end

-- UI factory and plugin preferences
local f     = LrView.osFactory()
local prefs = LrPrefs.prefsForPlugin()

-- Property table for UI binding
local props = {
    token = prefs.token or ""
}

--------------------------------------------------------------------------------
-- Function: openTokenPageSync
-- Purpose : Opens iNaturalist token generation page synchronously (no yield)
--------------------------------------------------------------------------------
local function openTokenPageSync()
    logger.log("Opening iNaturalist token generation page in default browser.")
    local url = "https://www.inaturalist.org/users/api_token"
    local openCommand
    if WIN_ENV then
        openCommand = 'start "" "' .. url .. '"'
    elseif MAC_ENV then
        openCommand = 'open "' .. url .. '"'
    else
        openCommand = 'xdg-open "' .. url .. '"'
    end
    local success, err = LrTasks.execute(openCommand)
    if not success then
        logger.log("Failed to open URL: " .. tostring(err))
    end
end

--------------------------------------------------------------------------------
-- Function: decodeBase64Url (JWT-safe)
--------------------------------------------------------------------------------
local function decodeBase64Url(input)
    -- Replace URL-safe chars
    input = input:gsub('-', '+'):gsub('_', '/')
    -- Add padding if needed
    local pad = #input % 4
    if pad > 0 then
        input = input .. string.rep('=', 4 - pad)
    end
    -- Decode manually (évite LrTasks.decodeBase64 qui peut yield)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    input = input:gsub('[^'..b..'=]', '')
    return (input:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r = r .. (f%2^i - f%2^(i-1) > 0 and '1' or '0') end
        return r
    end)
    :gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c = c + (x:sub(i,i) == '1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

--------------------------------------------------------------------------------
-- Function: isTokenValid
--------------------------------------------------------------------------------
local function isTokenValid(token)
    if not token or token == "" then
        logger.log("Token validation failed: token missing.")
        return false, LOC("$$$/iNat/Error/TokenMissing=Token is missing.")
    end

    -- JWT tokens have 3 parts separated by "."
    local header, payload = token:match("([^%.]+)%.([^%.]+)%.")
    if not payload then
        logger.log("Token validation failed: invalid format.")
        return false, LOC("$$$/iNat/Error/TokenFormat=Invalid token format.")
    end

    -- Decode payload JSON
    local payloadJson = decodeBase64Url(payload)
    if not payloadJson then
        logger.log("Token validation failed: unable to decode payload.")
        return false, LOC("$$$/iNat/Error/TokenDecode=Unable to decode token payload.")
    end

    -- Extract "exp" field (Unix timestamp)
    local exp = payloadJson:match('"exp"%s*:%s*(%d+)')
    if not exp then
        logger.log("Token validation failed: expiration field missing.")
        return false, LOC("$$$/iNat/Error/TokenNoExp=Token expiration field missing.")
    end

    exp = tonumber(exp)
    if not exp then
        logger.log("Token validation failed: invalid expiration format.")
        return false, LOC("$$$/iNat/Error/TokenExpInvalid=Invalid expiration format.")
    end

    -- Compare with current time
    local now = os.time()
    if now >= exp then
        logger.log("Token validation failed: token expired.")
        return false, LOC("$$$/iNat/Error/TokenExpired=Token has expired.")
    end

    logger.log("Token is valid.")
    return true
end

--------------------------------------------------------------------------------
-- Function: showTokenDialog
--------------------------------------------------------------------------------
local function showTokenDialog()
    logger.log("Showing token input dialog.")
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
            action = function()
                LrTasks.startAsyncTask(function()
                    openTokenPageSync()
                end)
            end
        },

        f:push_button {
            title = LOC("$$$/iNat/TokenDialog/Save=Save token"),
            action = function()
                LrTasks.startAsyncTask(function()
                    prefs.token = props.token
                    logger.log("Token saved by user.")
                    LrDialogs.message(LOC("$$$/iNat/TokenDialog/Saved=Token successfully saved."))
                end)
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

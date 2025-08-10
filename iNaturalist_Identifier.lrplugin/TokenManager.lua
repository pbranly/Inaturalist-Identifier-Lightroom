--[[
=====================================================================================
 Script       : TokenManager.lua
 Purpose      : Centralized management of iNaturalist API token in a Lightroom plugin
 Author       : Philippe

 Overview:
 ---------
 This module handles *everything* related to the iNaturalist API token:
  - Checking if a token exists and is valid
  - Opening a UI to let the user paste/update it
  - Saving the token to Lightroom preferences
  - Opening the official token generation webpage in the user's browser

 With this approach, there is no need for a separate VerificationToken.lua file.

 Key Functions:
  - openTokenPage()              : Opens iNaturalist's token generation page
  - showOrUpdateTokenDialog()    : Shows the modal UI to paste and save the token
  - isTokenValid(token)          : Checks if a token is valid (format/expiration)
  - ensureValidToken()           : Returns a valid token or prompts the user

 Dependencies:
  - Lightroom SDK: LrPrefs, LrDialogs, LrView, LrTasks
  - Localization via LOC()
  - OS detection: WIN_ENV, MAC_ENV
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

-- Property table bound to UI controls
local props = { token = prefs.token or "" }

--------------------------------------------------------------------------------
-- Function: openTokenPage
-- Opens the iNaturalist API token generation page in the user's default browser
--------------------------------------------------------------------------------
local function openTokenPage()
    local url = "https://www.inaturalist.org/users/api_token"
    LrTasks.startAsyncTask(function()
        local openCommand
        if WIN_ENV then
            openCommand = 'start "" "' .. url .. '"'      -- Windows
        elseif MAC_ENV then
            openCommand = 'open "' .. url .. '"'          -- macOS
        else
            openCommand = 'xdg-open "' .. url .. '"'      -- Linux/Unix
        end
        LrTasks.execute(openCommand)
    end)
end

--------------------------------------------------------------------------------
-- Function: isTokenValid
-- Checks if a token is valid. Currently only checks existence and non-empty.
-- You can expand this to check:
--  - Expiration date (24h validity for iNat tokens)
--  - Proper JWT format (3 parts separated by '.')
--------------------------------------------------------------------------------
local function isTokenValid(token)
    return (token ~= nil) and (token ~= "")
end

--------------------------------------------------------------------------------
-- Function: showOrUpdateTokenDialog
-- Displays a modal dialog for the user to paste and save the token.
-- Pre-fills with the current token if it exists.
--------------------------------------------------------------------------------
local function showOrUpdateTokenDialog()
    -- Refresh props from preferences
    props.token = prefs.token or ""

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
-- Function: ensureValidToken
-- Returns a valid token or prompts the user until they provide one.
-- Returns nil if the user cancels without entering a valid token.
--------------------------------------------------------------------------------
local function ensureValidToken()
    local token = prefs.token

    if not isTokenValid(token) then
        showOrUpdateTokenDialog()
        token = prefs.token
        if not isTokenValid(token) then
            return nil
        end
    end

    return token
end

--------------------------------------------------------------------------------
-- Exported functions
--------------------------------------------------------------------------------
return {
    openTokenPage = openTokenPage,
    showOrUpdateTokenDialog = showOrUpdateTokenDialog,
    ensureValidToken = ensureValidToken
}

--[[
=====================================================================================
 Script       : update_token.lua
 Purpose      : UI dialog for entering and saving an iNaturalist API token
 Author       : Philippe

 Functional Overview:
 This script creates a modal dialog in Adobe Lightroom that allows users to enter,
 save, and manage their iNaturalist API token. The token is required for authenticating
 API requests such as species identification and observation submission.

 Key Features:
 - Modal dialog ensures focused interaction
 - Opens the official token generation page in the user's default browser
 - Saves token persistently using Lightroom plugin preferences
 - Pre-fills token field if a token is already stored
 - Cross-platform support for launching URLs
 - Localization-ready via `LOC()` strings

 How It Works:
 1. Builds a UI with a text field and two buttons (open page, save token)
 2. Opens the token generation page asynchronously based on OS
 3. Stores the token in plugin preferences for reuse across sessions

 Dependencies:
 - Lightroom SDK: LrPrefs, LrDialogs, LrView, LrTasks
 - Localization strings via LOC()
 - Platform detection variables: WIN_ENV, MAC_ENV

 Notes:
 - iNaturalist tokens expire after 24 hours; users must renew them periodically.
=====================================================================================
--]]

-- Import Lightroom SDK modules
local LrPrefs   = import "LrPrefs"    -- For persistent plugin preferences
local LrDialogs = import "LrDialogs"  -- For displaying modal dialogs
local LrView    = import "LrView"     -- For building UI elements
local LrTasks   = import "LrTasks"    -- For running asynchronous tasks

-- Create a UI factory for constructing controls
local f = LrView.osFactory()

-- Load plugin preferences
local prefs = LrPrefs.prefsForPlugin()

-- Create a property table for UI binding
local props = {
    token = prefs.token or ""  -- Pre-fill with stored token if available
}

--[[
 Function: openTokenPage
 Description:
 Opens the iNaturalist token generation page in the user's default browser.
 Uses platform-specific shell commands and runs asynchronously to avoid blocking Lightroom.
--]]
local function openTokenPage()
    local url = "https://www.inaturalist.org/users/api_token"
    LrTasks.startAsyncTask(function()
        local openCommand
        if WIN_ENV then
            openCommand = 'start "" "' .. url .. '"'     -- Windows
        elseif MAC_ENV then
            openCommand = 'open "' .. url .. '"'         -- macOS
        else
            openCommand = 'xdg-open "' .. url .. '"'     -- Linux/Unix
        end
        LrTasks.execute(openCommand)
    end)
end

--[[
 UI Layout: contents
 Description:
 Builds the modal dialog layout using a vertical column of UI elements:
 - Instructional text
 - Token input field
 - Button to open token page
 - Button to save token
--]]
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

--[[
 Dialog Presentation
 Description:
 Displays the constructed UI as a modal dialog. Blocks until the user closes it.
--]]
LrDialogs.presentModalDialog {
    title = LOC("$$$/iNat/TokenDialog/Title=iNaturalist Token Setup"),
    contents = contents
}
--[[
=====================================================================================
 Script       : verificationtoken.luan
 Author       : Philippe

 Functional Overview:
 This script creates a modal dialog in Adobe Lightroom that allows users to paste
 their personal iNaturalist API token. The token is required for authenticating
 requests to the iNaturalist API, such as species identification and observation
 submission.

 Key Features:
 - Prompts user to paste a valid iNaturalist token (valid for 24 hours).
 - Provides a button to open the official token generation page in the default browser.
 - Saves the token persistently using Lightroom plugin preferences.
 - Pre-fills the input field with any previously saved token.
 - Executes browser-opening commands asynchronously to avoid UI blocking.

 Dependencies:
 - Lightroom SDK modules: LrView, LrDialogs, LrPrefs, LrTasks
 - Platform detection variables: WIN_ENV, MAC_ENV (must be defined elsewhere)

 Usage Notes:
 - This dialog is typically invoked during plugin setup or when the token expires.
 - The saved token is accessible via `LrPrefs.prefsForPlugin().token`.
=====================================================================================
--]]

-- Import Lightroom SDK modules
local LrPrefs   = import "LrPrefs"    -- For persistent plugin preferences
local LrDialogs = import "LrDialogs"  -- For modal dialog display
local LrView    = import "LrView"     -- For building UI elements
local LrTasks   = import "LrTasks"    -- For asynchronous task execution

-- Create a UI factory
local f = LrView.osFactory()

-- Load plugin preferences
local prefs = LrPrefs.prefsForPlugin()

-- Create a property table for UI binding
local props = {
    token = prefs.token or ""  -- Pre-fill with saved token if available
}

--[[
 Function: openTokenPage
 Description:
 Opens the official iNaturalist token generation page in the user's default browser.
 Uses platform-specific shell commands and runs asynchronously to avoid freezing Lightroom.
--]]
local function openTokenPage()
    local url = "https://www.inaturalist.org/users/api_token"
    LrTasks.startAsyncTask(function()
        local openCommand
        if WIN_ENV then
            openCommand = 'start "" "' .. url .. '"'    -- Windows
        elseif MAC_ENV then
            openCommand = 'open "' .. url .. '"'        -- macOS
        else
            openCommand = 'xdg-open "' .. url .. '"'    -- Linux/Unix
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
        width = 400,
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
--[[
    Script: update_token.lua
    ------------------------
    This script provides a Lightroom user interface for entering and saving an iNaturalist API token.

    Purpose:
    --------
    Allows the user to:
      1. Open the iNaturalist token generation webpage in their default browser.
      2. Paste the generated token into a text field.
      3. Save the token to Lightroom plugin preferences for future use (e.g., in API calls).

    How It Works:
    -------------
    - Uses Lightroom's UI framework (`LrView`) to build a simple dialog box.
    - Provides a push button that opens the browser to the iNaturalist token page.
    - Accepts the user's token input and stores it persistently using `LrPrefs`.
    - Executes URL opening logic differently depending on the operating system (Windows, macOS, or Linux).

    Features:
    ---------
    - Modal dialog to ensure focus while entering token.
    - Cross-platform support for opening URLs.
    - Localization-ready (uses `LOC()` for translatable strings).
    - Token is saved and reused automatically without requiring re-entry on each session.

    Dependencies:
    -------------
    - Lightroom SDK modules: `LrPrefs`, `LrDialogs`, `LrView`, `LrTasks`
    - Plugin-specific localization strings via the `LOC` function

    Notes:
    ------
    iNaturalist API tokens expire after 24 hours. The user may need to repeat this process periodically.
]]

-- Import Lightroom SDK modules
local LrPrefs   = import "LrPrefs"    -- Module to read/write plugin preferences
local LrDialogs = import "LrDialogs"  -- Module for UI dialogs (e.g., messages, modal windows)
local LrView    = import "LrView"     -- UI construction module
local LrTasks   = import "LrTasks"    -- For executing asynchronous tasks (e.g., launching browser)

-- Create a UI factory object (used to build Lightroom-native UI controls)
local f = LrView.osFactory()

-- Access stored plugin preferences
local prefs = LrPrefs.prefsForPlugin()

-- Create a property table for binding UI values (e.g., token input)
local props = { token = prefs.token or "" }  -- Default to stored token if it exists

-- Function that opens the iNaturalist token generation page in the default browser
local function openTokenPage()
    local url = "https://www.inaturalist.org/users/api_token"  -- Token generation page

    -- Run this in an asynchronous task to avoid blocking the Lightroom UI
    LrTasks.startAsyncTask(function()
        local openCommand

        -- OS-specific commands to open a URL
        if WIN_ENV then
            openCommand = 'start "" "' .. url .. '"'
        elseif MAC_ENV then
            openCommand = 'open "' .. url .. '"'
        else
            openCommand = 'xdg-open "' .. url .. '"'
        end

        -- Execute the command
        LrTasks.execute(openCommand)
    end)
end

-- Build the dialog UI layout using a vertical column layout
local contents = f:column {
    bind_to_object = props,               -- Binds UI controls to the `props` table
    spacing = f:control_spacing(),        -- Standard spacing between elements

    -- Instruction label for the user
    f:static_text {
        title = LOC("$$$/iNat/TokenDialog/Instruction=Please paste your iNaturalist token (valid for 24 hours):"),
        width = 400,
    },

    -- Text input field for entering the token
    f:edit_field {
        value = LrView.bind("token"),     -- Binds the value to props.token
        width_in_chars = 50               -- Display width
    },

    -- Button to open the token generation page in a browser
    f:push_button {
        title = LOC("$$$/iNat/TokenDialog/OpenPage=Open token generation page"),
        action = openTokenPage
    },

    -- Button to save the entered token to Lightroom plugin preferences
    f:push_button {
        title = LOC("$$$/iNat/TokenDialog/Save=Save token"),
        action = function()
            prefs.token = props.token    -- Save the token persistently
            LrDialogs.message(LOC("$$$/iNat/TokenDialog/Saved=Token successfully saved."))
        end
    }
}

-- Show the UI as a modal dialog
LrDialogs.presentModalDialog {
    title = LOC("$$$/iNat/TokenDialog/Title=iNaturalist Token Setup"),  -- Window title
    contents = contents                                                 -- UI content defined above
}

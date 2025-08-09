--[[
=====================================================================================
 Script : Token Dialog for iNaturalist Plugin
 Author : Philippe (or your name if you prefer)
 Description :
 This script creates a modal dialog in Adobe Lightroom that allows the user to paste 
 their iNaturalist API token. This token is required for the plugin to interact with 
 the iNaturalist API and identify species from exported photos.

 Features:
 - Prompts the user to paste a personal iNaturalist token (valid for 24 hours).
 - Includes a button to open the official iNaturalist token generation webpage.
 - Saves the token into persistent plugin preferences so it's remembered across sessions.
 - If a token is already stored, it is pre-filled into the input field.

 This script uses Lightroom SDK modules such as LrView, LrDialogs, LrPrefs, and LrTasks.
 It also runs system-level browser-opening commands asynchronously to avoid freezing the UI.

=====================================================================================
--]]

-- Import Lightroom SDK modules
local LrPrefs   = import "LrPrefs"    -- For storing and retrieving persistent plugin preferences
local LrDialogs = import "LrDialogs"  -- For showing modal and non-modal dialog windows
local LrView    = import "LrView"     -- For creating Lightroom-native user interface elements
local LrTasks   = import "LrTasks"    -- For background tasks (e.g., launching external commands)

-- Create a factory for building UI elements
local f = LrView.osFactory()

-- Load saved preferences for this plugin (used to remember token across sessions)
local prefs = LrPrefs.prefsForPlugin()

-- Create a property table used to bind values between UI and data
-- If a token has already been saved, it is loaded here
local props = {
    token = prefs.token or ""  -- Default to empty string if no token is stored
}

-- Function to open the iNaturalist token generation page in the default web browser
local function openTokenPage()
    local url = "https://www.inaturalist.org/users/api_token"  -- Official URL to generate a new token

    -- Run browser launch asynchronously so Lightroom doesn't freeze
    LrTasks.startAsyncTask(function()
        local openCommand

        -- Detect and build platform-specific shell commands to open a browser
        if WIN_ENV then
            openCommand = 'start "" "' .. url .. '"'    -- Windows
        elseif MAC_ENV then
            openCommand = 'open "' .. url .. '"'        -- macOS
        else
            openCommand = 'xdg-open "' .. url .. '"'    -- Linux/other Unix
        end

        -- Execute the command to open the browser
        LrTasks.execute(openCommand)
    end)
end

-- Build the dialog layout using a vertical column of elements
local contents = f:column {
    bind_to_object = props,               -- Bind the UI elements to the `props` table
    spacing = f:control_spacing(),        -- Use Lightroom's default spacing

    -- Explanatory static text
    f:static_text {
        title = LOC("$$$/iNat/TokenDialog/Instruction=Please paste your iNaturalist token (valid for 24 hours):"),
        width = 400,  -- Width in pixels
    },

    -- Text field for the user to paste the API token
    f:edit_field {
        value = LrView.bind("token"),     -- Binds the field to props.token
        width_in_chars = 50               -- Display width (approximate number of characters)
    },

    -- Button that opens the token generation webpage in the browser
    f:push_button {
        title = LOC("$$$/iNat/TokenDialog/OpenPage=Open token generation page"),
        action = openTokenPage            -- Calls the function defined above
    },

    -- Button to save the entered token to plugin preferences
    f:push_button {
        title = LOC("$$$/iNat/TokenDialog/Save=Save token"),
        action = function()
            prefs.token = props.token     -- Store the token persistently in plugin preferences
            LrDialogs.message(LOC("$$$/iNat/TokenDialog/Saved=Token successfully saved.")) -- Confirmation
        end
    }
}

-- Display the UI as a modal dialog (blocking until the user closes it)
LrDialogs.presentModalDialog {
    title = LOC("$$$/iNat/TokenDialog/Title=iNaturalist Token Setup"),  -- Title shown in the dialog window
    contents = contents                                                 -- UI layout defined above
}
--[[
============================================================
Functional Description
------------------------------------------------------------
This script provides a modal user interface in Lightroom 
to allow the user to enter and save an iNaturalist authentication 
token (valid for 24 hours) into the plugin preferences.

Main features:
1. Display a modal dialog containing:
   - An input field to paste the iNaturalist token.
   - A button to open the official token generation webpage.
   - A button to save the token into the plugin preferences.
2. Open the webpage in the default browser, using an OS-appropriate 
   shell command (Windows, macOS, Linux).
3. Save the token in Lightroom preferences accessible to other plugin modules.

------------------------------------------------------------
Detailed Steps
1. Import necessary Lightroom modules (prefs, dialogs, view, tasks).
2. Create a factory object to build the UI.
3. Retrieve the current token value from plugin preferences.
4. Define `openTokenPage` function that opens the official iNaturalist 
   token page via a shell command depending on the OS.
5. Build the modal UI with:
   - Instruction text.
   - Text field bound to the `token` variable.
   - Button to open the token generation page.
   - Button to save the token in prefs and notify the user.
6. Show the modal dialog.

------------------------------------------------------------
Called Modules
- Lightroom SDK (LrPrefs, LrDialogs, LrView, LrTasks)

------------------------------------------------------------
Calling Scripts
- TokenUpdater.lua (which launches this script to update the token)

============================================================
]]

-- 1. Import necessary Lightroom modules
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrView    = import "LrView"
local LrTasks   = import "LrTasks"

-- 2. Create a factory object to build the UI
local f = LrView.osFactory()

-- 3. Retrieve current token value from plugin preferences
local prefs = LrPrefs.prefsForPlugin()
local props = { token = prefs.token or "" }

-- 4. Define the function to open the official iNaturalist token page
local function openTokenPage()
    local url = "https://www.inaturalist.org/users/api_token"
    LrTasks.startAsyncTask(function()
        local openCommand
        if WIN_ENV then
            -- Windows command
            openCommand = 'start "" "' .. url .. '"'
        elseif MAC_ENV then
            -- macOS command
            openCommand = 'open "' .. url .. '"'
        else
            -- Linux or others command
            openCommand = 'xdg-open "' .. url .. '"'
        end
        -- Execute command to open the browser
        LrTasks.execute(openCommand)
    end)
end

-- 5. Build the modal user interface
local contents = f:column {
    bind_to_object = props,
    spacing = f:control_spacing(),

    -- 5.a Instruction text
    f:static_text {
        title = LOC("$$$/iNat/TokenDialog/Instruction=Please paste your iNaturalist token (valid for 24 hours):"),
        width = 400,
    },

    -- 5.b Text field bound to the 'token' variable
    f:edit_field {
        value = LrView.bind("token"),
        width_in_chars = 50
    },

    -- 5.c Button to open the token generation page
    f:push_button {
        title = LOC("$$$/iNat/TokenDialog/OpenPage=Open token generation page"),
        action = openTokenPage
    },

    -- 5.d Button to save the token into preferences and notify user
    f:push_button {
        title = LOC("$$$/iNat/TokenDialog/Save=Save token"),
        action = function()
            prefs.token = props.token
            LrDialogs.message(LOC("$$$/iNat/TokenDialog/Saved=Token successfully saved."))
        end
    }
}

-- 6. Show the modal dialog
LrDialogs.presentModalDialog {
    title = LOC("$$$/iNat/TokenDialog/Title=iNaturalist Token Setup"),
    contents = contents
}

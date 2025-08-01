-- Import Lightroom SDK modules
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrView    = import "LrView"
local LrTasks   = import "LrTasks"

-- Create a UI factory object
local f = LrView.osFactory()

-- Access plugin preferences
local prefs = LrPrefs.prefsForPlugin()
local props = { token = prefs.token or "" }

-- Function to open the iNaturalist token page in the default browser, based on OS
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

-- Build the modal dialog UI
local contents = f:column {
    bind_to_object = props,
    spacing = f:control_spacing(),

    -- Instructional text
    f:static_text {
        title = LOC("$$$/iNat/TokenDialog/Instruction=Please paste your iNaturalist token (valid for 24 hours):"),
        width = 400,
    },

    -- Input field for the token
    f:edit_field {
        value = LrView.bind("token"),
        width_in_chars = 50
    },

    -- Button to open token generation page
    f:push_button {
        title = LOC("$$$/iNat/TokenDialog/OpenPage=Open token generation page"),
        action = openTokenPage
    },

    -- Button to save the token to preferences
    f:push_button {
        title = LOC("$$$/iNat/TokenDialog/Save=Save token"),
        action = function()
            prefs.token = props.token
            LrDialogs.message(LOC("$$$/iNat/TokenDialog/Saved=Token successfully saved."))
        end
    }
}

-- Display the modal dialog with the UI
LrDialogs.presentModalDialog {
    title = LOC("$$$/iNat/TokenDialog/Title=iNaturalist Token Setup"),
    contents = contents
}

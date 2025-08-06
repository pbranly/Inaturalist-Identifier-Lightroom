--[[
=====================================================================================
 Script : TokenUpdater.lua
 Purpose : Provide a full UI and logic to update and store the iNaturalist API token.
 Author  : Philippe (or your name here)

 Description :
 This script combines the logic of the old `runUpdateTokenScript.lua` and `update_token.lua`.
 It presents a modal dialog to the user to enter their token, with a button to open the
 iNaturalist token generation page in their browser.

 The entered token is stored using Lightroom's preferences system (`LrPrefs`) and will be 
 reused automatically by other plugin modules.

 Usage :
 You can call this script directly using: `dofile("TokenUpdater.lua")`
 Or import it as a module and use: `require("TokenUpdater").launchTokenUpdater()`

 Dependencies :
 Lightroom SDK modules:
 - LrPrefs, LrDialogs, LrView, LrTasks
=====================================================================================
--]]

-- Lightroom SDK imports
local LrPrefs   = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrView    = import "LrView"
local LrTasks   = import "LrTasks"

-- Create the module
local TokenUpdater = {}

function TokenUpdater.launchTokenUpdater()
    local f = LrView.osFactory()
    local prefs = LrPrefs.prefsForPlugin()
    local props = { token = prefs.token or "" }

    -- Function to open the iNaturalist token page
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

    -- UI definition
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

    -- Show the UI as a modal dialog
    LrDialogs.presentModalDialog {
        title = LOC("$$$/iNat/TokenDialog/Title=iNaturalist Token Setup"),
        contents = contents
    }
end

-- Return module table
return TokenUpdater

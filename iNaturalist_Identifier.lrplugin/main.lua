--[[
    Script: identify.lua
    --------------------
    This lightweight script serves as an entry point to trigger the species identification
    process using the AnimalIdentifier module.

    Purpose:
    --------
    Calls the `identify()` function defined in `AnimalIdentifier.lua` to process the exported image 
    (usually "tempo.jpg") and attempt to identify the animal species using the iNaturalist API.

    How It Works:
    -------------
    1. Imports the AnimalIdentifier module.
    2. Calls the exported `identify()` function directly.

    Dependencies:
    -------------
    - AnimalIdentifier.lua : Contains the full implementation of the identification logic.
    - tempo.jpg             : Should already exist (exported photo to be analyzed).
    - Lightroom SDK         : Required indirectly by the AnimalIdentifier module.

    Notes:
    ------
    This script is typically invoked asynchronously by the plugin UI or other automation logic 
    after a photo is selected and exported.
]]

-- Import the module responsible for identifying animals
local identifyanimal = require("AnimalIdentifier")

-- Call the 'identify' function defined in the AnimalIdentifier module
identifyanimal.identify()  -- ✅ function call is correctly invoked

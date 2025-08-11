--[[
============================================================
Functional Description
------------------------------------------------------------
This script `main.lua` is the entry point of the plugin when 
launched from Lightroom’s "File > Export" menu.  
Its simple but essential role is to:  
1. Import the module responsible for animal identification.  
2. Call the main function of this module to start the identification process.

------------------------------------------------------------
Numbered Steps
1. Import the `Inaturalist_Identifier` module containing the identification logic.
2. Call the `identify()` function from this module to perform identification.

------------------------------------------------------------
Called Scripts
- Inaturalist_Identifier.lua (main identification module)

------------------------------------------------------------
Calling Script
- Declared in `Info.lua` under the `LrExportMenuItems` key  
  → Lightroom runs `main.lua` when selecting  
    "Identify wildlife via iNaturalist" from the Export menu.
============================================================
]]

-- [Step 1] Import the module responsible for identifying animals
local identifier = require("Inaturalist_Identifier")

-- [Step 2] Call the 'identify' function defined in the Inaturalist_Identifier module
identifier.identify()

--[[
============================================================
Description fonctionnelle
------------------------------------------------------------
Ce script `main.lua` est le point d’entrée du plugin lorsqu’il est
lancé depuis le menu "Fichier > Exporter" de Lightroom.  
Son rôle est simple mais essentiel :  
1. Importer le module chargé d’identifier les animaux.  
2. Appeler la fonction principale de ce module pour lancer 
   l’identification.  

------------------------------------------------------------
Étapes numérotées
1. Importer le module `AnimalIdentifier` qui contient la logique 
   d’identification.
2. Appeler la fonction `identify()` de ce module pour exécuter 
   l’identification.

------------------------------------------------------------
Scripts appelés
- AnimalIdentifier.lua (module principal d’identification)

------------------------------------------------------------
Script appelant
- Déclaré dans `Info.lua` via la clé `LrExportMenuItems`  
  → Lightroom exécute `main.lua` lorsqu’on sélectionne  
    "Identify wildlife via iNaturalist" dans le menu Exporter.
============================================================
]]

-- [Étape 1] Import the module responsible for identifying animals
local identifyanimal = require("AnimalIdentifier")

-- [Étape 2] Call the 'identify' function defined in the AnimalIdentifier module
identifyanimal.identify()  -- ✅ function call is correctly invoked

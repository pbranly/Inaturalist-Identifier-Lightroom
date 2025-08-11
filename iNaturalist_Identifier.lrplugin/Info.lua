--[[
============================================================
Description fonctionnelle
------------------------------------------------------------
Ce script `Info.lua` définit les métadonnées et la configuration 
principale d’un plugin Lightroom pour identifier la faune via 
la plateforme iNaturalist.

Il s’agit d’un fichier de configuration Lua spécifique au SDK 
de Lightroom, qui permet :
1. D’indiquer le nom, l’identifiant unique et la compatibilité 
   avec les versions du SDK Lightroom.
2. De fournir l’URL d’informations sur le plugin.
3. De définir les éléments de menu dans Lightroom, en précisant 
   le script principal à exécuter lors du choix de l’option.
4. De spécifier les scripts annexes comme le fournisseur 
   d’informations pour le gestionnaire de plugins.
5. De définir le type de plugin et sa version.

------------------------------------------------------------
Étapes numérotées
1. Déclarer le nom du plugin affiché dans Lightroom.
2. Définir l’identifiant unique du plugin (Toolkit Identifier).
3. Spécifier les versions du SDK Lightroom supportées.
4. Fournir l’URL vers les informations du plugin.
5. Déclarer l’élément de menu dans "Fichier > Exporter" et 
   le script à lancer.
6. Spécifier le script d’interface pour le gestionnaire de plugins.
7. Indiquer le type de plugin.
8. Définir la version du plugin.

------------------------------------------------------------
Scripts appelés
- main.lua (script principal exécuté via le menu Exporter)
- PluginInfoProvider.lua (script pour l’affichage d’informations 
  dans le gestionnaire de plugins Lightroom)

------------------------------------------------------------
Script appelant
- Lightroom (application hôte) via son moteur interne de 
  chargement de plugins SDK.
============================================================
]]

return {
    -- [Étape 1] Display name in Lightroom (localized)
    LrPluginName = LOC("$$$/iNat/PluginName=Identification iNaturalist"),

    -- [Étape 2] Unique identifier for the plugin
    LrToolkitIdentifier = "com.example.iNaturalistBirdIdentifier",

    -- [Étape 3] Supported Lightroom SDK versions
    LrSdkVersion = 14.0,
    LrSdkMinimumVersion = 10.0,

    -- [Étape 4] Link to plugin information website
    LrPluginInfoUrl = "https://www.inaturalist.org",

    -- [Étape 5] Script launched from the "File > Export" menu
    LrExportMenuItems = {
        {
            title = LOC("$$$/iNat/MenuItem=Identify wildlife via iNaturalist"),
            file = "main.lua",
        },
    },

    -- [Étape 6] Interface for the Plugin Manager
    LrPluginInfoProvider = "PluginInfoProvider.lua",

    -- [Étape 7] Plugin type
    LrPluginType = "export",

    -- [Étape 8] Plugin version number
    VERSION = {
        major = 0,
        minor = 0,
        revision = 0,
        build = 1,
    },
}

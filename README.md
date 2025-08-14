# iNaturalist Identifier

![iNaturalist Identifier screenshot](logo.png)

*A Lightroom Classic plugin that identifies species in photos using the iNaturalist API.*  
*Un plugin pour Lightroom Classic qui identifie les espèces présentes sur les photos en utilisant l'API iNaturalist.*

---

## Table of Contents

- [Overview](#overview)  
- [Features](#features)  
- [Installation](#installation)  
- [Configuration](#configuration)  
- [Usage](#usage)  
- [Plugin Structure](#plugin-structure)  
- [Dependencies](#dependencies)  
- [Development](#development)  
- [License](#license)  
- [Support the Project](#support-the-project)

---

## Overview  
*Présentation*

The iNaturalist Identifier plugin integrates with Adobe Lightroom Classic to help users automatically identify species captured in their photographs. It leverages the iNaturalist API to analyze selected photos and adds species identification tags based on the API's results.  
Le plugin *iNaturalist Identifier* s’intègre à Adobe Lightroom Classic pour aider les utilisateurs à identifier automatiquement les espèces présentes sur leurs photos.

---

## Features  
*Fonctionnalités*

- Send photos from Lightroom to iNaturalist's image recognition API  
  *Envoyer les photos vers l’API de reconnaissance d’image d’iNaturalist*
- Automatically tag photos with identified species  
  *Baliser automatiquement les photos avec les espèces identifiées*
- Select and tag multiple photos in batch (to be done)  
  *Sélectionner et baliser plusieurs photos en lot (à venir)*
- View detailed API responses for each image  
  *Voir les réponses détaillées de l’API pour chaque image*
- Simple and lightweight plugin using Lua  
  *Plugin simple et léger basé sur Lua*

---

## Installation  
*Installation*

1. Download or clone the repository:  
   [📥 Télécharger la dernière version](https://github.com/pbranly/Inaturalist-Identifier-Lightroom/releases/latest)
2. Open Lightroom Classic.  
   *Ouvrez Lightroom Classic.*
3. Go to **File > Plugin Manager**.  
   *Allez dans **Fichier > Gestionnaire de modules externes**.*
4. Click **Add** and navigate to the cloned folder.  
   *Cliquez sur **Ajouter** et naviguez jusqu’au dossier cloné.*
5. Select the folder and confirm.  
   *Sélectionnez le dossier et confirmez l’installation.*

---

## Configuration  
*Configuration*

The plugin requires an iNaturalist API token for authentication:  
Le plugin nécessite un jeton API iNaturalist pour l’authentification :

- Create an account on [iNaturalist](https://www.inaturalist.org).  
  *Créez un compte sur iNaturalist.*
- Generate a personal access token in your profile settings.  
  *Générez un jeton d’accès personnel dans vos paramètres de profil.*
- In Lightroom, enter your API token in the plugin panel.  
  *Dans Lightroom, entrez votre jeton API dans le panneau du plugin.*

> ⚠️ **Note:** This token is only valid for 24 hours.  
> ⚠️ *Remarque : Ce jeton est valide pendant 24 heures seulement.*

---

## Usage  
*Utilisation*

- Select one or more photos in the Lightroom Library (*not fully tested*)  
  *Sélectionnez une ou plusieurs photos dans la bibliothèque (*non testé complètement)*
- Use the plugin menu to send them to the iNaturalist API  
  *Utilisez le menu du plugin pour les envoyer à l’API iNaturalist*
- Review and apply the species tags based on results  
  *Vérifiez et appliquez les balises d’espèces selon les résultats*

---

## Plugin Structure  
*Structure du plugin*

- `Info.lua` — Plugin metadata and entry point.  
  *Métadonnées du plugin et point d’entrée principal*
- `AnimalIdentifier.lua` — Uploads images and manages API calls.  
  *Gère l’envoi des images et les appels à l’API*
- `call_inaturalist.lua` — Sends requests and processes responses.  
  *Envoie les requêtes et traite les réponses*
- `SelectAndTagResults.lua` — Interface for tagging selected species.  
  *Interface utilisateur pour le choix des résultats et le marquage*
- `json.lua` — JSON utility functions.  
  *Utilitaire pour l’encodage/décodage JSON*

---

## Dependencies  
*Dépendances*

- Adobe Lightroom Classic (Lua plugin support)  
  *Adobe Lightroom Classic avec support des plugins Lua*
- Internet connection  
  *Connexion Internet*
- Lua standard libraries  
  *Bibliothèques standard Lua (fournies avec Lightroom)*

---

## Development  
*Développement*

Feel free to fork and contribute!  
*N’hésitez pas à forker et proposer des améliorations !*

1. Fork the repository  
   *Forkez le dépôt*
2. Make your changes  
   *Modifiez le code*
3. Submit a pull request  
   *Soumettez une pull request*

---

## License  
*Licence*

This project is licensed under the MIT License. See the LICENSE file.  
*Projet sous licence MIT. Voir le fichier LICENSE.*

Developed by Philippe Branly  
*Développé par Philippe Branly*

---

## Support the Project  
*Soutenir le projet*

If this plugin is useful to you, consider supporting its development:  
*Si ce plugin vous est utile, vous pouvez soutenir son développement :*

- [Buy me a coffee](https://www.buymeacoffee.com/philippebro)  
  *Offrez-moi un café*
- Donate via PayPal: [paypal.me/philippebranly](https://www.paypal.me/philippebranly)  
  *Ou faites un don via PayPal*  




# iNaturalist Identifier

![Capture d’écran du plugin](logo.png)

Un plugin pour Lightroom Classic qui identifie les espèces présentes sur les photos en utilisant l'API iNaturalist.

---

## Sommaire

- [Présentation](#présentation)
- [Fonctionnalités](#fonctionnalités)
- [Installation](#installation)
- [Configuration](#configuration)
- [Utilisation](#utilisation)
- [Structure du plugin](#structure-du-plugin)
- [Dépendances](#dépendances)
- [Développement](#développement)
- [Licence](#licence)
- [Soutenir le projet](#soutenir-le-projet)

---

## Présentation

Le plugin iNaturalist Identifier s’intègre à Adobe Lightroom Classic pour aider les photographes à identifier automatiquement les espèces visibles sur leurs clichés.  
Il utilise l’API iNaturalist pour analyser les images sélectionnées et ajoute des balises d’identification selon les résultats obtenus.

---

## Fonctionnalités

- 📤 Envoi des photos vers l’API de reconnaissance d’image d’iNaturalist  
- 🏷️ Balises automatiques avec les espèces identifiées  
- 📚 Traitement en lot des photos (fonctionnalité à venir)  
- 🔍 Affichage des réponses détaillées de l’API pour chaque image  
- 🧩 Plugin léger et simple, développé en Lua

---

## Installation

1. [📥 Télécharger la dernière version](https://github.com/pbranly/Inaturalist-Identifier-Lightroom/releases/latest)  
2. Ouvrir Lightroom Classic  
3. Aller dans **Fichier > Gestionnaire de modules externes**  
4. Cliquer sur **Ajouter** et sélectionner le dossier du plugin  
5. Confirmer l’installation

---

## Configuration

Le plugin nécessite un jeton d’accès API iNaturalist :

- Créer un compte sur [iNaturalist](https://www.inaturalist.org)  
- Générer un jeton personnel dans les paramètres du profil  
- Saisir ce jeton dans le panneau du plugin dans Lightroom

> ⚠️ Remarque : Le jeton est valide pendant 24 heures seulement.

---

## Utilisation

- Sélectionner une ou plusieurs photos dans la bibliothèque Lightroom (*fonctionnalité en cours de test*)  
- Utiliser le menu du plugin pour les envoyer à l’API iNaturalist  
- Vérifier les résultats et appliquer les balises d’espèces proposées

---

## Structure du plugin

| Fichier                    | Description                                         |
|---------------------------|-----------------------------------------------------|
| `Info.lua`                | Métadonnées et point d’entrée du plugin             |
| `AnimalIdentifier.lua`    | Gestion de l’envoi des images et des appels API     |
| `call_inaturalist.lua`    | Requêtes vers l’API et traitement des réponses      |
| `SelectAndTagResults.lua` | Interface utilisateur pour le marquage des espèces  |
| `json.lua`                | Fonctions utilitaires pour le JSON                  |

---

## Dépendances

- Adobe Lightroom Classic (support des plugins Lua)  
- Connexion Internet  
- Bibliothèques Lua standard (incluses avec Lightroom)

---

## Développement

Tu veux contribuer ? Super !

1. Forker le dépôt  
2. Modifier le code  
3. Soumettre une pull request

---

## Licence

Projet sous licence MIT. Voir le fichier LICENSE.  
Développé par Philippe Branly.

---

## Soutenir le projet

Si ce plugin t’est utile, tu peux soutenir son développement :

- [☕ Offrez-moi un café](https://www.buymeacoffee.com/philippebro)  
- [💸 Faire un don via PayPal](https://www.paypal.me/philippebranly)

# ============================================================
# Description fonctionnelle
# ------------------------------------------------------------
# Ce script envoie une image à l’API iNaturalist pour identifier 
# automatiquement l’animal présent (notamment les oiseaux).
# Il utilise un token d’authentification et renvoie la liste 
# des espèces reconnues avec un pourcentage de confiance normalisé.
#
# Fonctionnalités principales :
# 1. Forcer l'encodage UTF-8 pour l’affichage console.
# 2. Vérifier la présence de l’image donnée en paramètre.
# 3. Envoyer l’image à l’API iNaturalist avec le token fourni.
# 4. Traiter les erreurs HTTP et afficher les messages correspondants.
# 5. Extraire et afficher la liste des animaux reconnus avec pourcentages.
#
# ------------------------------------------------------------
# Étapes détaillées
# 1. Importer les modules nécessaires (requests, sys, os).
# 2. Forcer l’encodage UTF-8 pour un affichage correct.
# 3. Définir la fonction identify_bird(image_path, token).
# 4. Vérifier que le fichier image existe, sinon quitter.
# 5. Envoyer la requête POST à l’API iNaturalist avec l’image et le token.
# 6. Vérifier le code de réponse HTTP et gérer les erreurs.
# 7. Extraire et traiter les résultats de l’API.
# 8. Calculer les pourcentages de confiance normalisés.
# 9. Afficher les espèces reconnues et leurs scores.
# 10. Gérer le point d’entrée du script avec les arguments CLI.
#
# ------------------------------------------------------------
# Modules appelés :
# - requests (HTTP)
# - sys (gestion arguments + sortie)
# - os (vérification de fichier)
#
# ------------------------------------------------------------
# Script appelant :
# - Appelé directement en ligne de commande
# - Ou déclenché par un autre script/plugin Lightroom (non inclus ici)
# ============================================================

# 1. Importer les modules nécessaires
import requests
import sys
import os

# 2. Forcer UTF-8 pour affichage console
sys.stdout.reconfigure(encoding='utf-8')

# 3. Définir la fonction principale
def identify_bird(image_path, token):
    url = "https://api.inaturalist.org/v1/computervision/score_image"

    headers = {
        "Authorization": f"Bearer {token}",
        "User-Agent": "LightroomBirdIdentifier/1.0",
        "Accept": "application/json"
    }

    # 4. Vérifier si l'image existe
    if not os.path.exists(image_path):
        print(f"Image not found: {image_path}")
        sys.exit(1)

    # 5. Envoyer la requête POST avec l'image
    with open(image_path, "rb") as img_file:
        files = {"image": img_file}
        response = requests.post(url, headers=headers, files=files)

    # 6. Gérer les codes HTTP non 200
    if response.status_code != 200:
        print(f"API error: {response.status_code}")
        print(response.text)
        sys.exit(1)

    # 7. Extraire les résultats JSON
    results = response.json().get("results", [])
    if not results:
        print("No animal recognized.")
        return

    print("🕊️ Recognized animals:\n")

    # 8. Normaliser les scores de confiance
    max_score = max((r.get("combined_score", 0) for r in results), default=1)

    # 9. Parcourir et afficher chaque espèce
    for result in results:
        taxon = result.get("taxon", {})
        name_fr = taxon.get("preferred_common_name", "Unknown")
        name_latin = taxon.get("name", "Unknown")
        raw_score = result.get("combined_score", 0)
        normalized = round((raw_score / max_score) * 100, 1)

        print(f"- {name_fr} ({name_latin}) : {normalized}%")

# 10. Point d'entrée du script
if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python identifier_animal.py /path/to/photo.jpg <token>")
        sys.exit(1)

    image_path = sys.argv[1]
    token = sys.argv[2]
    identify_bird(image_path, token)

import requests
import sys
import os

# 🔧 Force UTF-8 output encoding for proper character rendering
sys.stdout.reconfigure(encoding='utf-8')

# 🔍 Main function to call iNaturalist API and identify animal from image
def identify_bird(image_path, token):
    url = "https://api.inaturalist.org/v1/computervision/score_image"

    headers = {
        "Authorization": f"Bearer {token}",
        "User-Agent": "LightroomBirdIdentifier/1.0",
        "Accept": "application/json"
    }

    # ❌ Check if image exists
    if not os.path.exists(image_path):
        print(f"Image not found: {image_path}")
        sys.exit(1)

    # 📤 Send image to iNaturalist API
    with open(image_path, "rb") as img_file:
        files = {"image": img_file}
        response = requests.post(url, headers=headers, files=files)

    # ⚠️ Handle non-successful HTTP response
    if response.status_code != 200:
        print(f"API error: {response.status_code}")
        print(response.text)
        sys.exit(1)

    # 📥 Parse and check results
    results = response.json().get("results", [])
    if not results:
        print("No animal recognized.")
        return

    print("🕊️ Recognized animals:\n")

    # 🧮 Normalize confidence scores (0–100%)
    max_score = max((r.get("combined_score", 0) for r in results), default=1)

    for result in results:
        taxon = result.get("taxon", {})
        name_fr = taxon.get("preferred_common_name", "Unknown")
        name_latin = taxon.get("name", "Unknown")
        raw_score = result.get("combined_score", 0)
        normalized = round((raw_score / max_score) * 100, 1)

        print(f"- {name_fr} ({name_latin}) : {normalized}%")

# 🚀 Entry point for script execution
if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python identifier_animal.py /path/to/photo.jpg <token>")
        sys.exit(1)

    image_path = sys.argv[1]
    token = sys.argv[2]
    identify_bird(image_path, token)

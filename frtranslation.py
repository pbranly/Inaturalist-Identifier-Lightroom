import os
import re

# Expression régulière pour détecter les chaînes de traduction Lightroom
pattern = re.compile(r'(\$\$\$/[^\s=]+)=(.+)')

output_file = "TranslatedStrings_fr.txt"
found_strings = {}  # clé = identifiant (ex: "$$$/iNat/PluginName"), valeur = (texte, fichier origine)

lines_out = []

# Parcourt tous les fichiers .lua du répertoire courant
for filename in sorted(os.listdir(".")):
    if filename.lower().endswith(".lua"):
        lines_out.append(f"# ===== {filename} =====\n")
        
        with open(filename, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                match = pattern.search(line)
                if match:
                    key = match.group(1).strip()
                    value = match.group(2).strip()
                    
                    if key not in found_strings:
                        found_strings[key] = (value, filename)
                        lines_out.append(f"{key}={value}\n")
                    else:
                        # Doublon : on commente
                        lines_out.append(f"# {key}={value}  # déjà vu dans {found_strings[key][1]}\n")
        lines_out.append("\n")

# Écriture du fichier final
with open(output_file, "w", encoding="utf-8") as out:
    out.writelines(lines_out)

print(f"Fichier '{output_file}' généré avec succès.")

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re

def extract_lightroom_strings(text):
    # Capture les chaînes de type LOC("$$$/clé=valeur")
    pattern = re.compile(r'LOC\("(\$\$\$/[^\s=]+)=([^\n")]+)"')
    return pattern.findall(text)

def format_translation(key, value):
    return f'"{key}={value}"'

def process_scripts_in_current_directory(output_path):
    seen_lines = set()
    output_lines = []

    for filename in sorted(os.listdir(".")):
        if filename.lower().endswith(".lua"):
            with open(filename, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()

            translations = extract_lightroom_strings(content)
            if translations:
                output_lines.append(f'# {filename}')
                for key, value in translations:
                    line = format_translation(key, value)
                    if line in seen_lines:
                        output_lines.append(f'# {line}')
                    else:
                        output_lines.append(line)
                        seen_lines.add(line)
                output_lines.append('')  # Ligne vide entre blocs

    # Écriture du fichier final
    with open(output_path, "w", encoding="utf-8") as f:
        f.write('\n'.join(output_lines))

# 🔧 Exécution dans le répertoire courant
output_file = "TranslatedStrings_en.txt"
process_scripts_in_current_directory(output_file)

print(f"Fichier '{output_file}' généré avec succès.")

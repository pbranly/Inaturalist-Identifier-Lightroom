#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
-------------------------------------------------------------------------------
Script Name: extract_lightroom_strings.py
-------------------------------------------------------------------------------
Description:
Scans all `.lua` files in the current directory to extract Lightroom translation
strings defined as:
    LOC("$$$/namespace/key=Translated Text")
or
    LOC "$$$/namespace/key=Translated Text"
Handles multi-line strings, Lua concatenations using `..`, and variable concatenations.
Generates:
    - TranslatedStrings_en.txt
-------------------------------------------------------------------------------
"""
import os
import re

# ---------------------------------------------------------------------------
# 1. Extraction logic
# ---------------------------------------------------------------------------

def extract_loc_strings_improved(text):
    """
    Extrait les chaînes LOC en gérant les concaténations avec variables.
    Recherche tous les patterns LOC et extrait uniquement la partie texte.
    """
    results = []
    
    # Pattern pour trouver LOC( ou LOC "
    # Capture: LOC("$$$/key=value" .. variable) ou LOC "$$$/key=value" .. variable
    patterns = [
        # LOC("$$$/key=value" potentiellement suivi de ..)
        r'LOC\s*\(\s*"(\$\$\$/[^=]+)=([^"]*?)"\s*(?:\.\.|,|\))',
        # LOC "$$$/key=value" potentiellement suivi de ..
        r'LOC\s+"(\$\$\$/[^=]+)=([^"]+?)"\s*(?:\.\.|$|,)',
    ]
    
    for pattern in patterns:
        matches = re.finditer(pattern, text, re.MULTILINE)
        for match in matches:
            key = match.group(1).strip()
            value = match.group(2).strip()
            
            # Nettoyer la valeur
            value = clean_value(value)
            
            # Ne garder que si la valeur n'est pas vide
            if value:
                results.append((key, value))
    
    return results


def clean_value(value):
    """
    Nettoie une valeur extraite en gérant les échappements et caractères spéciaux.
    """
    # Remplacer les placeholders Lua
    value = value.replace("^1", "{1}")
    value = value.replace("^2", "{2}")
    value = value.replace("^3", "{3}")
    
    # Gérer les retours à la ligne littéraux
    value = value.replace('\\n', ' ')
    value = value.replace('\\t', ' ')
    
    # Réduire les espaces multiples
    value = re.sub(r'\s+', ' ', value)
    
    return value.strip()


def format_translation(key, value):
    """Return formatted translation line."""
    return f'"{key}={value}"'


# ---------------------------------------------------------------------------
# 2. Main processing
# ---------------------------------------------------------------------------

def process_lua_files():
    """Extract and generate English translation file from current directory."""
    current_dir = os.getcwd()
    print(f"🔍 Scanning Lua files in: {current_dir}")
    
    seen_translations = {}  # key -> value pour détecter les doublons
    translations_by_file = {}
    
    for filename in sorted(os.listdir(current_dir)):
        if filename.lower().endswith(".lua"):
            path = os.path.join(current_dir, filename)
            
            try:
                with open(path, "r", encoding="utf-8", errors="ignore") as f:
                    content = f.read()
                
                # Extraire les chaînes
                matches = extract_loc_strings_improved(content)
                
                if matches:
                    translations_by_file[filename] = matches
                    print(f"  📄 {filename}: {len(matches)} strings found")
            except Exception as e:
                print(f"  ⚠️  Error reading {filename}: {e}")
    
    if not translations_by_file:
        print("⚠️  No translation strings found.")
        return
    
    output_path = os.path.join(current_dir, "TranslatedStrings_en.txt")
    output_lines = []
    
    for filename, translations in translations_by_file.items():
        output_lines.append(f"# {filename}")
        
        for key, value in translations:
            line = format_translation(key, value)
            
            # Vérifier les doublons
            if key in seen_translations:
                if seen_translations[key] == value:
                    output_lines.append(f"# DUPLICATE: {line}")
                else:
                    output_lines.append(f"# CONFLICT: {line} (previous: {seen_translations[key]})")
            else:
                output_lines.append(line)
                seen_translations[key] = value
        
        output_lines.append("")
    
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(output_lines))
    
    print(f"\n✅ File generated: {output_path}")
    print(f"📊 Total unique translations: {len(seen_translations)}")
    
    # Afficher quelques exemples
    print("\n📝 Sample extractions:")
    for i, (k, v) in enumerate(list(seen_translations.items())[:5]):
        print(f"   {i+1}. {k[:50]}... = {v[:50]}...")


# ---------------------------------------------------------------------------
# 3. Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    process_lua_files()
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
    Recherche tous les patterns LOC et extrait la partie texte complète.
    """
    results = []
    
    # Pattern amélioré pour capturer les chaînes complètes, même sur plusieurs lignes
    # Recherche LOC( ou LOC " suivi de $$$/key=value
    pattern = r'LOC\s*[("\s]+(\$\$\$/[^=]+)=([^"]*(?:"[^"]*)?[^"]*?)(?:"|$)'
    
    # Recherche toutes les occurrences
    pos = 0
    while pos < len(text):
        # Chercher le début d'un LOC
        loc_match = re.search(r'LOC\s*[\("]\s*"(\$\$\$/[^=]+)=', text[pos:])
        if not loc_match:
            break
        
        start = pos + loc_match.start()
        key = loc_match.group(1).strip()
        
        # Trouver la position après le =
        equals_pos = pos + loc_match.end()
        
        # Extraire la valeur jusqu'à la fin de la chaîne ou concaténation
        value = extract_value_from_position(text, equals_pos)
        
        if value:
            results.append((key, value))
        
        pos = equals_pos + 1
    
    return results


def extract_value_from_position(text, start_pos):
    """
    Extrait la valeur d'une chaîne LOC à partir d'une position donnée.
    Gère les concaténations avec .. et les chaînes multi-lignes.
    """
    value_parts = []
    pos = start_pos
    in_string = True
    paren_depth = 0
    
    while pos < len(text):
        char = text[pos]
        
        # Gérer les guillemets échappés
        if char == '\\' and pos + 1 < len(text):
            if text[pos + 1] == 'n':
                value_parts.append('\n')
                pos += 2
                continue
            elif text[pos + 1] == 't':
                value_parts.append('\t')
                pos += 2
                continue
            elif text[pos + 1] == '"':
                value_parts.append('"')
                pos += 2
                continue
            pos += 1
            continue
        
        # Fin de la chaîne
        if char == '"' and in_string:
            # Vérifier s'il y a une concaténation après
            next_chars = text[pos+1:pos+10].strip()
            if next_chars.startswith('..'):
                # Chercher la prochaine chaîne
                concat_pos = pos + 1 + next_chars.index('..')
                next_string_match = re.search(r'\s*\.\.\s*"', text[pos:concat_pos+10])
                if next_string_match:
                    pos = pos + next_string_match.end()
                    continue
                else:
                    # Pas de chaîne après .., c'est une variable
                    break
            else:
                # Fin de la valeur
                break
        
        # Ajouter le caractère à la valeur
        if in_string:
            value_parts.append(char)
        
        pos += 1
    
    value = ''.join(value_parts)
    return clean_value(value)


def clean_value(value):
    """
    Nettoie une valeur extraite en gérant les échappements et caractères spéciaux.
    """
    # Remplacer les placeholders Lua par le format {N}
    value = re.sub(r'\^(\d+)', r'{\1}', value)
    
    # Nettoyer les espaces excessifs mais garder les \n intentionnels
    lines = value.split('\n')
    cleaned_lines = []
    for line in lines:
        # Réduire les espaces multiples sur chaque ligne
        line = re.sub(r'[ \t]+', ' ', line)
        line = line.strip()
        if line:
            cleaned_lines.append(line)
    
    # Rejoindre avec \n\n pour les vraies nouvelles lignes
    if len(cleaned_lines) > 1:
        value = '\\n\\n'.join(cleaned_lines)
    else:
        value = ' '.join(cleaned_lines)
    
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
        print(f"   {i+1}. {k[:60]}...")
        print(f"       = {v[:80]}...")


# ---------------------------------------------------------------------------
# 3. Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    process_lua_files()

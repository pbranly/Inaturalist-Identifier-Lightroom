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
Handles multi-line strings and Lua concatenations using `..`.
Generates:
    - TranslatedStrings_en.txt
-------------------------------------------------------------------------------
"""
import os
import re

# ---------------------------------------------------------------------------
# 1. Extraction logic
# ---------------------------------------------------------------------------

def preprocess_lua_concatenations(text):
    """
    Prétraite le texte Lua pour fusionner les concaténations de chaînes.
    Gère les patterns comme "text" .. "more" ou "text" .. 'more'
    """
    # Remplacer les retours à la ligne et espaces multiples par un espace unique
    text = re.sub(r'\s+', ' ', text)
    
    # Fusionner les concaténations: "..." .. "..."
    # On procède itérativement jusqu'à ce qu'il n'y ait plus de changements
    max_iterations = 10
    for _ in range(max_iterations):
        # Pattern pour "texte" .. "suite"
        before = text
        text = re.sub(r'"\s*\.\.\s*"', '', text)
        # Pattern pour "texte" .. 'suite'
        text = re.sub(r'"\s*\.\.\s*\'', '', text)
        # Pattern pour 'texte' .. "suite"
        text = re.sub(r'\'\s*\.\.\s*"', '', text)
        # Pattern pour 'texte' .. 'suite'
        text = re.sub(r'\'\s*\.\.\s*\'', '', text)
        
        if text == before:
            break
    
    return text


def extract_lightroom_strings(text):
    """
    Extract Lightroom LOC() or LOC "" translation strings.
    """
    results = []
    
    # Prétraiter pour fusionner les concaténations
    processed = preprocess_lua_concatenations(text)
    
    # Pattern amélioré pour capturer les LOC avec différentes variantes
    # Capture: LOC("$$$/key=value") ou LOC "$$$/key=value"
    patterns = [
        # LOC("$$$/key=value")
        r'LOC\s*\(\s*"(\$\$\$/[^=]+)=([^"]*(?:"[^"]*"[^"]*)*?)"\s*(?:,|\))',
        # LOC "$$$/key=value"
        r'LOC\s+"(\$\$\$/[^=]+)=([^"]+)"',
    ]
    
    for pattern in patterns:
        matches = re.finditer(pattern, processed, re.DOTALL)
        for match in matches:
            key = match.group(1).strip()
            value = match.group(2).strip()
            
            # Nettoyer la valeur
            value = clean_value(value)
            
            results.append((key, value))
    
    return results


def clean_value(value):
    """
    Nettoie une valeur extraite en gérant les échappements et caractères spéciaux.
    """
    # Remplacer les quotes simples utilisées pour échapper
    value = value.replace("^1", "{1}")  # Placeholder Lua
    
    # Gérer les retours à la ligne littéraux \n
    value = value.replace('\\n', ' ')
    value = value.replace('\\t', ' ')
    
    # Supprimer les guillemets simples utilisés comme échappement
    # (dans Lua, on peut échapper " avec ' à l'intérieur)
    # Mais attention à ne pas tout casser
    
    # Réduire les espaces multiples
    value = re.sub(r'\s+', ' ', value)
    
    return value.strip()


def format_translation(key, value):
    """Return formatted translation line."""
    return f'"{key}={value}"'


# ---------------------------------------------------------------------------
# 2. Approche alternative: parser ligne par ligne
# ---------------------------------------------------------------------------

def extract_loc_strings_robust(text):
    """
    Approche plus robuste: trouve tous les LOC( et extrait jusqu'à la parenthèse fermante.
    """
    results = []
    
    # Trouver toutes les positions de LOC(
    loc_positions = []
    for match in re.finditer(r'\bLOC\s*\(', text):
        loc_positions.append(match.end())
    
    for start_pos in loc_positions:
        # Extraire depuis cette position jusqu'à trouver la clé et la valeur
        extracted = extract_from_position(text, start_pos)
        if extracted:
            results.append(extracted)
    
    return results


def extract_from_position(text, pos):
    """
    Extrait une paire clé/valeur depuis une position donnée.
    Gère les concaténations et les parenthèses imbriquées.
    """
    # Trouver d'abord la clé ($$$/...)
    key_match = re.match(r'\s*"(\$\$\$/[^=]+)=', text[pos:])
    if not key_match:
        return None
    
    key = key_match.group(1)
    value_start = pos + key_match.end()
    
    # Maintenant extraire la valeur jusqu'à la fin de la chaîne LOC
    value_parts = []
    i = value_start
    in_string = True
    paren_depth = 1  # On est déjà dans LOC(
    current_quote = '"'
    
    while i < len(text) and paren_depth > 0:
        char = text[i]
        
        if in_string:
            # On est dans une chaîne
            if char == '\\' and i + 1 < len(text):
                # Échappement
                value_parts.append(text[i:i+2])
                i += 2
                continue
            elif char == current_quote:
                # Fin de chaîne
                in_string = False
                i += 1
                
                # Chercher une concaténation
                j = i
                while j < len(text) and text[j] in ' \t\n\r':
                    j += 1
                
                if j + 1 < len(text) and text[j:j+2] == '..':
                    # Concaténation trouvée
                    j += 2
                    while j < len(text) and text[j] in ' \t\n\r':
                        j += 1
                    
                    if j < len(text) and text[j] in '"\'':
                        # Début d'une nouvelle chaîne
                        current_quote = text[j]
                        in_string = True
                        i = j + 1
                        continue
                
                # Pas de concaténation, chercher la fin
                while j < len(text) and text[j] in ' \t\n\r':
                    j += 1
                
                if j < len(text):
                    if text[j] == ')':
                        paren_depth -= 1
                        if paren_depth == 0:
                            break
                        i = j + 1
                    elif text[j] == ',':
                        # Fin du premier argument
                        break
                    else:
                        i = j
                else:
                    break
            else:
                value_parts.append(char)
                i += 1
        else:
            i += 1
    
    if not value_parts:
        return None
    
    value = ''.join(value_parts)
    value = clean_value(value)
    
    return (key, value)


# ---------------------------------------------------------------------------
# 3. Main processing
# ---------------------------------------------------------------------------

def process_lua_files():
    """Extract and generate English translation file from current directory."""
    current_dir = os.getcwd()
    print(f"🔍 Scanning Lua files in: {current_dir}")
    
    seen_lines = set()
    translations_by_file = {}
    
    for filename in sorted(os.listdir(current_dir)):
        if filename.lower().endswith(".lua"):
            path = os.path.join(current_dir, filename)
            
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
            
            # Utiliser l'approche robuste
            matches = extract_loc_strings_robust(content)
            
            if matches:
                translations_by_file[filename] = matches
                print(f"  📄 {filename}: {len(matches)} strings found")
    
    if not translations_by_file:
        print("⚠️  No translation strings found.")
        return
    
    output_path = os.path.join(current_dir, "TranslatedStrings_en.txt")
    output_lines = []
    
    for filename, translations in translations_by_file.items():
        output_lines.append(f"# {filename}")
        
        for key, value in translations:
            line = format_translation(key, value)
            
            if line in seen_lines:
                output_lines.append(f"# DUPLICATE: {line}")
            else:
                output_lines.append(line)
                seen_lines.add(line)
        
        output_lines.append("")
    
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(output_lines))
    
    print(f"\n✅ File generated: {output_path}")
    print(f"📊 Total unique translations: {len(seen_lines)}")


# ---------------------------------------------------------------------------
# 4. Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    process_lua_files()

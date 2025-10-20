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

def extract_lightroom_strings(text):
    """
    Extract Lightroom LOC() or LOC "" translation strings,
    even if split across multiple lines with Lua concatenations.
    """

    # Supprime les concaténations Lua " .. " pour recomposer la chaîne
    normalized = re.sub(r'"\s*\.\.\s*"', '', text)

    # Regroupe les retours à la ligne à l’intérieur des LOC(...)
    normalized = re.sub(r'\s*\n\s*', ' ', normalized)

    # Recherche les chaînes LOC(...) ou LOC "..."
    pattern = re.compile(
        r'LOC\s*(?:\(\s*"?|\s+)"(\$\$\$/[^\s=]+)=([^"]+)"',
        re.MULTILINE
    )

    return pattern.findall(normalized)


def format_translation(key, value):
    """Return formatted translation line."""
    return f'"{key}={value.strip()}"'

# ---------------------------------------------------------------------------
# 2. Main processing
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
            matches = extract_lightroom_strings(content)
            if matches:
                translations_by_file[filename] = matches

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
                output_lines.append(f"# {line}")
            else:
                output_lines.append(line)
                seen_lines.add(line)
        output_lines.append("")

    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(output_lines))

    print(f"✅ File generated: {output_path}")

# ---------------------------------------------------------------------------
# 3. Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    process_lua_files()

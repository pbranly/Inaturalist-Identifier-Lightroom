#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
-------------------------------------------------------------------------------
Script Name: translation.py
Author: Philippe's Python Helper (GPT-5)
-------------------------------------------------------------------------------
Functional Description:
This script scans all `.lua` files inside the `iNaturalist_Identifier.lrplugin`
directory to extract Lightroom translation strings defined as:

    LOC("$$$/namespace/key=Translated Text")
or
    LOC "$$$/namespace/key=Translated Text"

It generates or overwrites translation files:
    - TranslatedStrings_en.txt
    - TranslatedStrings_fr.txt
    - TranslatedStrings_de.txt
    - etc.

based on languages provided as command-line arguments:
    python3 translation.py fr de it

If no language is specified, only the English base file is generated.

-------------------------------------------------------------------------------
Features:
- Detects both LOC("...") and LOC "..." syntax.
- Removes duplicates (marks repeated entries as comments).
- Auto-installs `deep-translator` if missing.
- Translates extracted English strings using Google Translate.
- Saves translations per language into `iNaturalist_Identifier.lrplugin`.

-------------------------------------------------------------------------------
"""

import os
import re
import sys
import subprocess

# ---------------------------------------------------------------------------
# 1. Ensure dependency: deep-translator
# ---------------------------------------------------------------------------
try:
    from deep_translator import GoogleTranslator
except ImportError:
    print("Installing required package: deep-translator...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "deep-translator"])
    from deep_translator import GoogleTranslator


# ---------------------------------------------------------------------------
# 2. Core extraction logic
# ---------------------------------------------------------------------------

def extract_lightroom_strings(text):
    """Extract Lightroom LOC() or LOC "" translation strings."""
    pattern = re.compile(
        r'LOC\s*(?:\(\s*"?|\s+)"(\$\$\$/[^\s=]+)=([^\n")]+)"'
    )
    return pattern.findall(text)


def format_translation(key, value):
    """Return formatted translation line."""
    return f'"{key}={value}"'


# ---------------------------------------------------------------------------
# 3. Translation helper
# ---------------------------------------------------------------------------

def translate_text(text, target_lang):
    """Translate text using Google Translate, or return original on error."""
    try:
        return GoogleTranslator(source="en", target=target_lang).translate(text)
    except Exception as e:
        print(f"[WARN] Translation failed for '{text}' → {target_lang}: {e}")
        return text


# ---------------------------------------------------------------------------
# 4. Main processing
# ---------------------------------------------------------------------------

def process_lua_files(plugin_dir, output_langs):
    """Extract and generate translation files for given languages."""
    print(f"🔍 Scanning Lua files in: {plugin_dir}")

    # Step 1 — Collect all translations
    seen_lines = set()
    translations_by_file = {}
    for filename in sorted(os.listdir(plugin_dir)):
        if filename.lower().endswith(".lua"):
            path = os.path.join(plugin_dir, filename)
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
            matches = extract_lightroom_strings(content)
            if matches:
                translations_by_file[filename] = matches

    if not translations_by_file:
        print("⚠️  No translation strings found.")
        return

    # Step 2 — Build English base output
    en_output_path = os.path.join(plugin_dir, "TranslatedStrings_en.txt")
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

    with open(en_output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(output_lines))

    print(f"✅ English base file generated: {en_output_path}")

    # Step 3 — Generate translations if requested
    for lang in output_langs:
        if lang == "en":
            continue
        lang_path = os.path.join(plugin_dir, f"TranslatedStrings_{lang}.txt")
        translated_lines = []
        for line in output_lines:
            if line.startswith('"$$$'):
                key, value = line.strip('"').split("=", 1)
                translated_value = translate_text(value, lang)
                translated_lines.append(f'"{key}={translated_value}"')
            else:
                translated_lines.append(line)
        with open(lang_path, "w", encoding="utf-8") as f:
            f.write("\n".join(translated_lines))
        print(f"🌍 Translated file generated: {lang_path}")


# ---------------------------------------------------------------------------
# 5. CLI entry point
# ---------------------------------------------------------------------------

def main():
    # Determine plugin directory (fixed)
    plugin_dir = os.path.join(os.getcwd(), "iNaturalist_Identifier.lrplugin")

    # Parse language arguments
    langs = [arg.lower() for arg in sys.argv[1:]]
    if not langs:
        langs = ["en"]

    print(f"Languages selected: {', '.join(langs)}")

    if not os.path.isdir(plugin_dir):
        print(f"❌ Plugin directory not found: {plugin_dir}")
        sys.exit(1)

    process_lua_files(plugin_dir, langs)
    print("✅ All translations completed successfully.")


if __name__ == "__main__":
    main()

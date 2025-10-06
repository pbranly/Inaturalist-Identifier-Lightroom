#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
-------------------------------------------------------------------------------
Script Name: translation.py
Author: Philippe's Python Helper (GPT-5)
-------------------------------------------------------------------------------
Functional Description:
This script scans all `.lua` files in the `iNaturalist_Identifier.lrplugin`
directory to extract Lightroom translation strings of the form:

    LOC("$$$/namespace/key=Translated Text")

It then:
  1. Generates a base English file `TranslatedStrings_en.txt`
  2. Optionally translates these strings into one or more target languages
     (e.g., French, German, Italian) using Google Translate via `deep-translator`.
  3. Creates or overwrites files named:
        TranslatedStrings_<lang>.txt

Usage:
    python3 translation.py fr de it
    → generates English + French + German + Italian translation files

If no language is specified, only the English file is generated.

-------------------------------------------------------------------------------
"""

import os
import re
import sys
import subprocess

# --- Ensure deep-translator is available ------------------------------------
try:
    from deep_translator import GoogleTranslator
except ImportError:
    print("Installing required package: deep-translator ...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "deep-translator"])
    from deep_translator import GoogleTranslator

# --- Configuration -----------------------------------------------------------
PLUGIN_DIR = "iNaturalist_Identifier.lrplugin"
ENGLISH_FILE = os.path.join(PLUGIN_DIR, "TranslatedStrings_en.txt")

# --- Utility functions -------------------------------------------------------
def extract_lightroom_strings(text):
    """Extract translation strings from LOC() calls."""
    pattern = re.compile(r'LOC\("(\$\$\$/[^\s=]+)=([^\n")]+)"')
    return pattern.findall(text)

def format_translation(key, value):
    """Format Lightroom translation line."""
    return f'"{key}={value}"'

def translate_text(text, target_lang):
    """Translate English text to target_lang using Google Translate."""
    if target_lang.lower() == "en":
        return text
    try:
        return GoogleTranslator(source="en", target=target_lang).translate(text)
    except Exception as e:
        print(f"[Warning] Failed to translate '{text}' to '{target_lang}': {e}")
        return text  # fallback to original English text

# --- Main processing ---------------------------------------------------------
def process_scripts(languages):
    """Extract Lightroom strings and generate translated files."""
    seen_lines = set()
    output_en = []

    # Ensure plugin directory exists
    if not os.path.isdir(PLUGIN_DIR):
        print(f"Error: '{PLUGIN_DIR}' not found.")
        sys.exit(1)

    print(f"Scanning Lua scripts in '{PLUGIN_DIR}' ...")

    for filename in sorted(os.listdir(PLUGIN_DIR)):
        if filename.lower().endswith(".lua"):
            path = os.path.join(PLUGIN_DIR, filename)
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()

            translations = extract_lightroom_strings(content)
            if translations:
                output_en.append(f"# {filename}")
                for key, value in translations:
                    line = format_translation(key, value)
                    if line in seen_lines:
                        output_en.append(f"# {line}")
                    else:
                        output_en.append(line)
                        seen_lines.add(line)
                output_en.append("")

    # Write English file
    print(f"Writing English file: {ENGLISH_FILE}")
    with open(ENGLISH_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(output_en))

    # Generate translations
    for lang in languages:
        lang = lang.lower()
        if lang == "en":
            continue

        translated_lines = []
        print(f"Translating to '{lang}' ...")
        for line in output_en:
            if line.startswith("#") or not line.strip():
                translated_lines.append(line)
            elif line.startswith('"$$$/'):
                try:
                    key, value = line.strip('"').split("=", 1)
                    translated_value = translate_text(value, lang)
                    translated_lines.append(format_translation(key, translated_value))
                except Exception as e:
                    print(f"Error translating line '{line}': {e}")
                    translated_lines.append(line)
            else:
                translated_lines.append(line)

        output_path = os.path.join(PLUGIN_DIR, f"TranslatedStrings_{lang}.txt")
        print(f"Writing {output_path}")
        with open(output_path, "w", encoding="utf-8") as f:
            f.write("\n".join(translated_lines))

    print("\n✅ Translation generation complete!")

# --- Entry point -------------------------------------------------------------
if __name__ == "__main__":
    # Get target languages from command-line arguments
    # Example: python3 translation.py fr de it
    languages = sys.argv[1:] or []
    if not languages:
        print("No languages specified. Generating English file only.")
    else:
        print(f"Target languages: {', '.join(languages)}")

    process_scripts(["en"] + languages)

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
-------------------------------------------------------------------------------
Script Name: extract_lightroom_translations.py
Author: Philippe's Python Helper (GPT-5)
-------------------------------------------------------------------------------
Functional Description:
This script scans all `.lua` files in the current working directory to extract
Lightroom-style translation strings of the form:

    $$$/namespace/key=Translated Text

For example:
    $$$/iNat/PluginName=Identification iNaturalist

The script performs the following actions:
1. Prompts the user to select a language code (e.g., fr, en, es).
2. Iterates through all `.lua` files in the current directory.
3. Uses a regular expression to find lines that match the Lightroom translation pattern.
4. Groups translations by their source `.lua` file, adding a section header as a comment:
       # ===== filename.lua =====
5. Tracks already-seen translation keys to avoid duplicates:
   - The first occurrence of a key is written as-is.
   - Subsequent occurrences of the same key are commented out and annotated
     with a note indicating where the key was first found.
6. Generates a single output file named:
       TranslatedStrings_<lang>.txt
   where <lang> is the chosen language code.

This script is useful when:
- You have multiple Lightroom plugin Lua scripts and want to centralize
  all translation strings into one file.
- You need to ensure there are no duplicate translation keys.
- You want to preserve the origin of each translation for reference.

-------------------------------------------------------------------------------
Usage:
1. Place this script in the same directory as your `.lua` files.
2. Open a terminal and run:
       python3 extract_lightroom_translations.py
3. When prompted, enter the language code (e.g., fr, en, es).
4. The script will produce a file:
       TranslatedStrings_<lang>.txt

Notes:
- The script assumes UTF-8 encoding for reading `.lua` files.
- Non-matching lines in `.lua` files are ignored.
- Duplicates are commented out, not removed, to preserve context.

-------------------------------------------------------------------------------
"""

import os
import re

# Ask for language code
lang = input("Enter language code (e.g., fr, en, es): ").strip().lower()
if not lang:
    print("No language code provided. Exiting.")
    exit(1)

# Regular expression to detect Lightroom translation strings
pattern = re.compile(r'(\$\$\$/[^\s=]+)=(.+)')

output_file = f"TranslatedStrings_{lang}.txt"
found_strings = {}  # key = identifier (e.g., "$$$/iNat/PluginName"), value = (text, source file)

lines_out = []

# Scan all .lua files in the current directory
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
                        # Duplicate: comment it out
                        lines_out.append(f"# {key}={value}  # duplicate of {found_strings[key][1]}\n")
        lines_out.append("\n")

# Write final output file
with open(output_file, "w", encoding="utf-8") as out:
    out.writelines(lines_out)

print(f"File '{output_file}' generated successfully.")

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
-------------------------------------------------------------------------------
Script Name: extract_lightroom_translations.py
Author: Philippe's Python Helper (GPT-5)
-------------------------------------------------------------------------------
Functional Description:
This script scans all `.lua` files in its current working directory to extract
Lightroom-style translation strings embedded in LOC() calls, such as:

    LOC("$$$/namespace/key=Translated Text")

For example:
    LOC("$$$/iNat/Bezel/Started=Plugin started")

The script performs the following actions:
1. Iterates through all `.lua` files in the current directory.
2. Uses a regular expression to find translation strings inside LOC() calls.
3. Extracts the key and value from each match.
4. Formats each translation line as:
       "$$$/namespace/key=Translated Text"
   with straight double quotes surrounding the entire line.
5. Groups translations by their source `.lua` file, adding a section header:
       # filename.lua
6. Tracks already-seen translation lines to avoid duplication:
   - The first occurrence of a line is written normally.
   - Subsequent occurrences of the same line are commented out with a `#`.
7. Generates a single output file named:
       TranslatedStrings_en.txt

This script is useful when:
- You want to centralize all Lightroom translation strings from multiple Lua scripts.
- You need to detect and annotate duplicate translation keys across files.
- You prefer a clean, structured output grouped by source file.

-------------------------------------------------------------------------------
Usage:
1. Place this script in the same directory as your `.lua` files.
2. Open a terminal and run:
       python3 extract_lightroom_translations.py
3. The script will produce a file:
       TranslatedStrings_en.txt

Notes:
- The script assumes UTF-8 encoding for reading `.lua` files.
- Only LOC()-style translation strings are extracted.
- Duplicates are commented out, not removed, to preserve context.
- The output file is overwritten each time the script runs.

-------------------------------------------------------------------------------
"""

import os
import re

def extract_lightroom_strings(text):
    # Capture translation strings inside LOC("$$$/key=value")
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
                output_lines.append('')  # Blank line between blocks

    # Write final output file
    with open(output_path, "w", encoding="utf-8") as f:
        f.write('\n'.join(output_lines))

# 🔧 Run in current working directory
output_file = "TranslatedStrings_en.txt"
process_scripts_in_current_directory(output_file)

print(f"File '{output_file}' generated successfully.")

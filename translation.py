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

def extract_loc_strings(text):
    """
    Extract LOC strings handling multi-line concatenations with ..
    Properly handles LOC("$$/key=value") pattern
    """
    results = []
    
    pos = 0
    while pos < len(text):
        # Look for LOC( followed by "
        loc_match = re.search(r'LOC\s*\(\s*"', text[pos:])
        if not loc_match:
            break
        
        # Move to position RIGHT AFTER the opening quote
        after_quote = pos + loc_match.end()
        
        # Now check if we have $$/key= right after the quote
        lookahead = text[after_quote:after_quote+500]
        key_match = re.match(r'(\$\$\$/[^=]+)=', lookahead)
        
        if not key_match:
            # Not a translation string, move on
            pos = after_quote
            continue
        
        # Found a valid LOC with key
        key = key_match.group(1).strip()
        
        # The value starts right after the = sign
        value_start = after_quote + key_match.end()
        
        # Extract the complete value (handling multi-line and concatenations)
        value, next_pos = extract_complete_value(text, value_start, key)
        
        if value:
            results.append((key, value))
            pos = next_pos if next_pos > value_start else value_start + 1
        else:
            pos = value_start + 1
    
    return results


def extract_complete_value(text, start_pos, key=""):
    """
    Extract a complete LOC value starting from position after the '=' sign.
    The value is already inside the opened quote from LOC("$$/key=VALUE")
    Reads until closing quote, then checks for .. concatenation or end of LOC.
    """
    value_parts = []
    pos = start_pos
    debug = "SpeciesGuessInfo" in key
    should_stop = False  # Flag to stop both loops
    
    if debug:
        print(f"\n  📍 Starting extraction at position {pos}")
    
    # Read characters until we hit the closing quote
    chars = []
    iteration = 0
    while pos < len(text) and not should_stop:
        iteration += 1
        if debug and iteration <= 10:
            print(f"    Iter {iteration}: pos={pos}, char='{text[pos] if pos < len(text) else 'EOF'}'")
        
        # Check flag at start of each iteration
        if should_stop:
            if debug:
                print(f"    should_stop flag detected, breaking")
            break
        
        char = text[pos]
        
        # Handle escape sequences
        if char == '\\' and pos + 1 < len(text):
            next_char = text[pos + 1]
            if next_char == 'n':
                chars.append('\n')
                pos += 2
                continue
            elif next_char == 't':
                chars.append('\t')
                pos += 2
                continue
            elif next_char == '"':
                chars.append('"')
                pos += 2
                continue
            elif next_char == '\\':
                chars.append('\\')
                pos += 2
                continue
            else:
                chars.append(char)
                pos += 1
                continue
        
        # Closing quote - this is the end of the current string part
        if char == '"':
            # Save what we have so far
            if chars:
                value_parts.append(''.join(chars))
                chars = []
            
            pos += 1  # Skip the closing quote
            
            # Now look ahead: skip whitespace and check what's next
            while pos < len(text) and text[pos] in ' \t\n\r':
                pos += 1
            
            if pos >= len(text):
                break
            
            # Check for end of LOC parameters FIRST (before checking concatenation)
            if text[pos] in ',)':
                break
            
            # Check for concatenation operator ..
            if pos + 1 < len(text) and text[pos:pos+2] == '..':
                
                pos += 2
                
                # Skip whitespace after ..
                while pos < len(text) and text[pos] in ' \t\n\r':
                    pos += 1
                
                if pos >= len(text):
                    break
                
                next_char = text[pos]
                
                # Check if next is a quoted string
                if next_char == '"':
                    pos += 1  # Skip opening quote of next part
                    continue  # Continue reading
                elif next_char == "'":
                    # Single-quoted string in Lua
                    pos += 1
                    # Read until closing single quote
                    single_chars = []
                    while pos < len(text):
                        if text[pos] == '\\' and pos + 1 < len(text):
                            # Handle escapes
                            if text[pos + 1] == "'":
                                single_chars.append("'")
                                pos += 2
                                continue
                            elif text[pos + 1] == 'n':
                                single_chars.append('\n')
                                pos += 2
                                continue
                        if text[pos] == "'":
                            pos += 1
                            if single_chars:
                                part = ''.join(single_chars)
                                value_parts.append(part)
                                single_chars = []
                            # After single quote, check for more concatenation
                            while pos < len(text) and text[pos] in ' \t\n\r':
                                pos += 1
                            
                            # CRITICAL: Check for end markers FIRST
                            if pos < len(text) and text[pos] in ',)':
                                # This is the end of the LOC string value
                                should_stop = True
                                break
                            
                            if pos + 1 < len(text) and text[pos:pos+2] == '..':
                                pos += 2
                                while pos < len(text) and text[pos] in ' \t\n\r':
                                    pos += 1
                                if pos < len(text):
                                    next_after_concat = text[pos]
                                    if next_after_concat == '"':
                                        pos += 1
                                        break  # Back to main loop to read double-quoted string
                                    elif next_after_concat == "'":
                                        # Stay in this loop to read another single-quoted string
                                        pos += 1
                                        single_chars = []
                                        continue
                            # No more concat after single quote, stop
                            break
                        single_chars.append(text[pos])
                        pos += 1
                    # After exiting single-quote loop, check if we should stop
                    if should_stop:
                        break  # Exit the main loop too
                    # Otherwise continue to read more in main loop
                    continue
                else:
                    # Concatenation with variable/expression, stop here
                    break
            else:
                # No more concatenation, end of value
                break
        else:
            # Regular character
            chars.append(char)
            pos += 1
    
    # Don't forget remaining chars
    if chars:
        value_parts.append(''.join(chars))
    
    # Join all parts and clean
    if value_parts:
        value = ''.join(value_parts)
        value = clean_value(value)
        return value, pos
    
    return None, pos


def clean_value(value):
    """
    Clean extracted value:
    - Replace Lua placeholders ^1, ^2 with {1}, {2}
    - Normalize whitespace (but preserve intentional newlines)
    """
    # Replace ^N with {N}
    value = re.sub(r'\^(\d+)', r'{\1}', value)
    
    # Split by newlines to handle each line
    lines = value.split('\n')
    cleaned_lines = []
    
    for line in lines:
        # Collapse multiple spaces/tabs to single space
        line = re.sub(r'[ \t]+', ' ', line)
        line = line.strip()
        if line:
            cleaned_lines.append(line)
    
    # Join lines
    if len(cleaned_lines) > 1:
        # Multiple lines: join with literal \n\n string
        result = '\\n\\n'.join(cleaned_lines)
    elif len(cleaned_lines) == 1:
        result = cleaned_lines[0]
    else:
        result = ''
    
    return result


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
    
    seen_translations = {}
    translations_by_file = {}
    
    lua_files = [f for f in os.listdir(current_dir) if f.lower().endswith(".lua")]
    print(f"Found {len(lua_files)} .lua files\n")
    
    # Process all files
    for filename in sorted(lua_files):
        path = os.path.join(current_dir, filename)
        
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
            
            matches = extract_loc_strings(content)
            
            if matches:
                translations_by_file[filename] = matches
                print(f"  📄 {filename}: {len(matches)} strings extracted")
                    
        except Exception as e:
            print(f"  ⚠️  Error reading {filename}: {e}")
    
    if not translations_by_file:
        print("\n⚠️  No translation strings found.")
        return
    
    # Generate output file
    output_path = os.path.join(current_dir, "TranslatedStrings_en.txt")
    output_lines = []
    
    for filename, translations in translations_by_file.items():
        output_lines.append(f"# {filename}")
        
        for key, value in translations:
            line = format_translation(key, value)
            
            if key in seen_translations:
                if seen_translations[key] == value:
                    output_lines.append(f"# DUPLICATE: {line}")
                else:
                    output_lines.append(f"# CONFLICT: {line}")
                    output_lines.append(f"# PREVIOUS: \"{key}={seen_translations[key]}\"")
            else:
                output_lines.append(line)
                seen_translations[key] = value
        
        output_lines.append("")
    
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(output_lines))
    
    print(f"\n✅ File generated: {output_path}")
    print(f"📊 Total unique translations: {len(seen_translations)}")
    
    # Show some examples
    print("\n📋 Sample extractions:")
    for i, (k, v) in enumerate(list(seen_translations.items())[:5]):
        value_display = v[:80] + '...' if len(v) > 80 else v
        print(f"   {i+1}. {k}")
        print(f"      = {value_display}")


# ---------------------------------------------------------------------------
# 3. Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    process_lua_files()
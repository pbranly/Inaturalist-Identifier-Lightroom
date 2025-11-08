#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
-------------------------------------------------------------------------------
Script Name: fix_lua_style.py
-------------------------------------------------------------------------------
Description:
Corrige automatiquement les erreurs de style Lua détectées par stylua :
- Convertit import "module" en import("module")
- Remplace les espaces par des tabulations pour l'indentation
- Ajoute des parenthèses aux appels de fonction avec tables
- Ajoute des virgules finales dans les tables
-------------------------------------------------------------------------------
"""

import os
import re
from pathlib import Path


def fix_import_syntax(content):
    """
    Convertit import "module" en import("module")
    """
    # Pattern pour capturer import suivi d'une chaîne entre guillemets
    pattern = r'import\s+"([^"]+)"'
    replacement = r'import("\1")'
    return re.sub(pattern, replacement, content)


def fix_indentation(content):
    """
    Remplace les espaces d'indentation par des tabulations
    Détecte automatiquement le niveau d'indentation (2 ou 4 espaces)
    """
    lines = content.split('\n')
    fixed_lines = []
    
    for line in lines:
        # Compter les espaces au début de la ligne
        leading_spaces = len(line) - len(line.lstrip(' '))
        
        if leading_spaces > 0:
            # Détecter si l'indentation est par 2 ou 4 espaces
            if leading_spaces % 4 == 0:
                tabs = leading_spaces // 4
            elif leading_spaces % 2 == 0:
                tabs = leading_spaces // 2
            else:
                # Garder tel quel si l'indentation est bizarre
                fixed_lines.append(line)
                continue
            
            # Remplacer les espaces par des tabulations
            fixed_line = '\t' * tabs + line.lstrip(' ')
            fixed_lines.append(fixed_line)
        else:
            fixed_lines.append(line)
    
    return '\n'.join(fixed_lines)


def fix_function_call_braces(content):
    """
    Ajoute des parenthèses aux appels de fonction avec tables
    Exemples:
    - f:checkbox { ... } -> f:checkbox({ ... })
    - LrDialogs.message "text" -> LrDialogs.message("text")
    """
    # Pour les appels avec des tables { }
    # Pattern: identifiant suivi de { sans parenthèses
    pattern1 = r'(\w+(?:\.\w+|\:\w+)*)\s*(\{)'
    
    def replace_table_call(match):
        func = match.group(1)
        brace = match.group(2)
        # Ne pas modifier les cas où c'est déjà entre parenthèses
        # ou si c'est une définition de table simple (= {)
        return f'{func}({brace}'
    
    # Appliquer le remplacement ligne par ligne pour éviter les faux positifs
    lines = content.split('\n')
    fixed_lines = []
    
    for line in lines:
        # Ignorer les lignes avec des assignations de tables
        if '=' in line and '{' in line:
            # Vérifier si c'est une assignation simple
            if re.search(r'\w+\s*=\s*\{', line):
                fixed_lines.append(line)
                continue
        
        # Remplacer uniquement si c'est un appel de fonction
        if re.search(r'(\w+(?:\.\w+|\:\w+)+)\s*\{', line):
            line = re.sub(r'(\w+(?:\.\w+|\:\w+)+)\s*(\{)', r'\1({\2', line)
        
        fixed_lines.append(line)
    
    return '\n'.join(fixed_lines)


def fix_trailing_commas(content):
    """
    Ajoute des virgules finales dans les tables et les listes
    """
    lines = content.split('\n')
    fixed_lines = []
    
    for i, line in enumerate(lines):
        stripped = line.rstrip()
        
        # Si la ligne suivante contient } ou ) et que la ligne actuelle
        # se termine par un identifiant ou une valeur sans virgule
        if i < len(lines) - 1:
            next_line = lines[i + 1].strip()
            
            # Vérifier si la ligne suivante ferme une structure
            if next_line.startswith('}') or next_line.startswith(')'):
                # Vérifier si la ligne actuelle devrait avoir une virgule
                if stripped and not stripped.endswith(',') and not stripped.endswith('{') \
                   and not stripped.endswith('(') and not stripped.endswith('['):
                    # Ajouter une virgule si ce n'est pas un commentaire
                    if not stripped.strip().startswith('--'):
                        # Vérifier que ce n'est pas déjà une ligne de fermeture
                        if not stripped.endswith('}') and not stripped.endswith(')'):
                            stripped += ','
        
        fixed_lines.append(stripped if stripped else line)
    
    return '\n'.join(fixed_lines)


def fix_string_quotes(content):
    """
    Convertit les guillemets simples en guillemets doubles pour les chaînes
    (sauf dans les commentaires et cas spéciaux)
    """
    # Pour l'instant, on garde les guillemets simples car c'est plus complexe
    # à gérer correctement sans parser complet
    return content


def process_lua_file(filepath):
    """
    Traite un fichier Lua et applique toutes les corrections de style
    """
    print(f"Traitement de {filepath}...")
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Appliquer toutes les corrections
        content = fix_import_syntax(content)
        content = fix_indentation(content)
        content = fix_function_call_braces(content)
        content = fix_trailing_commas(content)
        
        # Sauvegarder seulement si des modifications ont été faites
        if content != original_content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"  ✅ Corrigé")
            return True
        else:
            print(f"  ℹ️  Aucune modification nécessaire")
            return False
            
    except Exception as e:
        print(f"  ❌ Erreur: {e}")
        return False


def main():
    """
    Parcourt tous les fichiers .lua dans le répertoire courant et ses sous-répertoires
    """
    current_dir = Path.cwd()
    print(f"🔍 Recherche de fichiers .lua dans: {current_dir}\n")
    
    lua_files = list(current_dir.rglob("*.lua"))
    
    if not lua_files:
        print("❌ Aucun fichier .lua trouvé")
        return
    
    print(f"📝 {len(lua_files)} fichiers .lua trouvés\n")
    
    fixed_count = 0
    for lua_file in sorted(lua_files):
        if process_lua_file(lua_file):
            fixed_count += 1
    
    print(f"\n✅ Terminé! {fixed_count}/{len(lua_files)} fichiers modifiés")


if __name__ == "__main__":
    main()
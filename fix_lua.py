#!/usr/bin/env python3
"""
Script de correction automatique avec StyLua
Corrige tous les fichiers .lua du répertoire courant (récursivement)
Affiche les modifications effectuées dans chaque fichier
"""

import subprocess
import sys
import difflib
from pathlib import Path

# Codes couleurs ANSI
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
NC = '\033[0m'  # No Color

def check_stylua_installed():
    """Vérifie si StyLua est présent dans le répertoire courant"""
    stylua_path = Path('./stylua.exe')
    return stylua_path.is_file()

def find_lua_files():
    """Trouve tous les fichiers .lua dans le répertoire courant"""
    current_dir = Path('.')
    return list(current_dir.rglob('*.lua'))

def apply_stylua_and_show_changes(lua_files):
    """Applique StyLua et affiche les modifications"""
    for lua_file in lua_files:
        try:
            # Lire le contenu original avec encodage UTF-8
            with open(lua_file, 'r', encoding='utf-8') as f:
                original_content = f.readlines()
        except UnicodeDecodeError:
            print(f"{RED}Erreur d'encodage pour {lua_file}. Tentative avec un autre encodage...{NC}")
            try:
                with open(lua_file, 'r', encoding='latin1') as f:
                    original_content = f.readlines()
            except Exception as e:
                print(f"{RED}Impossible de lire {lua_file}: {e}{NC}")
                continue

        # Appliquer StyLua pour corriger le fichier
        try:
            result = subprocess.run(['.\\stylua.exe', str(lua_file)],
                                  capture_output=False,
                                  text=False)
            if result.returncode != 0:
                print(f"{RED}Erreur lors de la correction de {lua_file}{NC}")
                continue

            # Lire le contenu corrigé avec encodage UTF-8
            try:
                with open(lua_file, 'r', encoding='utf-8') as f:
                    corrected_content = f.readlines()
            except UnicodeDecodeError:
                with open(lua_file, 'r', encoding='latin1') as f:
                    corrected_content = f.readlines()

            # Comparer et afficher les différences
            diff = difflib.unified_diff(
                original_content, corrected_content,
                fromfile=str(lua_file),
                tofile=f'{lua_file} (corrigé)',
                lineterm='')

            diff_list = list(diff)
            if diff_list:
                print(f"{YELLOW}Modifications dans {lua_file}:{NC}")
                print('\n'.join(diff_list))
                print("-" * 50)

        except Exception as e:
            print(f"{RED}Erreur lors de la correction de {lua_file}: {e}{NC}")

def main():
    # Vérifier si StyLua est présent dans le répertoire courant
    if not check_stylua_installed():
        print(f"{RED}Erreur: stylua.exe n'est pas trouvé dans le répertoire courant.{NC}")
        sys.exit(1)

    print(f"{YELLOW}Recherche des fichiers .lua...{NC}")

    # Trouver tous les fichiers .lua
    lua_files = find_lua_files()
    file_count = len(lua_files)

    if file_count == 0:
        print(f"{YELLOW}Aucun fichier .lua trouvé dans le répertoire courant.{NC}")
        sys.exit(0)

    print(f"{GREEN}{file_count} fichier(s) .lua trouvé(s).{NC}")
    print(f"{YELLOW}Application de StyLua et affichage des modifications...{NC}\n")

    # Appliquer StyLua et afficher les modifications
    apply_stylua_and_show_changes(lua_files)

    print(f"\n{GREEN}✓ Correction terminée avec succès!{NC}")

if __name__ == "__main__":
    main()

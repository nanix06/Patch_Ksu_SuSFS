#!/usr/bin/env bash
# fix_sepolicy_mojito.sh
#
# Corrige l'erreur de compilation SELinux/policydb rencontrée avec le
# sepolicy.c fourni par la branche "legacy" de KernelSU-Next sur le
# noyau Mojito (4.14, avec un policydb.h déjà "post-flex_array" mais
# PAS encore au niveau de la réécriture struct selinux_policy des
# noyaux 5.19+).
#
# Historique des tentatives :
#   1. sepolicy.c de KernelSU-Next legacy -> erreurs flex_array
#      (API SELinux ~2.6.37-5.0, trop ancienne pour ce noyau)
#   2. sepolicy.c upstream HEAD de tiann/KernelSU -> erreurs
#      struct selinux_policy / filename_trans_key incomplete type
#      (API SELinux ~5.19+, trop récente pour ce noyau)
#
# Solution retenue : backslashxx/KernelSU est un fork de tiann/KernelSU
# activement maintenu pour compiler sur une large plage de noyaux
# (3.0 à 5.4+, testé notamment sur 4.14) grâce à du code conditionnel
# par version (LINUX_VERSION_CODE) dans sepolicy.c. On ne remplace QUE
# ce fichier : rules.c de la branche legacy d'origine compile déjà
# sans problème sur ce noyau, et il est la cible du patch
# susfs_hook_only_official-legacy.patch appliqué juste après cette
# étape dans le workflow -- le remplacer casse le contexte de ce
# patch (hunk appliqué avec un gros offset = fichier corrompu).
#
# Usage (dans le workflow, juste après avoir cloné KernelSU-Next et créé
# le lien symbolique drivers/kernelsu) :
#   bash fix_sepolicy_mojito.sh KernelSU

set -euo pipefail

KSU_DIR="${1:-KernelSU}"
SRC_BASE="https://raw.githubusercontent.com/backslashxx/KernelSU/master/kernel/selinux"

for f in sepolicy.c; do
  TARGET="$KSU_DIR/kernel/selinux/$f"

  if [ ! -f "$TARGET" ]; then
    echo "Attention : $TARGET introuvable, on saute ce fichier." >&2
    continue
  fi

  echo "Sauvegarde de l'ancien $f en .orig ..."
  cp "$TARGET" "$TARGET.orig"

  echo "Téléchargement de $f depuis backslashxx/KernelSU (compat multi-versions) ..."
  curl -fsSL "$SRC_BASE/$f" -o "$TARGET.new"

  if [ ! -s "$TARGET.new" ]; then
    echo "Erreur : téléchargement de $f vide ou échoué." >&2
    rm -f "$TARGET.new"
    continue
  fi

  mv "$TARGET.new" "$TARGET"
  echo "Remplacement terminé : $TARGET"
done

echo "Anciennes versions conservées en .orig à côté de chaque fichier (pour comparaison si besoin)"

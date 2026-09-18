#!/usr/bin/env bash
# fix_sepolicy_mojito.sh
#
# Corrige l'erreur de compilation :
#   error: implicit declaration of function 'flex_array_alloc'
#   error: no member named 'total_nr_elements' in 'struct ebitmap'
#   error: no member named 'type_val_to_struct_array' in 'struct policydb'
#
# Cause : drivers/kernelsu/selinux/sepolicy.c (fourni par la branche "legacy"
# de KernelSU-Next) a été écrit pour l'ancienne API SELinux basée sur
# struct flex_array (kernels ~2.6.37 -> ~5.0). Le noyau Mojito, bien
# qu'étiqueté "4.14", a déjà le policydb.h post-2019 (tableaux kvmalloc
# classiques, sans flex_array). D'où l'incompatibilité.
#
# Solution : remplacer ce fichier par la version upstream actuelle de
# tiann/KernelSU, qui utilise la même API que le policydb.h de Mojito.
#
# Usage (dans le workflow, juste après avoir cloné KernelSU-Next et créé
# le lien symbolique drivers/kernelsu) :
#   bash fix_sepolicy_mojito.sh KernelSU

set -euo pipefail

KSU_DIR="${1:-KernelSU}"
TARGET="$KSU_DIR/kernel/selinux/sepolicy.c"
UPSTREAM_URL="https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/selinux/sepolicy.c"

if [ ! -f "$TARGET" ]; then
  echo "Erreur : $TARGET introuvable. Vérifie le chemin passé en argument." >&2
  exit 1
fi

echo "Sauvegarde de l'ancien sepolicy.c (flex_array) en .orig ..."
cp "$TARGET" "$TARGET.orig"

echo "Téléchargement de la version upstream (compatible policydb sans flex_array) ..."
curl -fsSL "$UPSTREAM_URL" -o "$TARGET.new"

if ! grep -q "flex_array" "$TARGET.new"; then
  echo "OK : la nouvelle version ne référence plus flex_array."
else
  echo "Attention : le fichier téléchargé contient encore 'flex_array', vérifie manuellement." >&2
fi

mv "$TARGET.new" "$TARGET"

echo "Remplacement terminé : $TARGET"
echo "Ancienne version conservée dans : $TARGET.orig (pour comparaison si besoin)"

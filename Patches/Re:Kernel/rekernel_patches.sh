#!/usr/bin/env bash
#
# Re:Kernel - integration kbuild pour le noyau WestCoast A17 (4.14 / mojito)
#
# A lancer depuis la racine du noyau, APRES avoir applique rekernel_extra.patch :
#
#   patch -p1 < .../rekernel_extra.patch
#   bash .../rekernel_patches.sh
#
# Pourquoi ce script a ete reecrit :
#   la version d'origine cherchait la derniere ligne "endif" de
#   drivers/net/Kconfig pour inserer le "source" juste avant. Or ce noyau
#   termine ce fichier par "endif # NETDEVICES" : le sed ne trouvait rien,
#   ne modifiait rien, et le build continuait sans jamais compiler le driver.
#
# Ce script est idempotent : on peut le relancer sans creer de doublons.

set -eu

KCONFIG="drivers/net/Kconfig"
MAKEFILE="drivers/net/Makefile"
KCONFIG_LINE='source "drivers/net/rekernel/Kconfig"'
MAKEFILE_LINE='obj-$(CONFIG_REKERNEL) += rekernel/'

if [ ! -f "$KCONFIG" ] || [ ! -f "$MAKEFILE" ]; then
	echo "Re:Kernel: $KCONFIG ou $MAKEFILE introuvable, lancer depuis la racine du noyau" >&2
	exit 1
fi

if [ ! -f drivers/net/rekernel/rekernel.c ] || [ ! -f include/net/rekernel.h ]; then
	echo "Re:Kernel: fichiers du driver absents, appliquer rekernel_extra.patch d'abord" >&2
	exit 1
fi

if grep -Fq 'drivers/net/rekernel/Kconfig' "$KCONFIG"; then
	echo "Re:Kernel: $KCONFIG deja patche"
else
	printf '\n%s\n' "$KCONFIG_LINE" >> "$KCONFIG"
	echo "Re:Kernel: $KCONFIG mis a jour"
fi

if grep -Fq 'obj-$(CONFIG_REKERNEL) += rekernel/' "$MAKEFILE"; then
	echo "Re:Kernel: $MAKEFILE deja patche"
else
	printf '\n%s\n' "$MAKEFILE_LINE" >> "$MAKEFILE"
	echo "Re:Kernel: $MAKEFILE mis a jour"
fi

echo "Re:Kernel: integration kbuild terminee"

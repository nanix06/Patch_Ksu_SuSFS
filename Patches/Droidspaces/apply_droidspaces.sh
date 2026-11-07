#!/usr/bin/env bash
#
# Applique les correctifs noyau DroidSpaces sur un noyau non-GKI.
#
# A lancer depuis la racine du noyau, apres les patchs ROM / KernelSU / SuSFS :
#
#   bash patches/Patches/Droidspaces/apply_droidspaces.sh
#
# - kernel/cgroup/cgroup.c : alias des fichiers cgroup v1 prefixes (LXC/Docker)
# - net/netfilter/xt_qtaguid.c : evite un panic (ignore si le fichier est absent)
#
# Coccinelle (spatch) est utilise en priorite ; un diff unifie sert de repli si
# spatch est absent ou si le motif n'a pas ete reconnu.

set -uo pipefail

DS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KROOT="$(pwd)"

log() { printf '[DroidSpaces] %s\n' "$*"; }
die() { printf '[DroidSpaces] ERREUR: %s\n' "$*" >&2; exit 1; }

[ -f "$KROOT/kernel/cgroup/cgroup.c" ] \
	|| die "lancez ce script depuis la racine du noyau (kernel/cgroup/cgroup.c introuvable)"

# ---------------------------------------------------------------------------
# 1) kernel/cgroup/cgroup.c : noms prefixes "ss.fichier" en mode noprefix
# ---------------------------------------------------------------------------
CGROUP_C="$KROOT/kernel/cgroup/cgroup.c"
CGROUP_MARK='kernfs_create_link(cgrp->kn, name, kn)'

apply_cgroup() {
	if command -v spatch >/dev/null 2>&1; then
		log "cgroup: coccinelle sur kernel/cgroup/cgroup.c"
		spatch --sp-file "$DS_DIR/fix_restore_cgroup_file_prefix_handling.cocci" \
			--in-place --very-quiet "$CGROUP_C" || true
		grep -qF "$CGROUP_MARK" "$CGROUP_C" && return 0
		log "cgroup: coccinelle n'a rien modifie, repli sur le diff"
	else
		log "cgroup: spatch absent, repli sur le diff"
	fi

	patch -p1 --forward --fuzz=3 --no-backup-if-mismatch \
		< "$DS_DIR/02.fix_restore_cgroup_file_prefix_handling.patch" >/dev/null 2>&1 || true
	grep -qF "$CGROUP_MARK" "$CGROUP_C"
}

if grep -qF "$CGROUP_MARK" "$CGROUP_C"; then
	log "cgroup: deja applique"
else
	apply_cgroup || die "cgroup: correctif non applique (motif cgroup_add_file introuvable, noyau different ?)"
	log "cgroup: OK"
fi

# ---------------------------------------------------------------------------
# 2) net/netfilter/xt_qtaguid.c : suppression de dev_get_stats()
# ---------------------------------------------------------------------------
QTA="$KROOT/net/netfilter/xt_qtaguid.c"
QTA_MARK='dev_get_stats(iface_entry->net_dev'

if [ ! -f "$QTA" ]; then
	log "xt_qtaguid: fichier absent de cet arbre (netd eBPF), correctif inutile"
elif ! grep -qF "$QTA_MARK" "$QTA"; then
	log "xt_qtaguid: deja corrige (ou code different), rien a faire"
else
	if command -v spatch >/dev/null 2>&1; then
		log "xt_qtaguid: coccinelle sur net/netfilter/xt_qtaguid.c"
		spatch --sp-file "$DS_DIR/fix_kernel_panic_in_xt_qtaguid.cocci" \
			--in-place --very-quiet "$QTA" || true
	fi

	if grep -qF "$QTA_MARK" "$QTA"; then
		log "xt_qtaguid: repli sur le diff"
		patch -p1 --forward --fuzz=3 --no-backup-if-mismatch \
			< "$DS_DIR/01.fix_kernel_panic_in_xt_qtaguid.patch" >/dev/null 2>&1 || true
	fi

	grep -qF "$QTA_MARK" "$QTA" \
		&& die "xt_qtaguid: correctif non applique (motif iface_stat_fmt_proc_show introuvable)"
	log "xt_qtaguid: OK"
fi

log "correctifs noyau DroidSpaces appliques"

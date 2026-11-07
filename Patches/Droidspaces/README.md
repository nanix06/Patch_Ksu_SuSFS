# Patches/Droidspaces

Correctifs noyau et fragment de configuration pour **DroidSpaces** sur le noyau
**4.14.357-openela** de `STRIX-kernel_Mojito` (branche `inline-rom`,
`vendor/mojito_defconfig`).

## Contenu

| Fichier | Rôle |
|---|---|
| `droidspaces.config` | Options noyau, validées contre les Kconfig 4.14 de cet arbre |
| `fix_restore_cgroup_file_prefix_handling.cocci` | Alias `ss.fichier` des cgroups v1 (LXC/Docker) |
| `fix_kernel_panic_in_xt_qtaguid.cocci` | Évite un panic dans `xt_qtaguid` |
| `02.fix_restore_cgroup_file_prefix_handling.patch` | Repli `patch(1)` du correctif cgroup |
| `01.fix_kernel_panic_in_xt_qtaguid.patch` | Repli `patch(1)` du correctif qtaguid |
| `apply_droidspaces.sh` | Applique les deux correctifs et vérifie le résultat |

## Utilisation dans le workflow

```yaml
- name: Ajouter DroidSpaces (patchs noyau)
  run: |
    DS=patches/Patches/Droidspaces
    bash "$DS/apply_droidspaces.sh"
```

Le script utilise `spatch` quand il est disponible, sinon le diff unifié, puis
vérifie que le code a bien été inséré. Il échoue explicitement si le noyau ne
correspond plus (plutôt que de produire un noyau sans support DroidSpaces).

Les options de `droidspaces.config` sont ajoutées à `out/.config` avant
`olddefconfig` (voir le workflow).

## Corrections apportées aux fichiers d'origine

### `fix_restore_cgroup_file_prefix_handling.cocci`

- La signature `static int cgroup_add_file(...)` est remplacée par la
  signature exacte du noyau : selon les versions de Coccinelle, `...` dans une
  liste de paramètres n'est pas accepté dans une définition de fonction.
- Les métavariables `css`, `cgrp`, `cft`, `kn` et `name` sont déclarées, pour
  que le code inséré référence bien les variables du fichier cible.
- Le bloc n'est inséré que si `CGRP_ROOT_NOPREFIX` est actif : aucun conflit
  avec le nom déjà préfixé quand `noprefix` n'est pas utilisé.
- L'insertion est faite après la création du fichier (`kn` et `name` valides).

Sur ce noyau, `cgroup_file_name()` existe déjà et gère les préfixes ; le
correctif ajoute uniquement les alias manquants pour les montages `noprefix`,
ce qui est exactement ce que cherchent LXC/DroidSpaces.

### `fix_kernel_panic_in_xt_qtaguid.cocci`

- La déclaration réelle est `struct rtnl_link_stats64 dev_stats, *stats;` :
  l'ancienne règle (`- struct rtnl_link_stats64 dev_stats;`) ne pouvait pas
  matcher. La règle réécrit maintenant la ligne complète en
  `struct rtnl_link_stats64 *stats;`.
- Le `if/else` qui appelle `dev_get_stats()` est remplacé par
  `stats = &no_dev_stats;`.
- Sur `STRIX-kernel_Mojito`, `net/netfilter/xt_qtaguid.c` n'existe pas
  (comptabilité netd eBPF) : le script l'ignore proprement.

### `droidspaces.config`

Options retirées ou renommées pour le 4.14 (sinon `olddefconfig` les supprime
silencieusement) :

| Doc DroidSpaces | 4.14 |
|---|---|
| `CONFIG_FW_LOADER_COMPRESS` | inexistant (5.3+) → retiré |
| `CONFIG_NF_CONNTRACK_NETLINK` | `CONFIG_NF_CT_NETLINK` |
| `CONFIG_NETFILTER_XT_TARGET_MASQUERADE` | `CONFIG_IP_NF_TARGET_MASQUERADE` |
| `CONFIG_NETFILTER_XT_TARGET_REJECT` | `CONFIG_IP_NF_TARGET_REJECT` + `CONFIG_IP6_NF_TARGET_REJECT` |
| `CONFIG_IP_NF_TARGET_ULOG` | supprimé de l'arbre → retiré |
| `CONFIG_ANDROID_PARANOID_NETWORK` | absent de l'arbre → retiré |

`CONFIG_MEMCG_SWAP=y` a été ajouté (présent dans la documentation DroidSpaces).
`CONFIG_CFS_BANDWIDTH` est activable : cet arbre a `CONFIG_SCHED_WALT` désactivé
et `CONFIG_SWAP=y`.

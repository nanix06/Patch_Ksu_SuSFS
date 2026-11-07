// DroidSpaces / LXC: restore the prefixed cgroup v1 file names.
//
// kernel/cgroup/cgroup.c:cgroup_add_file() creates the file under its plain
// name ("limit_in_bytes") when the hierarchy is mounted with "noprefix"
// (CGRP_ROOT_NOPREFIX). LXC / Docker / DroidSpaces still look for the
// historical prefixed name ("memory.limit_in_bytes", "cpu.cfs_quota_us",
// ...), so add a kernfs symlink for every such file.
//
// The code is added AFTER the file has been created (so "kn" and "name" are
// valid) and only when noprefix is in use, so it never collides with the
// normal, already-prefixed name.
//
// Usage (from the kernel source root):
//   spatch --in-place --sp-file fix_restore_cgroup_file_prefix_handling.cocci \
//          kernel/cgroup/cgroup.c
//
// Tested against kernel 4.14 (STRIX / mojito):
//   static int cgroup_add_file(struct cgroup_subsys_state *css,
//                              struct cgroup *cgrp, struct cftype *cft)
//
// Every metavariable used in the added code is bound in the matched code:
//   - css/cgrp/cft by the function parameters,
//   - name/kn by their declarations at the top of the function.

@ cgroup_file_prefix @
identifier css, cgrp, cft, kn, name;
@@

static int cgroup_add_file(struct cgroup_subsys_state *css, struct cgroup *cgrp,
			   struct cftype *cft)
{
	char name[CGROUP_FILE_NAME_MAX];
	struct kernfs_node *kn;
	...
	if (cft->file_offset) {
		...
	}
+
+	if (cft->ss && (cgrp->root->flags & CGRP_ROOT_NOPREFIX) &&
+	    !(cft->flags & CFTYPE_NO_PREFIX)) {
+		snprintf(name, CGROUP_FILE_NAME_MAX, "%s.%s",
+			 cft->ss->name, cft->name);
+		kernfs_create_link(cgrp->kn, name, kn);
+	}
+
	return 0;
}

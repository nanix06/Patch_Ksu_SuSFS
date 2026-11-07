// DroidSpaces / LXC: avoid a kernel panic in xt_qtaguid.
//
// iface_stat_fmt_proc_show() calls dev_get_stats() on an interface that may
// already be gone (net_dev freed), which crashes the kernel when a container
// tears down a veth while /proc/net/xt_qtaguid/iface_stat_fmt is being read.
// Report zeroed statistics instead, like the official DroidSpaces patch.
//
// NOTE: many Android 4.14 trees (including STRIX/mojito, which uses the eBPF
// netd accounting) do not ship net/netfilter/xt_qtaguid.c at all. In that
// case there is nothing to patch and the build script skips this rule.
//
// Usage (from the kernel source root, only if the file exists):
//   spatch --in-place --sp-file fix_kernel_panic_in_xt_qtaguid.cocci \
//          net/netfilter/xt_qtaguid.c

@ iface_stat_no_dev_stats @
@@

static int iface_stat_fmt_proc_show(struct seq_file *m, void *v)
{
	...
-	struct rtnl_link_stats64 dev_stats, *stats;
+	struct rtnl_link_stats64 *stats;
	...
-	if (iface_entry->active) {
-		stats = dev_get_stats(iface_entry->net_dev,
-				      &dev_stats);
-	} else {
-		stats = &no_dev_stats;
-	}
+	stats = &no_dev_stats;
	...
}

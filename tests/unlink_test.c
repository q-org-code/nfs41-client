/* Phase 4c: unlink a file and print libnfs's error text. Usage: unlink_test <server> <export> <path> */
#include <stdio.h>
#include <nfsc/libnfs.h>

int main(int argc, char **argv)
{
	struct nfs_context *nfs = nfs_init_context();
	int rc;

	if (argc != 4) return 2;
	nfs_set_version(nfs, NFS_V4_1);
	if (nfs_mount(nfs, argv[1], argv[2]) < 0) { printf("mount failed: %s\n", nfs_get_error(nfs)); return 1; }
	rc = nfs_unlink(nfs, argv[3]);
	printf("unlink rc=%d err=%s\n", rc, rc < 0 ? nfs_get_error(nfs) : "");
	nfs_destroy_context(nfs);
	return rc < 0;
}

/* Phase 2: mkdir/write/rename/stat/unlink/rmdir over NFS 4.1 on a scratch dir. */
#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <nfsc/libnfs.h>

#define CHECK(x) do { if ((x) < 0) { printf("FAIL %s: %s\n", #x, nfs_get_error(nfs)); return 1; } } while (0)

int main(int argc, char **argv)
{
	struct nfs_context *nfs = nfs_init_context();
	struct nfsfh *fh;
	struct nfs_stat_64 st;
	char buf[16] = {0};

	if (argc != 3) return 2;
	nfs_set_version(nfs, NFS_V4_1);
	CHECK(nfs_mount(nfs, argv[1], argv[2]));
	CHECK(nfs_mkdir(nfs, "/p2_ops"));
	CHECK(nfs_creat(nfs, "/p2_ops/a", 0644, &fh));
	CHECK(nfs_write(nfs, fh, "hello", 5));
	CHECK(nfs_close(nfs, fh));
	CHECK(nfs_rename(nfs, "/p2_ops/a", "/p2_ops/b"));
	CHECK(nfs_stat64(nfs, "/p2_ops/b", &st));
	CHECK(nfs_open(nfs, "/p2_ops/b", O_RDONLY, &fh));
	CHECK(nfs_read(nfs, fh, buf, 15));
	CHECK(nfs_close(nfs, fh));
	printf("size=%d content=%s\n", (int)st.nfs_size, buf);
	if (nfs_stat64(nfs, "/p2_ops/a", &st) == 0) { printf("FAIL old name still exists\n"); return 1; }
	CHECK(nfs_unlink(nfs, "/p2_ops/b"));
	CHECK(nfs_rmdir(nfs, "/p2_ops"));
	printf("OK\n");
	nfs_destroy_context(nfs);
	return 0;
}

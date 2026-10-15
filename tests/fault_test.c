/* Phase 4 helper: stat+read a file once a second over NFS 4.1 and log rc, time and libnfs error.
 * usage: fault_test <url-with-options> <path> <seconds> */
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <fcntl.h>
#include <unistd.h>
#include <nfsc/libnfs.h>

int main(int argc, char **argv)
{
	struct nfs_context *nfs = nfs_init_context();
	struct nfs_url *url;
	char buf[4096];
	int n;

	if (argc != 4 || !(url = nfs_parse_url_dir(nfs, argv[1]))) return 2;
	if (nfs_mount(nfs, url->server, url->path) < 0) { printf("mount: %s\n", nfs_get_error(nfs)); return 1; }
	for (n = atoi(argv[3]); n > 0; n--) {
		struct nfsfh *fh; time_t s = time(NULL); int rc = nfs_open(nfs, argv[2], O_RDONLY, &fh);
		if (rc == 0) { rc = nfs_read(nfs, fh, buf, sizeof(buf)); nfs_close(nfs, fh); }
		printf("%ld rc=%d dur=%lds %s\n", (long)s, rc, (long)(time(NULL) - s), rc < 0 ? nfs_get_error(nfs) : "");
		fflush(stdout); sleep(1);
	}
	return 0;
}

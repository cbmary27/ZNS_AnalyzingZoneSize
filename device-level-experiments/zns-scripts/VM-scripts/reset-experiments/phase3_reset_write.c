#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include <nvme/ioctl.h>
#include <nvme/types.h>

static long diff_us(struct timespec a, struct timespec b) {
    return (b.tv_sec - a.tv_sec) * 1000000L +
           (b.tv_nsec - a.tv_nsec) / 1000L;
}

static int reset_zone_with_libnvme(int fd, __u32 nsid, __u64 slba) {
    struct nvme_zns_mgmt_send_args args = {
        .slba = slba,
        .result = NULL,
        .data = NULL,
        .args_size = sizeof(struct nvme_zns_mgmt_send_args),
        .fd = fd,
        .timeout = 0,
        .nsid = nsid,
        .zsa = NVME_ZNS_ZSA_RESET,
        .data_len = 0,
        .select_all = false,
        .zsaso = 0,
    };

    return nvme_zns_mgmt_send(&args);
}

int main(int argc, char *argv[]) {
    if (argc != 7) {
        fprintf(stderr,
                "Usage: %s <device> <zone_size_bytes> <target_zone> <write_size> <mode> <output_file>\n",
                argv[0]);
        fprintf(stderr,
                "Example: %s /dev/nvme0n1 67108864 13 4096 fresh_reset out.txt\n",
                argv[0]);
        return 1;
    }

    const char *dev = argv[1];
    long long zone_size = atoll(argv[2]);
    long long target_zone = atoll(argv[3]);
    size_t write_size = (size_t)atoll(argv[4]);
    const char *mode = argv[5];
    const char *outfile = argv[6];

    if (zone_size <= 0 || target_zone < 0 || write_size == 0) {
        fprintf(stderr, "Invalid numeric argument.\n");
        return 1;
    }

    off_t offset = (off_t)(target_zone * zone_size);
    __u64 slba = (__u64)(offset / 512);   // device uses 512-byte LBAs in your setup

    int fd = open(dev, O_WRONLY | O_DIRECT);
    if (fd < 0) {
        perror("open");
        return 1;
    }

    __u32 nsid = 0;
    if (nvme_get_nsid(fd, &nsid) < 0) {
        perror("nvme_get_nsid");
        close(fd);
        return 1;
    }

    void *buf = NULL;
if (posix_memalign(&buf, 4096, write_size) != 0) {
    perror("posix_memalign");
    close(fd);
    return 1;
}
memset(buf, 'A', write_size);

struct timespec t1, t2;
if (clock_gettime(CLOCK_MONOTONIC_RAW, &t1) != 0) {
    perror("clock_gettime start");
    free(buf);
    close(fd);
    return 1;
}

int rc = reset_zone_with_libnvme(fd, nsid, slba);
if (rc < 0) {
    perror("nvme_zns_mgmt_send(reset)");
    free(buf);
    close(fd);
    return 1;
}

ssize_t written = pwrite(fd, buf, write_size, offset);

if (clock_gettime(CLOCK_MONOTONIC_RAW, &t2) != 0) {
    perror("clock_gettime end");
    free(buf);
    close(fd);
    return 1;
}

    if (written < 0) {
        perror("pwrite");
        free(buf);
        close(fd);
        return 1;
    }

    if ((size_t)written != write_size) {
        fprintf(stderr, "Short write: expected %zu, got %zd\n", write_size, written);
        free(buf);
        close(fd);
        return 1;
    }

    long latency_us = diff_us(t1, t2);

    FILE *fp = fopen(outfile, "w");
    if (!fp) {
        perror("fopen");
        free(buf);
        close(fd);
        return 1;
    }

    fprintf(fp, "device=%s\n", dev);
    fprintf(fp, "nsid=%u\n", nsid);
    fprintf(fp, "zone_size=%lld\n", zone_size);
    fprintf(fp, "target_zone=%lld\n", target_zone);
    fprintf(fp, "target_offset=%lld\n", (long long)offset);
    fprintf(fp, "target_slba=%llu\n", (unsigned long long)slba);
    fprintf(fp, "write_size=%zu\n", write_size);
    fprintf(fp, "mode=%s\n", mode);
    fprintf(fp, "reset_plus_write_latency_us=%ld\n", latency_us);
    fclose(fp);

    //printf("mode=%s latency_us=%ld\n", mode, latency_us);
    printf("mode=%s reset_plus_write_latency_us=%ld\n", mode, latency_us);
    free(buf);
    close(fd);
    return 0;
}

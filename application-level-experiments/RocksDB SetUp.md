# RocksDB + ZenFS Installation Guide

A step-by-step guide for building RocksDB with the ZenFS plugin on a zoned block device (e.g., NVMe ZNS).

**Reference:** [ZenFS README](https://github.com/westerndigitalcorporation/zenfs/blob/master/README.md)

---

## Prerequisites

- GCC 11.2.0 (installed below)
- A zoned block device (e.g., `nvme0n1`)
- Ubuntu/Debian-based system

---

## 1. Set Up GCC 11

Update packages and install GCC/G++ 11:

```bash
sudo apt update
sudo apt install gcc-11 g++-11
```

Set GCC 11 as the default compiler by adding the following to `~/.bashrc`:

```bash
nano ~/.bashrc
```

Append these lines:

```bash
export CXX=g++-11
export CC=gcc-11
```

Apply the changes and verify:

```bash
source ~/.bashrc
echo $CXX   # Should output: g++-11
```

---

## 2. Install libzbd Dependencies

```bash
sudo apt update
sudo apt install m4 autoconf automake libtool libgtk-3-dev
```

> **Note:** RPM packages are not required on Debian/Ubuntu — skip any `.rpm`-specific steps.

---

## 3. Install RocksDB Build Dependencies

```bash
sudo apt update
sudo apt install -y \
  libgflags-dev \
  libsnappy-dev \
  zlib1g-dev \
  libbz2-dev \
  liblz4-dev \
  libzstd-dev \
  libjemalloc-dev
```

---

## 4. Build RocksDB with ZenFS Plugin

Run the build from the root of your RocksDB source directory.

**Full parallel build (auto-detect cores):**

```bash
DEBUG_LEVEL=0 ROCKSDB_PLUGINS=zenfs \
CXXFLAGS="$CXXFLAGS -Wno-error=unused-parameter" \
make -j$(nproc) db_bench install \
PREFIX=/home/femu/rocksdbTest/rocksdbInstall \
EXTRA_LDFLAGS="-lgflags -lsnappy -lz -lbz2 -llz4 -lzstd -ljemalloc"
```

**Fixed 8-core build (if `nproc` causes issues):**

```bash
DEBUG_LEVEL=0 ROCKSDB_PLUGINS=zenfs \
CXXFLAGS="$CXXFLAGS -Wno-error=unused-parameter" \
make -j8 db_bench install \
PREFIX=/home/femu/rocksdbTest/rocksdbInstall \
EXTRA_LDFLAGS="-lgflags -lsnappy -lz -lbz2 -llz4 -lzstd -ljemalloc"
```

> **Alternative install path** (if using `/home/femu/RocksDBFile/rocksdb-install`):
> Replace `PREFIX=/home/femu/rocksdbTest/rocksdbInstall` accordingly.

---

## 5. Configure PKG_CONFIG_PATH

So that other tools can find the installed RocksDB libraries:

```bash
export PKG_CONFIG_PATH=/home/femu/rocksdbTest/rocksdbInstall/lib/pkgconfig:$PKG_CONFIG_PATH
```

> Add this line to `~/.bashrc` to make it persistent across sessions.

---

## 6. Build the ZenFS Utility

Navigate to the ZenFS utility directory and build:

```bash
cd plugin/zenfs/util
make
```

---

## 7. Initialize the ZenFS Filesystem

### Set the I/O Scheduler (Required after every reboot)

```bash
echo mq-deadline | sudo tee /sys/class/block/nvme0n1/queue/scheduler
```

> **Important:** This must be run after every reboot before using ZenFS.

### Format the Zoned Block Device

```bash
sudo ./plugin/zenfs/util/zenfs mkfs \
  --zbd=nvme0n1 \
  --aux_path=/home/femu/rocksdbTest/zenfs_aux \
  --force
```

> ⚠️ The `--force` flag will **overwrite** any existing ZenFS filesystem on the device. Use with caution.

---

## Quick Reference: Post-Reboot Checklist

Every time the machine reboots, run the following before using ZenFS:

```bash
# 1. Re-export environment variables (if not in ~/.bashrc)
export CXX=g++-11
export CC=gcc-11
export PKG_CONFIG_PATH=/home/femu/rocksdbTest/rocksdbInstall/lib/pkgconfig:$PKG_CONFIG_PATH

# 2. Set the I/O scheduler for the ZNS device
echo mq-deadline | sudo tee /sys/class/block/nvme0n1/queue/scheduler
```

---

## Directory Structure

| Path | Purpose |
|------|---------|
| `/home/femu/rocksdbTest/rocksdbInstall` | RocksDB install prefix |
| `/home/femu/rocksdbTest/zenfs_aux` | ZenFS auxiliary metadata path |
| `/home/femu/RocksDBFile/rocksdb-install` | Alternative install path (legacy) |
| `plugin/zenfs/util/` | ZenFS CLI utility source |

---

## Troubleshooting

**Build fails with compiler errors**
Ensure `$CXX` and `$CC` are set correctly: `echo $CXX` should return `g++-11`.

**Missing library errors during `make`**
Re-run Step 3 to confirm all `-dev` packages are installed.

**ZenFS `mkfs` fails**
Confirm the I/O scheduler is set to `mq-deadline` (Step 7) and the device path (`nvme0n1`) is correct for your system.

**`pkg-config` can't find RocksDB**
Verify `PKG_CONFIG_PATH` includes the correct path and that the install step in Step 4 completed without errors.

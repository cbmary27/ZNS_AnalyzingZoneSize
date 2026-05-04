# ZNS Application-Level Experiments

This folder contains the scripts, results, and plotting code used to evaluate ZNS SSD behavior under different device configurations with RocksDB + ZenFS.

## IMPORTANT SETUP NOTE

1. For Installing RocksDB: [RocksDB](https://github.com/cbmary27/RocksDB-ZenFS/blob/main/README.md)
2. For Installing KVBench: 

A custom `zns.c` file is included in this repository.

### Location in repo:
```
zns.c
```

### Where to place it in FEMU:
```
confznsplusplus/hw/femu/zns/zns.c
```

### What to do:
Replace the existing file in FEMU:

```bash
cp zns.c ~/confznsplusplus/hw/femu/zns/zns.c
```

### Then rebuild FEMU:

```bash
cd ~/confznsplusplus
make clean
make -j
```

## Zone Configurations

Use the run-zns-exp.sh and pass the parameters as below:

FORMAT: ./run-zns-exp.sh zone_size channels_per_zone ways_per_zone

eg.  
```bash
./run-zns-exp.sh 64 8 1
```

## Overview

Measuring the impact of FINISH operation for varying occupancy thresholds on 1. Write Amplification 2. Space Amplification 3. Latency and Bandwidth

## EXPERIMENT 1: Write Amplification w.r.t Dummy Pages

### Run (inside VM)

```bash
cd kv-bench/kv-bench-rocksdb-example
```

```bash
./test_ft_page.sh
```

### Output

Fill in the desired occupancy threshold to test in the test_ft_page, then go to the 'log' file in the build-femu folder on SCC to obtain the pages to write value (sum, average)

## EXPERIMENT 2: Space Amplification w.r.t Invalid Data

### Run (Inside VM)

```bash
cd kv-bench/kv-bench-rocksdb-example
./test_ft_kv.sh
```
### Output

To get the log files generated from ZenFS:

```bash
scp -P 8080 femu@localhost:/tmp/zenfs_* <SCC or Local System folder path>
```
The last "Cumulative Average Garbage Bytes" in the log files contains the average garbage bytes over the intervals

## EXPERIMENT 3: Latency and Bandwidth





   
## NOTE

All experiments assume:
- FEMU configured correctly
- zns.c replaced before build
- VM running corresponding configuration

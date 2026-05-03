#!/bin/bash

AUX_PATH="/home/femu/rocksdbTest/zenfs_aux"
FS_URI="zenfs://dev:nvme0n1"

#to measure total garbage bytes

THRESHOLDS=0

sudo nvme zns reset-zone /dev/nvme0n1

    echo " Running benchmark for finish_threshold=100"

    sudo rm -rf "${AUX_PATH:?}"/*

    echo mq-deadline | sudo tee /sys/class/block/nvme0n1/queue/scheduler

    sudo /home/femu/rocksdbTest/rocksdb/plugin/zenfs/util/zenfs mkfs --zbd=nvme0n1 --aux_path="$AUX_PATH" --force --finish_threshold=0

    sudo ./plain_benchmark -E 1024 --dd \
  --iwp /home/femu/rocksdbTest/kv-bench/K-V-Workload-Generator/workload.txt \
  --qwp /home/femu/rocksdbTest/kv-bench/K-V-Workload-Generator/kvbench2_1k_4M.txt \
  --dw --dr --fs_uri=${FS_URI}  

     sudo nvme zns reset-zone /dev/nvme0n1 -a

     #sudo nvme zns report-zones /dev/nvme0n1

      echo "Finished benchmark for finish_threshold=10"

echo "All benchmarks completed."

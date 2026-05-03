#!/bin/bash

AUX_PATH="/home/femu/rocksdbTest/zenfs_aux"
DB_BENCH="./db_bench"
FS_URI="zenfs://dev:nvme0n1"

#to measure total garbage bytes

THRESHOLDS=$(seq 0 10 100)

echo " Running benchmark for finish_threshold=50"

sudo rm -rf "${AUX_PATH:?}"/*

echo mq-deadline | sudo tee /sys/class/block/nvme0n1/queue/scheduler

sudo ./plugin/zenfs/util/zenfs mkfs --zbd=nvme0n1 --aux_path="$AUX_PATH" --force --finish_threshold=50

sudo $DB_BENCH \
--fs_uri="$FS_URI" \
--benchmarks=fillrandom \
--use_direct_reads \
--key_size=16 \
--value_size=800 \
--target_file_size_base=33554432 \
--use_direct_io_for_flush_and_compaction \
--max_bytes_for_level_multiplier=4 \
--write_buffer_size=16777216 \
--target_file_size_multiplier=1 \
--num=1000000 \
--threads=1 \
--max_background_jobs=1 \
--seed=12345

sudo nvme zns reset-zone /dev/nvme0n1 -a

echo "Finished benchmark for finish_threshold=20"

#!/bin/bash

AUX_PATH="/home/femu/RocksDBFile/zenfs_aux"
DB_BENCH="/home/femu/RocksDBFile/rocksdb/db_bench"
FS_URI="zenfs://dev:nvme0n1"
ZENFS_MKFS="/home/femu/RocksDBFile/rocksdb/plugin/zenfs/util/zenfs"
RESULT_DIR="./results"


mkdir -p "$RESULT_DIR"

# Thresholds
THRESHOLDS=$(seq 0 10 100)
#THRESHOLDS="0 50"

# Run through the finish thresholds
for FT in $THRESHOLDS; do

    echo " Running benchmark for finish_threshold=${FT}"
    sudo rm -rf "${AUX_PATH:?}"/*
    echo mq-deadline | sudo tee /sys/class/block/nvme0n1/queue/scheduler
    # Make filesystem with current finish threshold
sudo $ZENFS_MKFS mkfs --zbd=nvme0n1 --aux_path="$AUX_PATH" --force --finish_threshold="$FT"
    # Start timer
    START_TIME=$(date +%s%N)

    LOG="$RESULT_DIR/output_ft_${FT}.log"
    echo "start_time_ns = $START_TIME" > "$LOG"
    echo "Running db_bench for finish_threshold=${FT}..."

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
--seed=12345 \
>> "$LOG" 2>&1

# ending timer
END_TIME=$(date +%s%N)

echo "end_time_ns=$END_TIME" >> "$LOG"
     sudo nvme zns reset-zone /dev/nvme0n1 -a
      echo " "
      echo "Finished benchmark for finish_threshold=${FT}"
done

echo "All benchmarks completed."

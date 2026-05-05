#!/bin/bash

FIO_ZONE=0
RESULT_DIR="results_intrazone_512M_MU4"
DEVICE_PATH="/dev/nvme0n1"
EXPERIMENT_NAME="intrazone"

BLOCK_SIZES=("16K" "32K" "64K" "128K" "256K" "512K" \
"1M" "2M" "4M" "8M" "16M" "32M" "64M" "256M" "512M")

mkdir -p "$RESULT_DIR"

for BS in "${BLOCK_SIZES[@]}"; do
    JSON_OUTPUT="${RESULT_DIR}/${EXPERIMENT_NAME}_bs_${BS}.json"
    
    echo "Resetting zones on $DEVICE_PATH..."
    sudo nvme zns reset-zone "$DEVICE_PATH" -a
    
    echo "Running fio with block size ${BS}..."

    sudo fio --ioengine=psync \
       --direct=1 \
       --filename="$DEVICE_PATH" \
       --rw=write \
       --bs="$BS" \
       --group_reporting \
       --zonemode=zbd \
       --name=seqwrite \
       --offset_increment=0 \
       --size=1z \
       --numjobs=1 \
       --max_open_zones=1 \
       --zonesize=512M \
       --output-format=json \
       --output="$JSON_OUTPUT"

    echo "Saved result to $JSON_OUTPUT"
    echo "-----------------------------------"
done

echo "Done. Check the results in $RESULT_DIR"

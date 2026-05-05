#!/bin/bash

### Configurations
BS=64k
RUNTIME=20
DEVICE=/dev/nvme0n1
RESULT_DIR="InterZone"

### Threads to test
THREADS=(2 4 6 8 10 12 14)

### Zone sizes to test
ZONES=("64M" "128M")

### Create result directory
mkdir -p "$RESULT_DIR"

### Running experiments for different zones
for Z in "${ZONES[@]}"; do
   echo ""
   echo "Running for zone size: $Z"

    for T in "${THREADS[@]}"; do
        echo "  Threads: $T"

        JSON_OUTPUT="${RESULT_DIR}/Result_${Z}_${T}.json"
        sudo nvme zns reset-zone $DEVICE -a
        sudo fio --name=seqwrite \
            --filename=$DEVICE \
            --rw=write \
            --ioengine=psync \
            --direct=1 \
            --bs=$BS \
            --size=1z \
            --max_open_zones=8 \
            --numjobs=$T \
            --zonesize=$Z \
            --zonemode=zbd \
            --group_reporting \
            --offset_increment=$Z \
            --output-format=json \
            --output="$JSON_OUTPUT"
            echo "Saving to Json..."
            echo ""
    done
done

echo "All experiments completed. Results saved in '${RESULT_DIR}/'"

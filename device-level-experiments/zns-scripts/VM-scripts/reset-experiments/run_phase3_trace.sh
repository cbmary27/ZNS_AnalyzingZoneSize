#!/bin/bash
set -e

CFG=$1
ZSIZE=$2
TRIALS=${3:-5}

TARGET_ZONE=13
WRITE_SIZE=4096
NUM_WRITES=256
OUTDIR=$HOME/zns-results/phase3_trace/cfg${CFG}

if [[ -z "$CFG" || -z "$ZSIZE" ]]; then
    echo "Usage: ./run_phase3_trace.sh <cfg> <zone_size_bytes> [trials]"
    echo "Example: ./run_phase3_trace.sh 0 134217728 5"
    exit 1
fi

mkdir -p "$OUTDIR"

for TRIAL in $(seq 1 $TRIALS); do
    echo "=== cfg${CFG} trace trial ${TRIAL} ==="

    echo "[1] Reset all zones"
    sudo nvme zns reset-zone /dev/nvme0n1 -a || true

    echo "[2] Fill zones 0-13 to create history"
    sudo fio --name=fill14_trace_trial${TRIAL} \
        --filename=/dev/nvme0n1 \
        --ioengine=psync \
        --direct=1 \
        --rw=write \
        --bs=64k \
        --group_reporting \
        --zonemode=zbd \
        --zonesize=${ZSIZE} \
        --size=$((14 * ZSIZE)) \
        --numjobs=1 \
        --max_open_zones=1 \
        --offset=0 \
        --output-format=json \
        --output="$OUTDIR/fill14_trace_trial${TRIAL}.json"

    echo "[3] Reset target zone once, then trace many 4K writes"
    sudo LD_LIBRARY_PATH=/home/femu/libnvme/.build/src ./phase3_trace_write /dev/nvme0n1 ${ZSIZE} ${TARGET_ZONE} ${WRITE_SIZE} ${NUM_WRITES} filled_then_reset_trace \
    "$OUTDIR/trace_trial${TRIAL}.csv"
    echo "Trial ${TRIAL} done"
done

echo "Done for cfg${CFG}"

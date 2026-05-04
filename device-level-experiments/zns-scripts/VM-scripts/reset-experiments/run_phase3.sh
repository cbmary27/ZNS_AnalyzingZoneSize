#!/bin/bash

CFG=$1
ZSIZE=$2
TRIALS=${3:-5}
TARGET_ZONE=13
WRITE_SIZE=4096
OUTDIR=$HOME/zns-results/phase3/cfg${CFG}

if [ -z "$CFG" ] || [ -z "$ZSIZE" ]; then
  echo "Usage: ./run_phase3.sh <cfg> <zone_size_bytes> [trials]"
  echo "Example: ./run_phase3.sh 0 134217728 5"
  exit 1
fi

mkdir -p "$OUTDIR"

for TRIAL in $(seq 1 $TRIALS); do
  echo "=== cfg${CFG} trial ${TRIAL} ==="

  sudo nvme zns report-zones /dev/nvme0n1 > "$OUTDIR/zone_report_trial${TRIAL}.txt"

  echo "[1] Baseline: fresh reset"
  sudo ./phase3_reset_write /dev/nvme0n1 ${ZSIZE} ${TARGET_ZONE} ${WRITE_SIZE} fresh_reset \
    "$OUTDIR/fresh_reset_trial${TRIAL}.txt"

  echo "[2] Reset all zones before fill"
  sudo nvme zns reset-zone /dev/nvme0n1 -a

  echo "[3] Fill zones 0-13"
  sudo fio --name=fill14 \
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
    --output="$OUTDIR/fill14_trial${TRIAL}.json"

  echo "[4] Test: filled then reset target zone"
  sudo ./phase3_reset_write /dev/nvme0n1 ${ZSIZE} ${TARGET_ZONE} ${WRITE_SIZE} filled_then_reset \
    "$OUTDIR/filled_then_reset_trial${TRIAL}.txt"

done

echo "Done for cfg${CFG}"

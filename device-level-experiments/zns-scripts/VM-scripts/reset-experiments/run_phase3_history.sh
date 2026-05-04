#!/bin/bash

CFG=$1
ZSIZE=$2
TRIALS=${3:-5}

TARGET_ZONE=13
WRITE_SIZE=4096
OUTDIR=$HOME/zns-results/phase3_history/cfg${CFG}

if [ -z "$CFG" ] || [ -z "$ZSIZE" ]; then
  echo "Usage: ./run_phase3_history.sh <cfg> <zone_size_bytes> [trials]"
  echo "Example: ./run_phase3_history.sh 10 67108864 5"
  exit 1
fi

mkdir -p "$OUTDIR"

# fill depths to test
FILL_COUNTS=(1 4 8 14 32)

for COUNT in "${FILL_COUNTS[@]}"; do
  COUNTDIR="$OUTDIR/fill${COUNT}"
  mkdir -p "$COUNTDIR"

  echo "=============================="
  echo "cfg${CFG} fill depth ${COUNT}"
  echo "=============================="

  for TRIAL in $(seq 1 $TRIALS); do
    echo "--- trial ${TRIAL} ---"

    sudo nvme zns report-zones /dev/nvme0n1 > "$COUNTDIR/zone_report_trial${TRIAL}.txt"

    echo "[1] Reset all zones before fill"
    sudo nvme zns reset-zone /dev/nvme0n1 -a

    echo "[2] Fill ${COUNT} zone(s)"
    sudo fio --name=fill${COUNT} \
      --filename=/dev/nvme0n1 \
      --ioengine=psync \
      --direct=1 \
      --rw=write \
      --bs=64k \
      --group_reporting \
      --zonemode=zbd \
      --zonesize=${ZSIZE} \
      --size=$((COUNT * ZSIZE)) \
      --numjobs=1 \
      --max_open_zones=1 \
      --offset=0 \
      --output-format=json \
      --output="$COUNTDIR/fill${COUNT}_trial${TRIAL}.json"

    echo "[3] Measure reset+write latency on target zone ${TARGET_ZONE}"
    sudo ./phase3_reset_write /dev/nvme0n1 ${ZSIZE} ${TARGET_ZONE} ${WRITE_SIZE} fill${COUNT} \
      "$COUNTDIR/fill${COUNT}_trial${TRIAL}.txt"
  done
done

echo "Done for cfg${CFG}"

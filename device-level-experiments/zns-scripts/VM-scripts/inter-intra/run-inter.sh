
#!/bin/bash

CFG=$1
ZSIZE=$2

if [ -z "$CFG" ] || [ -z "$ZSIZE" ]; then
  echo "Usage: ./run_inter.sh <cfg> <zone_size>"
  echo "Example: ./run_inter.sh 0 128M"
  exit 1
fi

mkdir -p $HOME/zns-results/cfg${CFG}/inter

for JOBS in 1 2 4 8 16; do
  echo "Running inter cfg${CFG} jobs=${JOBS}"

  sudo nvme zns reset-zone /dev/nvme0n1 -a

  sudo fio --name=inter_seq_jobs${JOBS} \
    --filename=/dev/nvme0n1 \
    --ioengine=psync \
    --direct=1 \
    --rw=write \
    --bs=4k \
    --group_reporting \
    --zonemode=zbd \
    --zonesize=${ZSIZE} \
    --size=${ZSIZE} \
    --numjobs=${JOBS} \
    --max_open_zones=${JOBS} \
    --offset_increment=${ZSIZE} \
    --output-format=json \
    --output=$HOME/zns-results/cfg${CFG}/inter/inter_cfg${CFG}_bs4k_jobs${JOBS}.json
done

echo "Inter cfg${CFG} completed"

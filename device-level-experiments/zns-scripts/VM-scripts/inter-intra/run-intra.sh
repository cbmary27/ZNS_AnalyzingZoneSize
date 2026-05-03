#!/bin/bash

CFG=$1
ZSIZE=$2

for BS in 4k 8k 16k 32k  64k 128k 256k; do
echo "Running intra for config $CFG for zonesize $ZSIZE"
sudo nvme zns reset-zone /dev/nvme0n1 -a

sudo fio --name=intra_seq_bs${BS} \
--filename=/dev/nvme0n1 \
--ioengine=psync \
--direct=1 \
--rw=write \
--bs=${BS} \
--group_reporting \
--zonemode=zbd \
--zonesize=${ZSIZE} \
--size=${ZSIZE} \
--numjobs=1 \
--max_open_zones=1 \
--offset=0 \
--output-format=json \
--output=$HOME/zns-results/cfg${CFG}/intra/intra_cfg${CFG}_bs${BS}_jobs1.json
done

echo "Intra zone experiment complete for config $CFG"

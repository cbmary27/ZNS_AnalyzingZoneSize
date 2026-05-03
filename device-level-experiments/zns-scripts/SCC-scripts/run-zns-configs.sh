#!/bin/bash
set -e

IMGDIR=/projectnb/cs561/students/vish1909/images
OSIMGF=$IMGDIR/u20s.qcow2
SSD_ID=${1:-0}

if [[ ! -e "$OSIMGF" ]]; then
    echo "VM disk image missing: $OSIMGF"
    exit 1
fi

# Default geometry/timing
zns_channels=8
zns_ways=2
zns_dies_per_chip=1
zns_planes_per_die=1
zns_block_size_pages=2048

zns_page_write_latency=500000
zns_page_read_latency=50000
zns_channel_transfer_latency=25000
zns_block_erase_latency=5000000

devsz_mb=$((1024*16))

max_active_zones=14
max_open_zones=14

case "$SSD_ID" in
  0)
    zns_vtable_mode=1            
    zns_chunk_size=1
    zns_channels_per_zone=8
    zns_ways_per_zone=2
    zns_min_luns=16
    zns_max_chunks_per_lun=1
    zns_zonesize=134217728
    zns_zonecap=134217728
    INCREMENT=262144
    REQUEST_SIZE=4096
    ;;
  1)
    zns_vtable_mode=4
    zns_chunk_size=1
    zns_channels_per_zone=8
    zns_ways_per_zone=2
    zns_min_luns=16
    zns_max_chunks_per_lun=1
    zns_zonesize=134217728
    zns_zonecap=134217728
    INCREMENT=262144
    REQUEST_SIZE=4096
    ;;
  10)
    zns_vtable_mode=1
    zns_chunk_size=1
    zns_channels_per_zone=8
    zns_ways_per_zone=1
    zns_min_luns=8
    zns_max_chunks_per_lun=1
    zns_zonesize=67108864
    zns_zonecap=67108864
    INCREMENT=131072
    REQUEST_SIZE=4096
    ;;
  11)
    zns_vtable_mode=2
    zns_chunk_size=1
    zns_channels_per_zone=8
    zns_ways_per_zone=1
    zns_min_luns=8
    zns_max_chunks_per_lun=1
    zns_zonesize=67108864
    zns_zonecap=67108864
    INCREMENT=131072
    REQUEST_SIZE=4096
    ;;
  18)
    zns_vtable_mode=1
    zns_chunk_size=1
    zns_channels_per_zone=4
    zns_ways_per_zone=1
    zns_min_luns=4
    zns_max_chunks_per_lun=1
    zns_zonesize=33554432
    zns_zonecap=33554432
    INCREMENT=65536
    REQUEST_SIZE=4096
    ;;
  19)
    zns_vtable_mode=2
    zns_chunk_size=1
    zns_channels_per_zone=4
    zns_ways_per_zone=1
    zns_min_luns=4
    zns_max_chunks_per_lun=1
    zns_zonesize=33554432
    zns_zonecap=33554432
    INCREMENT=65536
    REQUEST_SIZE=4096
    ;;
  *)
    echo "Unknown SSD_ID: $SSD_ID"
    exit 1
    ;;
esac

echo "Launching SSD_ID=$SSD_ID"
echo "vtable=$zns_vtable_mode zone_size=$zns_zonesize zone_cap=$zns_zonecap"
echo "channels/zone=$zns_channels_per_zone ways/zone=$zns_ways_per_zone"
echo "max_active_zones=$max_active_zones max_open_zones=$max_open_zones"

# x86_64-softmmu/qemu-system-x86_64 \
#     -name "FEMU-ZNSSD-VM" \
#     -enable-kvm \
#     -cpu host \
#     -smp 4 \
#     -m 4G \
#     -device virtio-scsi-pci,id=scsi0 \
#     -device scsi-hd,drive=hd0 \
#     -drive file=$OSIMGF,if=none,aio=native,cache=none,format=qcow2,id=hd0 \
#     -device femu,devsz_mb=4096,femu_mode=3 \
#     -net user,hostfwd=tcp::8081-:22 \
#     -net nic,model=virtio \
#     -nographic \
#     -qmp unix:./qmp-sock,server,nowait 2>&1 | tee log_cfg${SSD_ID}

x86_64-softmmu/qemu-system-x86_64 \
    -name "FEMU-ZNSSD-VM" \
    -enable-kvm \
    -cpu host \
    -smp 16 \
    -m 4G \
    -device virtio-scsi-pci,id=scsi0 \
    -device scsi-hd,drive=hd0 \
    -drive file=$OSIMGF,if=none,aio=native,cache=none,format=qcow2,id=hd0 \
    -device femu,\
devsz_mb=4096,\
femu_mode=3,\
zns_vtable_mode=$zns_vtable_mode,\
zns_channels=$zns_channels,\
zns_channels_per_zone=$zns_channels_per_zone,\
zns_ways=$zns_ways,\
zns_ways_per_zone=$zns_ways_per_zone,\
zns_dies_per_chip=$zns_dies_per_chip,\
zns_planes_per_die=$zns_planes_per_die,\
zns_block_size_pages=$zns_block_size_pages,\
zns_page_read_latency=$zns_page_read_latency,\
zns_page_write_latency=$zns_page_write_latency,\
zns_block_erasure_latency=$zns_block_erase_latency,\
zns_channel_transfer_latency=$zns_channel_transfer_latency,\
zns_zonesize=$zns_zonesize,\
zns_zonecap=$zns_zonecap \
    -net user,hostfwd=tcp::8081-:22 \
    -net nic,model=virtio \
    -nographic \
    -qmp unix:./qmp-sock,server,nowait 2>&1 | tee log_cfg${SSD_ID}
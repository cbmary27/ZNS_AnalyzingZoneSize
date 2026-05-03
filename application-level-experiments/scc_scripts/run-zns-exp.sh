#!/bin/bash
#
# Huaicheng Li <hcli@cmu.edu>
# Run FEMU as Zoned-Namespace (ZNS) SSDs
#

# Default values
ZONE_SIZE_MB=${1:-128}
CHANNELS_PER_ZONE=${2:-8}
WAYS_PER_ZONE=${3:-2}

# Derived values
ZONE_SIZE=$((ZONE_SIZE_MB*1024*1024))

# Image directory
IMGDIR=/projectnb/cs561/students/chris27/Project1/images
OSIMGF=$IMGDIR/u20s.qcow2

if [[ ! -e "$OSIMGF" ]]; then
    echo ""
    echo "VM disk image couldn't be found ..."
    echo "Please prepare a usable VM image and place it as $OSIMGF"
    echo "Once VM disk image is ready, please rerun this script again"
    echo ""
    exit
fi

x86_64-softmmu/qemu-system-x86_64 \
    -name "FEMU-ZNSSD-VM" \
    -enable-kvm \
    -cpu host \
    -smp 4 \
    -m 4G \
    -device virtio-scsi-pci,id=scsi0 \
    -device scsi-hd,drive=hd0 \
    -drive file=$OSIMGF,if=none,aio=native,cache=none,format=qcow2,id=hd0 \
    -device femu,\
devsz_mb=16384,\
id=nvme0,\
femu_mode=3,\
zns_zonesize=$ZONE_SIZE,\
zns_zonecap=$ZONE_SIZE,\
zns_channels_per_zone=$CHANNELS_PER_ZONE,\
zns_channels=8,\
zns_ways=2,\
zns_dies_per_chip=1,\
zns_planes_per_die=1,\
zns_block_size_pages=2048,\
zns_ways_per_zone=$WAYS_PER_ZONE,\
zns_vtable_mode=1,\
    -net user,hostfwd=tcp::8080-:22 \
    -net nic,model=virtio \
    -nographic \
    -qmp unix:./qmp-sock,server,nowait 2>&1 | tee log
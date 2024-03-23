#!/bin/bash
#
# updated 5/3/2019 - DD
#
# Script to run from within a Chromium OS USB boot disk, via CTRL+U boot, on any Chromebook/Chromebox in developer mode with the flag set for USB boot.
# The script then creates a physical forensic dd clone of the internal Chromebook HD writing out to an evidence drive previously GPT partitioned with an "EVIDENCE" partition created.
# "EVIDENCE" partition on destination drive should be created with prep_evidence_drive.sh script.
#
# A prepared "EVIDENCE" drive must be attached to the Chromebook/Chromebox prior to running this script.
# 


# If we're not running as root, restart as root.
if [ ${UID:-$(id -u)} -ne 0 ]; then
  exec sudo "$0" "$@"
fi

# Load functions and constants for chromeos-install.
. /usr/share/misc/chromeos-common.sh || exit 1
. /usr/sbin/write_gpt.sh || exit 1



main() {
 
# Set variable for the root (USB boot) device. 
 ROOTDEV=$(rootdev -d)

# Use ROOTDEV variable to find and set a variable for the internal HD device containing the STATE partition, such as /dev/mmcblk0p1.
 SRC=$(cgpt find -l STATE | grep -v ${ROOTDEV})
 echo -n "Source: "
 echo ${SRC}

# Set variable for block device of SRC. This removes the partition identifier from the above command, leaving /dev/mmcblk0.
 BLOCK_SRC=$(get_block_dev_from_partition_dev ${SRC})
 echo -n "Source Block Device: "
 echo ${BLOCK_SRC}

# Identify and set a variable for the attached output drive containing a previously GPT paritition evidence disk containing an EVIDENCE partition, such as /dev/sdb1.
 DST=$(cgpt find -l EVIDENCE)
 echo -n "Destination: "
 echo ${DST}
 
# Set variable for block device of DST. This removes the partition identifier from the above command, leaving /dev/sdb.
 BLOCK_DST=$(get_block_dev_from_partition_dev ${DST})
 echo -n "Destination Block Device: "
 echo ${BLOCK_DST} 

 
#
# Time to clone the source disk to the attached destination disk and finish!
#
 echo "Cloning " ${BLOCK_SRC} " to " ${BLOCK_DST} 
 
 dd conv=sync,noerror bs=2M if=${BLOCK_SRC} of=${BLOCK_DST} oflag=dsync status=progress 
 
 
 # All done. Force data to disk before we declare done.
 sync
 
 echo "------------------------------------------------------------"
 echo ""
 echo "Cloning process complete."
 echo "Please shutdown and remove the newly cloned evidence USB device."
 echo ""

}

main "$@"

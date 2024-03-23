#!/bin/bash
#
# updated 7/8/2019 - DD
#
# Script is for customizing a factory ChromeOS Recovery USB to turn the USB into a Physical Cloning Recovery USB designed for
# forensic physical acquisition of seized Chromebook or Chromebox devices.
#
# This script is designed to be run from within your booted Chromium OS live USB boot disk, on any computer other than your evidentiary Chromebook.
# This script and all other provided scripts must be placed in a /home/scripts/ folder of your booted Chromium OS live USB disk and then run.
# The required provided custom_chromeos-install must also be located in this same /home/scripts folder.
#

# If we're not running as root, restart as root.
if [ ${UID:-$(id -u)} -ne 0 ]; then
  exec sudo "$0" "$@"
fi

# Load functions and constants for chromeos-install.
. /usr/share/misc/chromeos-common.sh || exit 1
. /usr/sbin/write_gpt.sh || exit 1

# Like mount but keeps track of the current mounts so that they can be cleaned
# up automatically.
tracked_mount() {
  local last_arg
  eval last_arg=\$$#
  MOUNTS="${last_arg}${MOUNTS:+ }${MOUNTS:-}"
  mount "$@"
}

# Unmount with tracking.
tracked_umount() {
  # dash does not support ${//} expansions.
  local new_mounts
  for mount in $MOUNTS; do
    if [ "$mount" != "$1" ]; then
      new_mounts="${new_mounts:-}${new_mounts+ }$mount"
    fi
  done
  MOUNTS=${new_mounts:-}

  umount "$1"
  rmdir "$1"
}

# Create a loop device on the given file at a specified (sector) offset.
# Remember the loop device using the global variable LOOP_DEV.
# Invoke as: command
# Args: FILE OFFSET BLKSIZE
loop_offset_setup() {
  local filename=$1
  local offset=$2
  local blocksize=$3

  if [ "${blocksize}" -eq 512 ]; then
    local param=""
  else
    local param="-b ${blocksize}"
  fi

  LOOP_DEV=$(losetup -f ${param} --show -o $(($offset * blocksize)) ${filename})
  if [ -z "$LOOP_DEV" ]; then
    die "No free loop device. Free up a loop device or reboot. Exiting."
  fi

  LOOPS="${LOOP_DEV}${LOOPS:+ }${LOOPS:-}"
}

# Delete the current loop device.
loop_offset_cleanup() {
  # dash does not support ${//} expansions.
  local new_loops
  for loop in $LOOPS; do
    if [ "$loop" != "$LOOP_DEV" ]; then
      new_loops="${new_loops:-}${new_loops+ }$loop"
    fi
  done
  LOOPS=${new_loops:-}

  # losetup -a doesn't always show every active device, so we'll always try to
  # delete what we think is the active one without checking first. Report
  # success no matter what.
  losetup -d ${LOOP_DEV} || /bin/true
}

# Mount the existing loop device at the mountpoint in $TMPMNT.
# Args: optional 'readwrite'. If present, mount read-write, otherwise read-only.
mount_on_loop_dev() {
  local rw_flag=${1-readonly}
  local mount_flags=""
  # if [ "${rw_flag}" != "readwrite" ]; then
  #   mount_flags="-o ro"
  # fi
  tracked_mount ${mount_flags} ${LOOP_DEV} ${TMPMNT}
}

# Unmount loop-mounted device.
umount_from_loop_dev() {
  mount | grep -q " on ${TMPMNT} " && tracked_umount ${TMPMNT}
}

# Undo all mounts and loops.
cleanup() {
  set +e

  local mount_point
  for mount_point in ${MOUNTS:-}; do
    umount "$mount_point" || /bin/true
  done
  MOUNTS=""

  local loop_dev
  for loop_dev in ${LOOPS:-}; do
    losetup -d "$loop_dev" || /bin/true
  done
  LOOPS=""
}

is_ext2() {
  local rootfs="$1"
  local offset="${2-0}"
  # Make sure we're checking an ext2 image
  local sb_magic_offset=$((0x438))
  local sb_value=$(sudo dd if="$rootfs" skip=$((offset + sb_magic_offset)) \
                   count=2 bs=1 2>/dev/null)
  local expected_sb_value=$(printf '\123\357')
  if [ "$sb_value" = "$expected_sb_value" ]; then
    return 0
  fi
  return 1
}

enable_rw_mount() {
  local rootfs="$1"
  local offset="${2-0}"
  # Make sure we're checking an ext2 image
  if ! is_ext2 "$rootfs" $offset; then
    echo "enable_rw_mount called on non-ext2 filesystem: $rootfs $offset" 1>&2
    return 1
  fi
  local ro_compat_offset=$((0x464 + 3))  # Set 'highest' byte
  # Dash can't do echo -ne, but it can do printf "\NNN"
  # We could use /dev/zero here, but this matches what would be
  # needed for disable_rw_mount (printf '\377').
  printf '\000' |
    sudo dd of="$rootfs" seek=$((offset + ro_compat_offset)) \
            conv=notrunc count=1 bs=1 2>/dev/null
}



main() {
 
 # Set variable for the root (USB boot) device. 
 ROOTDEV=$(rootdev -d)

 readarray -t lines < <(lsblk --nodeps -no name,vendor,model,serial,size,subsystems | grep "usb")

 # Prompt the user to select one of the lines.
 echo "Please select the Factory ChromeOS Recovery USB drive you want to prepare as a modified Recovery USB."
 echo "This USB will set flags for USB booting in Developer Mode and Cloning a Chromebook/Chromebox HD if desired."
 echo "This will replace the /usr/sbin/chromeos-install script on the USB ROOT-A partition."
 select choice in "${lines[@]}"; do
 [[ -n $choice ]] || { echo "Invalid choice. Please try again." >&2; continue; }
 break # valid choice was made; exit prompt.
 done

 # Split out the ID of the selected USB device.
 read -r id unused <<<"$choice"

 echo ${choice}
 DEV=/dev/${id}
 echo ${DEV}

 if [[ $DEV == $ROOTDEV ]]; then
	echo "You have selected the USB drive you are booted from right now (i.e. Your currently running ChromeOS or Chromium OS), not your ChromeOS Recovery Drive."
	echo "Please re-run this script and select the factory ChromeOS Recovery Drive." 
	echo "...exiting script, without doing anything!"
	return 1
 else
	# Initial disclaimer
	echo "Got $DST as the target drive."
	echo "WARNING! You are about to modify the ROOT-A partition of this device! Continue at your own risk!"
	read -p "Press [Enter] to proceed on $DST or CTRL+C to quit"
	echo

	# This disk is probably freshly made from an image, let's get it fixed up
	# FIXME : This is likely very specific to running on Chromium OS, potentially find a better general purpose solution for putting the end of the drive in the correct place
	echo w | fdisk $DEV
	cgpt repair $DEV

	# Set a variable for the ROOT-A partition of the factory ChromeOS Recovery USB, such as /dev/sdc1.
	DST=$(cgpt find -l "ROOT-A" ${DEV})
	# echo -n "DST:"
	# echo ${DST}
	
	# Set variable for block device of DST. This removes the partition identifier from the above command, leaving /dev/sdc.
	BLOCK_DST=$(get_block_dev_from_partition_dev ${DST})
	# echo -n "Destination Block Device: "
	# echo ${BLOCK_DST} 
	 
	# Find the partition number of the ROOT-A partition on the factory ChromeOS Recovery USB and set a variable for it, such as 1.
	PARTITION_NUM_ROOTA=$(cgpt find -n -l "ROOT-A" "${DEV}")
	# echo -n "PARTITION_NUM_ROOTA:"
	# echo ${PARTITION_NUM_ROOTA}
	 
	# Create a temp folder to be used for a mount point later and set a variable for the mount point.
	TMPMNT=$(mktemp -d)

	# Set variable for base device name from the ROOT-A partition of factory ChromeOS Recovery USB, to be fed into blocksize function to determine block size, such as /dev/sdc1 (-> sdc1.
	BASE_DST=$(basename ${DST})
	# echo -n "BASE_DST:"
	# echo ${BASE_DST}
	 
	# Set variable for block size of the factory ChromeOS Recovery USB that contains the ROOT-A partition, such as 512. 
	DST_BLKSIZE=$(blocksize ${BASE_DST})
	# echo -n "DST_BLKSIZE:"
	# echo ${DST_BLKSIZE}
	 
	# Extract the whole disk block device from the partition device.
	# This works for /dev/sda3 -> /dev/sda -> sda as well as /dev/mmcblk0p2 -> /dev/mmcblk0 -> mmcblk0 and set it to a variable.
	BLOCK=$(get_block_dev_from_partition_dev ${DST##*/})
	# echo -n "BLOCK:"
	# echo ${BLOCK}

	# Set variable for starting offset of ROOT-A partition of the factory ChromeOS Recovery USB.
	ROOTA_OFFSET=$(cgpt show -b -i ${PARTITION_NUM_ROOTA} ${BLOCK_DST})
	# echo -n "ROOTA_OFFSET:"
	# echo ${ROOTA_OFFSET}

	# Set variable for starting offset of ROOT-A partition in bytes of the factory ChromeOS Recovery USB
	ROOTA_OFFSET_BYTES=$((${ROOTA_OFFSET} * ${DST_BLKSIZE}))

	#
	# Time to modify the ext2 flags on the ROOT-A partition
	#
	enable_rw_mount ${BLOCK_DST} ${ROOTA_OFFSET_BYTES}
	sync
	 
	# Mount ROOT-A partition on factory ChromeOS Recovery USB and replace the /usr/sbin/chromeos-install with the custom_chromeos-install script. 

	echo ""
	echo "Replacing /usr/sbin/chromeos-install..."
	loop_offset_setup ${BLOCK_DST} ${ROOTA_OFFSET} ${DST_BLKSIZE}
	mount_on_loop_dev readwrite
	 
	cp /home/scripts/custom_chromeos-install ${TMPMNT}/usr/sbin/chromeos-install
	 
	umount_from_loop_dev
	sync
	loop_offset_cleanup

fi 

 
 # All done. Force data to disk before we declare done.
 sync
 cleanup
 trap - EXIT

 echo "------------------------------------------------------------"
 echo ""
 echo "Factory ChromeOS Recovery USB has been turned into a Physical Cloning Recovery USB for purposes of forensic physical acquisition of Chromebook/Chromebox devices."
 echo "You may now disconnect your Physical Cloning Recovery USB and shutdown this Chromium OS live USB session."
 echo "Properly label this USB so you don't confuse it with any other ChromeOS Recovery USBs."
 
}

main "$@"

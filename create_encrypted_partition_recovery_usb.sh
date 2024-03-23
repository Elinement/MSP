#!/bin/bash
#
# updated 11/22/2019 - DD & DL
#
# This program creates an Encrypted Partition Recovery USB by expanding a factory Chrome OS Recovery Drive stateful partition without altering the original partition layout/scheme.
# Recommend to use a 128GB or larger USB Recovery Drive, to accomodate space for Chrombook/Chrombox encrypted partition recovery.
# The script then writes a file called decrypt_stateful to the STATE partition of the expanded Chrome OS Recovery Drive.
# Once finished you may place any Chromebook/Chromebox in Recovery Mode and attach the created Encrypted Partition Recovery USB to extract decrypted content after
# providing the username and password for the account(s) on the device. The "owner" account will also decrypt and extract encrypted.block.
#
# This script is designed to be run from within your booted Chromium OS live USB boot disk, on any computer other than your evidentiary Chromebook.
# This script and all other provided scripts must be placed in a /home/scripts/ folder of your booted Chromium OS live USB disk and then run. 
# 

# If we're not running as root, restart as root.
if [ ${UID:-$(id -u)} -ne 0 ]; then
  exec sudo "$0" "$@"
fi

# Load functions and constants.
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

main() {

NUM_REGEX='^[0-9]+([.][0-9]+)?$'
ROOTDEV=$(rootdev -d)

readarray -t lines < <(lsblk --nodeps -no name,vendor,model,serial,size,subsystems | grep "usb")

# Prompt the user to select one of the lines.
echo "Please select the Factory ChromeOS Recovery USB drive you want to prepare for encrypted partition recovery."
echo "This will remove any currently existing data on the USB STATE partition."
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

	# This disk is probably freshly made from an image, let's get it fixed up
	# FIXME : This is likely very specific to running on Chromium OS, potentially find a better general purpose solution for putting the end of the drive in the correct place
	echo w | fdisk $DEV
	cgpt repair $DEV

	# Calculate total available space
	STATE_START=$(cgpt show -i 1 -n -b -q $DEV)
	CURR_PART_END=$(sudo cgpt show $DEV | grep "Sec GPT table" | awk '{print $1}')

	AVAILABLE_SZ=$((CURR_PART_END - STATE_START))
	AVAILABLE_SZ_MB=$((AVAILABLE_SZ * 512 / 1024 / 1024))
	AVAILABLE_SZ_GB=$(awk "BEGIN {printf \"%.2f\",${AVAILABLE_SZ_MB} / 1024}")

	# Prompt and read desired sizes
	echo "We will expand the STATE partition (Chrome OS's data partition) on your Recovery Drive.
	You will specify how much size to allocate to the STATE partition.
	There are $AVAILABLE_SZ_MB MiB ($AVAILABLE_SZ_GB GiB) available to work with.
	You have the option of modifying your STATE partition using either MiB or GiB(default) precision."
	echo
	read -e -p "Would you like to use MiB or GiB? [m/G] " -i "G" STATE_SZ_PRECISION
	if [[ $STATE_SZ_PRECISION == "g" ]] || [[ $STATE_SZ_PRECISION == "G" ]]; then
	   STATE_SZ_PRECISION="GiB"
	elif [[ $STATE_SZ_PRECISION == "m" ]] || [[ $STATE_SZ_PRECISION == "M" ]]; then
	   STATE_SZ_PRECISION="MiB"
	else
	   echo "ERROR: $STATE_SZ_PRECISION is not a valid option."
	   return 1
	fi

	if [[ $STATE_SZ_PRECISION == "GiB" ]]; then
	   STATE_SZ_DEFAULT=10
	else
	   STATE_SZ_DEFAULT=10240
	fi
	echo

	read -e -p "How big should the STATE partition be in $STATE_SZ_PRECISION (default: \
	$STATE_SZ_DEFAULT)? " -i $STATE_SZ_DEFAULT STATE
	if ! [[ $STATE =~ $NUM_REGEX ]]; then
	   echo "ERROR: Not a valid number."
	   return 1
	fi
	echo

	echo "You chose to allocate $STATE $STATE_SZ_PRECISION for the state partition.
	The size of the STATE partition must be integers."
	echo
	read -e -p "Is everything correct? [y/N] " -i "N" CONTINUE
	if [[ $CONTINUE != "y" ]]  && [[ $CONTINUE != "Y" ]]; then
		echo "You said the values were wrong."
		return 1
	fi
	echo

	# Calculate starting sector(s) and size(s)
	STATE_START=$(cgpt show -i 1 -n -b -q $DEV)
	if [[ $STATE_SZ_PRECISION == "GiB" ]]; then
	   STATE_SZ=$((STATE * 1024 * 1024 * 2))
	else
	   STATE_SZ=$((STATE * 1024 * 2))
	fi

	# Fail if new sizes are too big
	if [ $AVAILABLE_SZ -lt $((STATE)) ]; then
		echo "ERROR: Chosen space allocation is larger than available space."
		return 1
	fi

	if [[ $STATE_SZ_PRECISION == "GiB" ]]; then
	   STATE_SZ_MB=$((STATE_SZ * 512 / 1024 / 1024))
	   STATE_SZ_GB=$((STATE_SZ_MB / 1024))
	else
	   STATE_SZ_MB=$STATE
	   STATE_SZ_GB=$(awk "BEGIN {printf \"%.2f\",${STATE_SZ_MB} / 1024}")
	fi

	echo "STATE will be allocated $STATE_SZ sectors, or $STATE_SZ_MB MiB, or $STATE_SZ_GB GiB."
	echo "After this point, your disk will be repartitioned and formatted."
	echo
	read -e -p "Does this look good? [y/N] " -i "N" CONTINUE
	if [[ $CONTINUE != "y" ]] && [[ $CONTINUE != "Y" ]]; then
		echo "You said the values were wrong."
		return 1
	fi
	echo

	# Modify GPT table
	echo "Editing partition table..."
	#cgpt add -i 1 -b $STATE_START -s $STATE_SZ -l STATE $DEV
	cgpt add -i 1 -s $STATE_SZ $DEV	

	sync	
	
	# Set a variable for the factory ChromeOS Recovery USB containing the STATE partition, such as /dev/sdb1.
	 DST=$(cgpt find -l STATE ${DEV})
	 # echo -n "DST:"
	 # echo ${DST}
	
	# Zero out STATE partition
	STATE_SEEK=$((STATE_START / 1024 / 2))
	STATE_COUNT=$((STATE_SZ / 1024 / 2))
	echo "Formatting stateful partition..."
	echo
	/sbin/mkfs.ext4 -F -b 4096 $DST
	echo
	sync
	
	# Set variable for block device of DST. This removes the partition identifier from the above command, leaving /dev/sdb.
	 BLOCK_DST=$(get_block_dev_from_partition_dev ${DST})
	 # echo -n "Destination Block Device: "
	 # echo ${BLOCK_DST} 
	 
	# Find the partition number of the STATE partition on the factory ChromeOS Recovery USB and set a variable for it, such as 1.
	 PARTITION_NUM_STATE=$(cgpt find -n -l STATE "${DEV}")
	 # echo -n "PARTITION_NUM_STATE:"
	 # echo ${PARTITION_NUM_STATE}
	 
	# Create a temp folder to be used for a mount point later and set a variable for the mount point.
	 TMPMNT=$(mktemp -d)

	# Set variable for base device name from the STATE partition of the factory ChromeOS Recovery USB, to be fed into blocksize function to determine block size, such as /dev/sdb1 (-> sdb1.
	 BASE_DST=$(basename ${DST})
	 # echo -n "BASE_DST:"
	 # echo ${BASE_DST}
	 
	# Set variable for block size of the factory ChromeOS Recovery USB that contains the STATE partition, such as 512. 
	 DST_BLKSIZE=$(blocksize ${BASE_DST})
	 # echo -n "DST_BLKSIZE:"
	 # echo ${DST_BLKSIZE}
	 
	# Extract the whole disk block device from the partition device.
	# This works for /dev/sda3 -> /dev/sda -> sda as well as /dev/mmcblk0p2 -> /dev/mmcblk0 -> mmcblk0 and set it to a variable.
	 BLOCK=$(get_block_dev_from_partition_dev ${DST##*/})
	 # echo -n "BLOCK:"
	 # echo ${BLOCK}

	# Set variable for starting offset of STATE partition of the factory ChromeOS Recovery USB.
	 STATE_OFFSET=$(cgpt show -b -i ${PARTITION_NUM_STATE} ${BLOCK_DST})
	 # echo -n "STATE_OFFSET:"
	 # echo ${STATE_OFFSET}
	 
	#
	# Time to mount via loopback and write decrypt_stateful and finish!
	#
	 echo -n "Adding decrypt_stateful to "
	 echo ${DST}
	 
	 loop_offset_setup ${BLOCK_DST} ${STATE_OFFSET} ${DST_BLKSIZE}
	 mount_on_loop_dev readwrite
	 
	 echo -n "1" | tee ${TMPMNT}/decrypt_stateful >/dev/null
	 
	 umount_from_loop_dev
	 sync
	 loop_offset_cleanup
	 
fi

 
 # All done. Force data to disk before we declare done.
 sync
 cleanup
 trap - EXIT

echo "You may now remove the USB, place your Chromebook/Chromebox in Recovery Mode and attach this USB"
echo "to perform a logical extraction of encrypted user and system data on the STATE partition of the Chromebook/Chromebox."
echo "Username and password authentication required to perform this encrypted extraction."
echo "Poperly label this 'Encrypted Partition Recovery USB' so you don't confuse it with any other ChromeOS Recovery USBs."
echo ""
echo "Google does not use special characters in the prefix of email addresses"
echo "So when using this Encrypted Partition Recovery USB, you will be prompted for a username and"
echo "you must type an email address such as first.last@gmail.com as firstlast@gmail.com!"
echo ""	

}

main "$@"
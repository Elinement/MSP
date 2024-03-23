#!/bin/bash
#
# updated 5/3/2019 - DD
#
# Script to prepare an evidence drive as a GPT partition disk by wiping (if needed) and creating a small GPT data partition labeled as "EVIDENCE" on the disk
# This script removes any existing partitioning information from the disk and offers the user the option of wiping the disk if it contains any data.
# You MUST WIPE the selected destination disk to remove any residual data left on the disk becuase the internal HD of the seized Chromebook will be cloned to this destination disk.

# If we're not running as root, restart as root.
if [ ${UID:-$(id -u)} -ne 0 ]; then
  exec sudo "$0" "$@"
fi

ROOTDEV=$(rootdev -d)

readarray -t lines < <(lsblk --nodeps -no name,vendor,model,serial,size,subsystems | grep "usb")

# Prompt the user to select one of the lines.
echo "Please select the USB drive you want to prepare as a Chromebook forensic acquisition destination drive."
echo "This will destroy any existing partitioning information on the disk."
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
	echo "You have selected the USB drive you are booted from right now (i.e. Your currently running ChromeOS or Chromium OS), not your evidence destination drive."
	echo "Please re-run this script and select the wiped large-capacity USB drive you wish to use as your evidence destination drive." 
	echo "...exiting script, without doing anything!"
	return 1
else
	echo "Checking evidence destination drive for existing data..."
	WIPED1=$(dd conv=sync,noerror bs=512 count=2048 if=${DEV} status=none | sum | awk '{print $1}')
	WIPED2=$(dd conv=sync,noerror bs=512 count=2048 skip=$(expr $(blockdev --getsz ${DEV}) - 2048) if=${DEV} status=none | sum | awk '{print $1}')
	if [[ $WIPED1 != "00000" || $WIPED2 != "00000" ]]; then
		echo "Your drive contains data. We recommend wiping the drive first before you prepare it as an evidence destination drive?"
		read -p "Would you like to wipe the drive now? This may take some time depending on the size of the drive.  " -n 1 -r WIPECHOICE
	
		if [[ $WIPECHOICE =~ ^[Yy]$ ]]
			then
			dd conv=sync,noerror bs=2M if=/dev/zero of=${DEV} oflag=dsync status=progress
			dd conv=sync,noerror bs=512 count=2048 seek=$(expr $(blockdev --getsz ${DEV}) - 2048) if=/dev/zero of=${DEV} oflag=dsync status=progress
		else
			echo "Continuing evidence destination drive preparation without wiping..."
		fi
	fi

    echo "Your drive appears to be clean and ready for paritioning."
	echo "You are about to write new GPT partition information on drive " ${DEV}
	read -p "Are you sure? " -n 1 -r WRITEGPTCHOICE

	if [[ $WRITEGPTCHOICE =~ ^[Yy]$ ]]
		then
		printf "o\nn\np\n1\n\n\nw\n" | fdisk ${DEV}	
		echo "Clearing and rewriting new GPT partition information on drive " ${DEV}
		cgpt create ${DEV}
		cgpt add -l EVIDENCE -s 4096 -t data -b 4096 ${DEV} 
		cgpt show ${DEV}
		sync
		echo "Done preparing destination USB drive for Chromebook forensic acquisition!" 
		echo "You may now disconnect the " ${choice} " drive."
	else
		echo "...exiting script, without doing anything!"
		return 1
	fi
fi




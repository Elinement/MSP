# MSP
Modify Stateful Partition of a Chromebook recovery image to allow for recovery of ChromeBook.

# Requirements
- Three 32GB USB flash drives
- Custom bash scripts (provided in GitHub Repo)
- An additional USB drive where the bash scripts will be located
- A large capacity USB hard drive large enough to hold a clone of the Chromebook/Chromebox internal hard drive, Chrome Browser, Chromebook Recovery Utility app, and the “Special” build of Chromium
- A PC or Laptop with Legacy Boot or "BIOS" mode

# Guide

<details>
<summary>Create a factory ChromeOS Recovery USB drive</summary>
1. You must create unique Recovery USB drives for each model Chromebook/Chromebox device you wish to acquire. Each Recovery USB is designed for a specific model and will only work with that model. You will need to repeat these steps each time you need to acquire a new Chromebook/Chromebox device, using freshly created Recovery USB drives.

2. Your first step is to create factory ChromeOS Recovery USB drives for the specific Chromebook/Chromebook you need to acquire.

3. Run your Chrome Browser, type chrome://apps/ into the Chrome address bar, launch the Chromebook Recovery Utility app and click “Get Started.”

4. Click “Select a model from a list” and select your manufacturer and model from the dropdown boxes…
![image](https://github.com/Elinement/MSP/assets/73756572/ad0480c4-3759-43e9-a71e-927196699c84)

…or enter a model # directly and click “Continue.”
![image](https://github.com/Elinement/MSP/assets/73756572/b32d8c67-9ec2-4022-b571-dc4071fee06a)

5. Select your 32GB USB drive, on which you will be deploying one of the customized ChromeOS Recovery images discussed in this document, and click “Continue.”
![image](https://github.com/Elinement/MSP/assets/73756572/bffd1e35-152e-4a20-9b2c-5503b6f5aec8)

6. Click “Create now” to create a factory ChromeOS Recovery USB drive.
![image](https://github.com/Elinement/MSP/assets/73756572/c2712677-3465-4293-9d8f-7ca1570460c6)

7. When complete, safely eject your USB.

8. Click “Create another” to repeat the steps in this section to create a second factory ChromeOS Recovery USB drive, one to modify as an Encrypted Partition Recovery USB and one to modify as a Physical Cloning Recovery USB.

9. Note that if you are performing these steps on a Windows OS, upon the creation of these ChromeOS USB drives, Windows will pop up NUMEROUS annoying dialog boxes asking if you want to format all of the many newly created partitions on the disk. Do NOT format or do anything other than simply close each and every pop-up dialog that appears.
</details>
<details>
<summary>Create a Chromium OS live USB</summary>

1. The Chromium OS Live USB created in this section is designed to be used as a “utility” OS environment, in which you will be running various scripts to create your needed Recovery USBs or perform various functions. These “Special” build Chromium OS Live USBs need to be able to boot one of your forensic computers successfully so you can operate inside this Chromium OS environment. All of these procedures were successfully accomplished with Special builds 72 and 78, booting a MacBook Pro laptop. Testing with build 76 resulted in unsuccessful booting of that same MacBook Pro laptop due to video driver issues. Through trial and error, you may need to find the build (up through build 78 at the time of this release) that properly boots your forensic computer that you will be using. This step, and which Special build of Chromium that you use, will depend solely on the computer you will be booting with your Chromium OS Live USB.

*Note: Once you find a build that successfully boots you forensic computer, this Chromium OS Live USB does not need to be recreated each time you need to acquire a new Chromebook/Chromebox device and may be reused on your forensic computer for any subsequent creating of custom Recovery USB drives in the following sections of this document.*

2. Download the “Special” build of Chromium for amd64 or x86 computers,Camd64OS_R78-12499.B-Special.7z for 64-bit computers, available here:https://chromium.arnoldthebat.co.uk/index.php?dir=special&order=modified&sort=desc ***THIS IMAGE REQUIRES A LEGACY BIOS PC/LAPTOP***  
![image](https://github.com/Elinement/MSP/assets/73756572/3ed806bd-02de-44db-a0ef-010d5341452a)  

3. Use 7-Zip to extract the image out of the 7z archive. Note, older releases called the image chromium_image.img but more recent releases of these Chromium images have been named chromium_image.bin instead. Regardless of what the name of the image is, simply extract the image contained in the 7-zip archive.  
![image](https://github.com/Elinement/MSP/assets/73756572/50d1532c-0d47-4937-a106-fe8aacac3d29)  

4. Launch the Chromebook Recovery Utility app and click the gear icon in the upper-right corner of the Chromebook Recovery Utility app. chrome://apps/  
![image](https://github.com/Elinement/MSP/assets/73756572/e9deec9e-e98a-4467-880b-4218d856c288)  

5. If your extracted Chromium OS image has a .bin file extension then the image file will be immediately visible when you browse to the folder containing the image. If your extracted Chromium OS image has an .img file extension, you will not immediately see the image file in the browse window where you select the downloaded and extracted “local image” and you must type “*.*” or “*.img” in the File name: box (as shown in the 2nd screenshot below) to see and select the chromium_image.img image.  
![image](https://github.com/Elinement/MSP/assets/73756572/90926490-843a-41aa-813a-02ad6c333f3b)  
![image](https://github.com/Elinement/MSP/assets/73756572/72fc2ea7-e1a6-494d-a18a-eb333474e737)  

6. Select a 32GB USB drive, on which you will be deploying the Chromium OS live USB image, and click “Continue.”
   ![image](https://github.com/Elinement/MSP/assets/73756572/a0256394-218b-4e49-a841-079899b6c4f6)

7. Click “Create now” to create your Chromium OS live USB drive.
![image](https://github.com/Elinement/MSP/assets/73756572/61b046f8-f03f-43f6-861e-f461b7e4a03f)
8. When complete, safely eject your USB and label the USB as your Chromium OS live USB.\
   ![image](https://github.com/Elinement/MSP/assets/73756572/73841534-11a8-4de6-aca9-08615603494c)
9. Note that upon the creation of this USB drive, Windows will pop up NUMEROUS annoying dialog boxes asking if you want to format all of the many newly created partitions on the disk. Do NOT format or do anything other than simply close each and every pop-up dialog that appears.
10. If this Chromium OS live USB does not correctly boot your own forensic computer then you will need to repeat this section to find a “Special” build that does correctly boot your own computer, or try another forensic computer.

</details>
<details>
  <summary>Copy provided scripts to your Chromium OS live USB</summary>  
  
  *Note: this section of the instructions requires at least some minimal understanding of *nix command line usage and commands.**

  1. On your additional regular USB thumb drive, use Windows to create a folder in the root of the thumb drive called “scripts” and copy all provided bash scripts into that “scripts” folder.

2. Boot your own forensic computer to your newly created Chromium OS live USB.

3. Upon booting to Chromium OS, at the GUI splash screen, press CTRL+ALT+F2 to open a non-GUI pseudoterminal (TTY1 = /dev/pts/1), otherwise known as a terminal or console.

4. Log into TTY1 using “root” as the username and no password is required.

5. Plug in your USB thumb drive containing all the provided bash scripts in a “scripts” folder. The USB drive should contain ONLY the provided scripts in a “scripts” folder and nothing else!

6. At the terminal prompt, run “fdisk -l” so you can identify your USB drive containing the bash scripts.

7. At the terminal prompt, type “mktemp -d” and hit enter. Make note of the temporary folder created, as you will use this folder as a mount point to mount your USB drive containing the bash scripts. (i.e. temp folder created named /tmp/tmp.i4F2gtKrs)

8. Mount the partition of your USB drive that contains the bash scripts using the command “mount /dev/sdc1 /tmp/tmp.i4F2gtKrs5” where /dev/sdc1 must be the correct device and partition identifier for your USB drive containing the bash scripts. The /tmp/tmp.i4F2gtKrs5 part of the command must match the randomly generated folder created by the “mktemp -d” command.

9. Copy all files from /tmp/tmp.i4F2gtKrs5/scripts/ to a /home/scripts/ folder on your Chromium OS live USB using the command:mkdir /home/scripts && cp /tmp/tmp.i4F2gtKrs5/scripts/* /home/scripts/

10. Unmount the USB drive containing the bash scripts, using the command “umount /tmp/tmp.i4F2gtKrs5”

11. Unplug the USB drive containing the bash scripts so it is no longer attached to the computer before running any of the scripts!
</details>

<details>
  <summary>Create your Encrypted Partition Recovery USB drive</summary>

  1. Attach one of your previously created factory ChromeOS Recovery USB drive to your forensic computer, which you have currently booted to Chromium OS using your Chromium OS live USB.

2. Run the bash script to turn the factory ChromeOS Recovery USB drive into an Encrypted Partition Recovery USB drive, using the command:“. /home/scripts/create_encrypted_partition_recovery_usb.sh” without the quotes. Make sure you have a space between the ‘.’ and /home/scripts/create_encrypted_partition_recovery_usb.sh.

3. You will be prompted to select the attached factory ChromeOS Recovery USB and then have the opportunity to choose the partition size to be created on the USB. The default partition size is 10GB and you can take the default unless you know you need a larger partition for capture of a very large amount of encrypted user data.

4. Read each prompt and/or information provided by the script. Confirm “Y” at each prompt in the script until the script ends.

5. The factory ChromeOS Recovery USB is now an Encrypted Partition Recovery USB to be used solely for the purpose of acquiring a decrypted logical backup of encrypted data on a Chromebook/Chromebox device for which you have a username and password.

6. Remove the USB drive and label the USB as your Encrypted Partition Recovery USB.
   ![image](https://github.com/Elinement/MSP/assets/73756572/fc733d24-9f7c-42a0-b35e-ef1db0cc642e)
7. Do not shutdown Chromium OS yet. Continue with the next section.
</details>

<details>
  <summary>Prepare your clone destination output USB hard drive</summary>
  1. You may, if desired and in certain circumstances, be cloning the internal HD of a "seized" Chromebook/Chromebox to your large capacity USB3.0 hard drive. You MUST first completely WIPE your large capacity USB hard drive using whatever method you choose before completing any further preparation steps, to ensure the destination drive contains no residual data.

2. After the destination USB drive is wiped, attach it to your forensic computer running Chromium OS from the previous section of this document.

3. Run the bash script to prepare the wiped destination USB drive so that it is ready to be cloned with the internal HD of your seized Chromebook/Chromebox. Use the command:“. /home/scripts/prep_evidence_drive.sh” without the quotes. Make sure you have a space between the ‘.’ and /home/scripts/prep_evidence_drive.sh.

4. When prompted by the script, select the number identified as your wiped destination USB drive.

5. You will be prompted to confirm that you wish to re-write new partitioning information to the selected disk. Hit “Y” or “y” to confirm and finish preparing the destination USB drive.

6. You may now disconnect your prepared destination USB drive, label the USB as your Evidence Destination USB, and shutdown Chromium OS.
   ![image](https://github.com/Elinement/MSP/assets/73756572/0abb6454-8cb7-4e54-b987-515571704a57)

</details>

<details>
  <summary>Performing the Encrypted Partition Recovery</summary>
  1.    Read all steps in this section in their entirety before you go through this process! There are certain steps that MUST be followed EXACTLY as explained!

  2. From a powered off Chromebook/Chromebox, place the device in “Recovery Mode”. Certain model Chromebooks require holding a keyboard sequence “ESC+Refresh” while powering on the Chromebook. Other models, such as Chromeboxes, have a physical recovery button/switch that must be pressed/switched while powering on the Chromebook. See further information under the “Enter Recovery Mode” section of this support page from Google. https://support.google.com/chromebook/answer/1080595?hl=en

![image](https://github.com/Elinement/MSP/assets/73756572/57a010f1-099a-4266-8d6c-1e5468f7463c)  
or  
![image](https://github.com/Elinement/MSP/assets/73756572/9b93f470-5957-4ecd-9383-dc2ad520b859)  
3. When powered on to Recovery Mode, you will see this on the screen saying “Please insert a recovery USB stick.”


</details>

# Credits
These scripts and images are from Daniel Dickerman's guide on Chromebook Forensic Acquisition.

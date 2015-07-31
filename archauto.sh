#!/bin/bash

#DISK="$@"
DISK="/dev/sda"

function do_stage_1 {
echo "Running Stage 1"

if [ ! -x "/sbin/parted" ]; then
    echo "This script requires /sbin/parted to run!" >&2
    exit 1
fi

## Begins of auto-parted part and format

parted -a optimal --script ${DISK} -- mktable gpt
parted -a none --script ${DISK} -- mkpart none 0 32MB
parted -a optimal --script ${DISK} -- mkpart ext4 32MB 256MB
parted -a optimal --script ${DISK} -- mkpart ext4 256MB 100%
parted -a optimal --script ${DISK} -- set 1 bios_grub on

mkfs.ext4 ${DISK}2
mkfs.ext4 ${DISK}3

##################################################################
# Stage 1, bootstrap partitions/filesystems and OS Base packages #
##################################################################
# Mount /
mount ${DISK}3 /mnt

# Make /boot mountpoint
mkdir /mnt/boot

# Mount /boot on previously made mountpoint
mount ${DISK}2 /mnt/boot

# Replace mirrorlist with known fast and good Swedish mirror
curl -s --data "country=NL&protocol=http&ip_version=4" https://www.archlinux.org/mirrorlist/ | sed 's/#Server/Server/g' > /etc/pacman.d/mirrorlist

# Bootstrap the Base OS packages (and grub)
pacstrap /mnt base base-devel grub openssh

cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

# Sync FS for consistency
sync

}
############################################
function do_stage_2 {

########################################################
# Stage 2, Chroot, Bootloader, Base Config, Mkinitcpio #
########################################################

# Configure and embed installed GRUB from pacstrap stage
arch-chroot /mnt grub-install --no-floppy ${DISK}
arch-chroot /mnt grub-mkconfig > /mnt/boot/grub/grub.cfg
# Generate appropriate fstab entries
genfstab /mnt >> /mnt/etc/fstab

#set hostname
echo "ArchBox" > /mnt/etc/hostname

# Configure Swedish Locale, language and keymaps
arch-chroot /mnt echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
arch-chroot /mnt echo "en_US ISO-8859-1" >> /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
arch-chroot /mnt echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
arch-chroot /mnt echo "KEYMAP=us" > /mnt/etc/vconsole.conf
arch-chroot /mnt echo "FONT=lat9w-16" >> /mnt/etc/vconsole.conf

# Enable SSHD and DHCP-Client for remote access
arch-chroot /mnt systemctl enable sshd
arch-chroot /mnt systemctl enable dhcpcd

}

do_stage_1
do_stage_2

# Sync before reboot
sync
# reboot into installed system
reboot
#exit

#!/bin/bash

#DISK="$@"
DISK="/dev/sda"

function do_stage_1 {
echo "Running Stage 1"

if [ ! -x "/sbin/parted" ]; then
    echo "This script requires /sbin/parted to run!" >&2
    exit 1
fi

#while true; do
#    read -p "Warning! This will partition and format any unformatted storage volumes! Are you sure? " yn
#    case $yn in
#        [Yy]* ) break;;
#        [Nn]* ) exit;;
#        * ) echo "Please answer yes or no.";;
#    esac
#done

## Begins of auto-parted part and format

parted -a optimal --script ${DISK} -- mktable gpt
parted -a none --script ${DISK} -- mkpart none 0 1MB
parted -a optimal --script ${DISK} -- mkpart ext2 1MB 128MB
parted -a optimal --script ${DISK} -- mkpart ext2 128MB 100%
parted -a optimal --script ${DISK} -- set 1 bios_grub on

mkfs.ext4 ${DISK}2
mkfs.ext4 ${DISK}3

#expect ${DISK}1 to be GRUB-GPT-BIOS COMPAT
#	${DISK}2 to be /boot
#	${DISK}3 to be /

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
echo 'Server = http://archlinux.dynamict.se/$repo/os/$arch' > /etc/pacman.d/mirrorlist

#echo '[xyne-any]' >> /etc/pacman.conf
#echo 'SigLevel = Required' >> /etc/pacman.conf
#echo 'Server = http://xyne.archlinux.ca/repos/xyne' >> /etc/pacman.conf

#pacman -Sy --noconfirm pacserve
#systemctl start pacserve.service
#pacman.conf-insert_pacserve > /tmp/pacman.conf
#cp /tmp/pacman.conf /etc/pacman.conf

# Bootstrap the Base OS packages (and grub)
pacstrap /mnt base grub dialog openssh

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
arch-chroot /mnt grub-install --target=i386-pc ${DISK}
arch-chroot /mnt grub-mkconfig > /mnt/boot/grub/grub.cfg
# Generate appropriate fstab entries
genfstab -U /mnt >> /mnt/etc/fstab

# Configure Swedish Locale, language and keymaps
arch-chroot /mnt echo "sv_SE.UTF-8 UTF-8" >> /mnt/etc/locale.gen
arch-chroot /mnt echo "sv_SE ISO-8859-1" >> /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
arch-chroot /mnt echo "LANG=sv_SE.UTF-8" > /mnt/etc/locale.conf
arch-chroot /mnt echo "KEYMAP=sv-latin1" > /mnt/etc/vconsole.conf

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

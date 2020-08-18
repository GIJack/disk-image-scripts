Arch In the Cloud
=================

This is how you create a VM template for cloud providers using:
* disk-image-scripts
* arch-install-scripts
* cloud-init + cloud-utils

1 - Create a Disk Image
-----------------------
init_image.sh <filename.img>

Use this to create an image, with partion and filesystem(ext4). You can set the
size of the image with -s.

2 - Mount the image
-------------------
make sure that $HOME/mnt exists as a directory. You can then

mount_image.sh mount <filename.img>

3 - Bootstrap Arch
------------------
Install Arch to the image with pacstrap from arch-install-scripts:

sudo pacstrap ~/mnt base linux nano vi cloud-init cloud-utils syslinux openssh


4 - Base configure
------------------
base system configuration, so the system is bootable. Uses arch-chroot from
arch-install-scripts.

Its also advisable to try this package that I also maintain from AUR:
https://aur.archlinux.org/packages/cloud-init-extra/

sudo arch-chroot ~/mnt

systemctl enable sshd systemd-networkd cloud-init-local cloud-init cloud-config \
cloud-final

syslinux-install-update -i -a -m

sed -i s/sda3/vda1/g /boot/syslinux/syslinux.cfg

nano /etc/mkinitcpio.conf

add this to MODULES=(): virtio virtio_pci virtio_blk virtio_net virtio_ring

mkinitcpio -p linux

exit


5 - Dismount
------------
umount and image and remove the look

mount_image.sh list # Get the loop device number -> N

mount_image.sh umount N

6 - Shrinkwrap
--------------
We get this ready by "shrink wrapping" or removing any excess space on the image

shrinkwrap_image.sh <filename.img>


After this, you have a valid, minimal Arch Template. Add your own files and
config in step 4.

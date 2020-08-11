# disk-image-scripts
A collection of shell scripts for working with raw disk image .img files with
bootable systems inside. We assume these files have been formated as raw disks.
It is also assumed that:
1. Each file is formated with fdisk and a parition table is added
2. there is a single partition that takes up the entire file
3. the filesystem is formated ext4t. We might support xfs or f2fs in the future

This is intended for installing Arch Linux systems in files instead of disks,
and working with and maintaining these installs. works hand in hand with
arch-chroot from install-scripts in Arch Linux.

This is particularly useful if making an image for the cloud or other virtual
machine systems.

Scripts:

mount_image.sh - mount or unmount a previously made image

image_shrinkwrap.sh - reduce an .img to its smallest possible size. Especially
for export.

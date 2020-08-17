# disk-image-scripts
A collection of shell scripts for working with raw disk image .img files with
bootable systems inside. Assumed that:
1. Formatted with an MBR paritioning scheme and boot record.
2. contains a single parition filling the entire drive, formated with a FS

System requirements:
1. Arch Linux
2. GNU Parted

Right now, only MBR partitioning and ext4 filesystem are supported. In the
future we may support GPT paritioning and xfs filesystems as well.

This is intended for installing Arch Linux systems in files instead of disks,
and working with and maintaining these installs. works hand in hand with
arch-chroot from install-scripts in Arch Linux.

This is particularly useful if making an image for the cloud or other virtual
machine systems.

Scripts:

mount_image.sh - mount or unmount a previously made image

shrinkwrap_image.sh - reduce an .img to its smallest possible size. Especially
for export.

init_image.sh - create a blank image file, formated with a single parition and a
filesystem

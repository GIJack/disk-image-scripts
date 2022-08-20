# disk-image-scripts

Generate virtual machine template images for the cloud, and tools for working
on .img files locally for upload.

Shell scripts for working with raw disk image .img files with bootable systems
inside. Assumed that:
1. Formatted with an MBR paritioning scheme and boot record.
2. contains a single parition filling the entire drive, formated with a FS

System requirements:
--------------------
1. Arch Linux
2. qemu (uses qemu-img resize)

Right now, only MBR partitioning and ext4 filesystem are supported. In the
future we may support GPT paritioning and xfs filesystems as well.

This is intended for installing Arch and Debian systems in files instead of disks,
and working with and maintaining these installs. works hand in hand with
arch-chroot from install-scripts in Arch Linux.

This is particularly useful if making an image for the cloud or other virtual
machine systems.

Support for RedHat is in the planning stage

Scripts:
--------
init\_image.sh - create a blank image file, formated with a single parition and a
filesystem

mount\_image.sh - mount or unmount a previously made image

gen\_cloud\_template.sh - generate a cloud virtual machine template images.
Designed for work with digital ocean, and programs like harbor-wave, but should
be convertable into an AMI for Amazon, but this has not been tested and not
supported. see --help for more information

shrinkwrap\_image.sh - reduce an .img to its smallest possible size. Especially
for export.

Instalation
-----------
There is a Makefile for GNU make with two options

make install

make remove

This should be self-explanitory

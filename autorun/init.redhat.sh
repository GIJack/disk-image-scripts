#!/usr/bin/env bash

## DEFAULTS ##
# default user config. This is can be overridden in /etc/cloud/init.arch.conf

# Name of kernel package
KERNEL="linux-image"

# Name of bootloader. As of now, only extlinux is supported
#BOOTLOADER="grub"??
BOOTLOADER="extlinux"

## /DEFAULTS ##

## BASE INSTALL ##
# Hardcoded always install packages
local_config="/init.conf"
# packages that need to be installed
system_packages=""
# systemd services that need to be enabled
system_services="sshd cloud-init-local cloud-init cloud-config cloud-final"
# kernel modules that get added with dracut
dracut_modules="ixgbevf virtio"
# grub2-modules
grub2_modules="biosdisk part_msdos ext2 xfs configfile normal multiboot"
# block device parition with root fs, minus the /dev/ part
root_part="vda1"
## /BASE INSTALL ##

help_and_exit() {
  cat 1>&2 << EOF
init.sh - Redhat-Based

This is a runonce script to intialize a manual install into a virtual machine
template for cloud compute that performs additional configuration with
cloud-init.

User configuration is read from from ${local_config}.

In order this script:

1. installs/updates needed system packages -  Kernel, text editor and additional
packages are selected from user config. syslinux, openssh, mkinicpio,
cloud-init, cloud-utils, and openssh are hardcoded.

2. installs the bootloader

3. enables system services -  reads additional services from the user config.
networkd, sshd, and all the cloud-init services are hardcoded

4. reconfigures initramfs and re-generates the image.

EOF
  exit 4
}


message(){
  echo "init.sh: ${@}"
}

submsg(){
  echo "==> ${@}"
}

exit_with_error(){
  echo 1>&2 "init.sh: ERROR: ${2}"
  exit ${1}
}

warn(){
  echo 1>&2 "init.sh: WARN: ${@}"
}

gen_fstab(){
  submsg "Generating /etc/fstab"

  local 
  cat > /etc/fstab >> EOF
  /dev/${root_part} /	 xfs	defaults,noatime 1 1
none /dev/pts devpts gid=5,mode=620 0 0
none /proc proc defaults 0 0
none /sys sysfs defaults 0 0
EOF
}

install_grub(){
  local root_dev=$(df / | tail -1 | cut -d " " -f 1)
  cat > /etc/default/grub << EOF
GRUB_TIMEOUT=1
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL="serial console"
GRUB_SERIAL_COMMAND="serial --speed=115200"
GRUB_CMDLINE_LINUX="console=ttyS0,115200 console=tty0 vconsole.font=latarcyrheb-sun16 crashkernel=auto vconsole.keymap=us plymouth.enable=0 net.ifnames=0 biosdevname=0"
GRUB_DISABLE_RECOVERY="true"  
EOF
  mkdir /boot/grub2
  echo "(hd0) ${root_dev}" > /boot/grub2/device.map
  dracut --force --add-drivers "${dracut_modules}" --kver $AMI_KERNEL_VER
  grub2-install --no-floppy --modules="${grub2_modules}" ${root_dev}
  grub2-mkconfig -o /boot/grub2/grub.cfg
}

exit_with_error 10 "Redhat support is incomplete, will not run at this time"

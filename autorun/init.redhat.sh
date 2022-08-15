#!/usr/bin/env bash

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

exit_with_error 10 "Redhat support is incomplete, will not run at this time"

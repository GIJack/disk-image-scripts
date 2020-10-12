#!/usr/bin/env bash

## DEFAULTS ##
# default user config. This is can be overridden in /etc/cloud/init.arch.local

# Name of kernel package
KERNEL="linux"

# Name of bootloader. As of now, only syslinux is supported
BOOTLOADER="syslinux"

## /DEFAULTS ##

## BASE INSTALL ##
# Hardcoded always install packages
local_config="/etc/cloud/init.arch.local"
# packages that need to be installed
system_packages="base cloud-init cloud-utils openssh mkinitcpio"
# systemd services that need to be enabled
system_services="systemd-networkd sshd cloud-init-local cloud-init cloud-config cloud-final"
# kernel modules that get added to /etc/mkinitcpio
initcpio_modules="virtio virtio_pci virtio_blk virtio_net virtio_ring"
# block device parition with root fs, minus the /dev/ part
root_part="vda1"
## /BASE INSTALL ##

help_and_exit() {
  cat 1>&2 << EOF
init.sh - Arch Linux

This is a runonce script to intialize a manual install into a virtual machine
template for cloud compute that performs additional configuration with
cloud-init.

User configuration is read from from ${local_config}.

In order this script:

1. installs/updates needed system packages -  Kernel, text editor and additional
packages are selected from user config. syslinux, openssh, mkinicpio,
cloud-init, cloud-utils, and openssh are hardcoded.

2. installs the syslinux bootloader

3. enables system services -  reads additional services from the user config.
networkd, sshd, and all the cloud-init services are hardcoded

4. reconfigures mkinitcpio and re-generates the image.

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

parse_environment(){
  # parse a key=pair shell enviroment file. NOTE all keys will be made UPPERCASE
  # variables. in parent script.

  local infile="${@}"
  local safe_config=$(mktemp)
  local key=""
  local value=""
  local -a file_lines
  local line=""
  
  [ -f "${infile}" ] || return 2 # infile is not a file
  # Now we have an array of file lines
  readarray file_lines < "${infile}" || return 1 # error proccessing

  for line in "${file_lines[@]}";do
    # Remove comments
    [[ -z "{$line}" || "${line}" == "#" ]] && continue
    line=$(cut -d "#" -f 1 <<< ${line} )

    # Split key and value from lines
    key=$(cut -d "=" -f 1 <<< ${line} )
    value=$(cut -d "=" -f 2 <<< ${line} )

    # Parse key. Make the Key uppercase, remove spaces and all non-alphanumeric
    # characters
    key="${key^^}"
    key="${key// /}"
    key="$(tr -cd "[:alnum:]" <<< $key)"

    # Parse value. Remove anything that can escape a variable and run code.
    value="$(tr -d ";|&()" <<< $value )"

    # Zero check. If after cleaning either the key or value is null, then
    # write nothing
    [ -z ${key} ] && continue
    [ -z ${value} ] && continue

    # write sanitized values to temp file
    echo "${key}=${value}" >> ${safe_config}
  done

  #Now, we can import the cleaned config and then delete it.
  source ${safe_config}
  rm -f ${safe_config}
}

install_packages() {
  submsg "Installing/Updated Base packages"
  pacman --noconfirm -Su ${system_packages} ${BOOTLOADER} ${KERNEL} ${EXTRAPACKAGES}
  return $?
}

install_syslinux() {
  submsg "Configuring Syslinux Bootloader"
  local -i exit_n=0
  sed -i s/sda3/${root_part}/g /boot/syslinux/syslinux.cfg || exit_n+=1
  sed -i s/initramfs-linux/initramfs-${KERNEL}/g /boot/syslinux/syslinux.cfg || exit_n+=1
  syslinux-install_update -i -a -m || exit_n+=1
  return ${exit_n}
}

enable_services() {
  submsg "Enabling Systemd Units"
  systemctl enable ${system_services} ${SYSTEMSERVICES}
  return $?
}

config_initcpio() {
  local -i exit_n=0
  submsg "Updating mkinicpio.conf"
  # add extra modules from local file
  initcpio_modules+=" "
  initcpio_modules+=${EXTRAINTMODULES}
  sed -i s/"MODULES=()"/"MODULES=(${initcpio_modules})"/g /etc/mkinitcpio.conf || exit_n+=1
  mkinitcpio -p ${KERNEL} || exit_n+=1
  return ${exit_n}
}

main() {
  local -i exit_code=0
  [[ $1 == "help" || $1 == "--help" ]] && help_and_exit
  message "Initalizing..."
  if [ -f "${local_config}" ];then
    parse_environment "${local_config}"
   else
    warn "${local_config} not found!, default is in /usr/share/cloud-init-extra/init.arch.local.default"
  fi
  install_packages || exit_with_error 1 "Could not install necessary packages needed for script to run. Please check install"
  case ${BOOTLOADER} in
   syslinux)
    install_syslinux || exit_code+=1
    ;;
   *)
    warn "Bootloader ${BOOTLOADER} is unsupported, NO INSTALLED BOOTLOADER CONFIGURED!"
    exit_code+=1
    ;;
  esac
  enable_services  || exit_code+=1
  config_initcpio  || exit_code+=1
  message "Done!"
  [ $exit_code -ne 0 ] && exit_with_error 1 "${exit_code} errrors, check above output"
}

main "${@}"

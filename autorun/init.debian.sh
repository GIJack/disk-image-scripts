#!/usr/bin/env bash

## DEFAULTS ##
# default user config. This is can be overridden in /etc/cloud/init.arch.conf

# Name of kernel package
KERNEL="linux-image"

# Name of bootloader. As of now, only syslinux is supported
#BOOTLOADER="grub"??

## /DEFAULTS ##

## BASE INSTALL ##
# Hardcoded always install packages
local_config="/init.conf"
# packages that need to be installed
system_packages="cloud-init cloud-initramfs-growroot cloud-guest-utils openssh-server initramfs-tools locales-all"
# systemd services that need to be enabled
system_services="networking ssh cloud-init-local cloud-init cloud-config cloud-final"
# kernel modules that get added to /etc/mkinitcpio
initcpio_modules="virtio virtio_pci virtio_blk virtio_net virtio_ring"
# block device parition with root fs, minus the /dev/ part
root_part="vda1"
## /BASE INSTALL ##

help_and_exit() {
  cat 1>&2 << EOF
init.sh - Debian-Based

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
  apt-get update -qy
  apt-get upgrade -qy ${system_packages} ${BOOTLOADER} ${KERNEL} ${EXTRAPACKAGES}
  return $?
}

# debian edition
install_extlinux() {
  local -i exit_n=0
  # Root partition detection. Assumes using a loop device with /dev/loop that
  # numbers partitions /dev/loop0p1 and such
  local mbr_file="/usr/lib/syslinux/mbr/mbr.bin"
  local root_mount=$(df / | tail -1 |cut -d " " -f 1) # location where / is mounted
  local N=${#root_mount} # count the characters in the string
  local root_part_n=${root_mount:${N}-1:1} # get the partition number
  local root_dev=${root_mount:0:-2} # /'s device.

  submsg "Configuring Extlinux Bootloader"
  
  apt install -y syslinux-common || return 1
  mkdir -p /boot/syslinux || return 1 # create syslinux dir
  cp /usr/lib/syslinux/modules/bios/* /boot/syslinux || exit_n+=1 # copy syslinux files
  mv /root/syslinux.cfg /boot/syslinux/syslinux.cfg || exit_n+=1 # set config file
  sfdisk -A ${root_dev} ${root_part_n} || exit_n+=1 # Mark partition as "active"
  dd if="${mbr_file}" of=${root_dev} bs=440 count=1 || exit+=1 # Install MBR
  extlinux -i /boot/syslinux || exit_n+=1 #Install rest of bootloader
  
  [ $exit_n -ne 0 ] && return 1
  return 0
}

enable_services() {
  submsg "Enabling Systemd Units"
  #work around because debian wants the sshd service named ssh and not sshd
  SYSTEMSERVICES=$(sed s/sshd/ssh/g <<< ${SYSTEMSERVICES})
  systemctl enable ${system_services} ${SYSTEMSERVICES}
  return ${?}
}

config_initramdisk() {
  submsg "Reconfiguring Kernel and Rebuilding Initial Ramdisk"
  local exit_n=0
  dpkg-reconfigure --frontend=noninteractive ${KERNEL} || exit_n+=${?}
  update-initramfs -u || exit_n+=${?}

  [ ${exit_n} -ne 0 ] && return 1
  return 0
}

config_misc() {
  submsg "Misc Config"
  touch /etc/machine-id
  # Use timezone module to set Timezone from config
  rm -f /etc/localtime
  ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
  if [ ${?} -ne 0 ];then
    warn "Could not set timezone: ${TIMEZONE}, check that it exists"
    return 1
  fi
}

run_user_script(){
  submsg "Running Local Script"
  local local_file="/init.local.sh"
  
  if [ ! -f ${local_file} ];then
    warn "No local init file: ${local_file}, skipping"
    return 0
  fi
  bash ${local_file}
  return ${?}
}

main() {
  local -i exit_code=0
  [[ $1 == "help" || $1 == "--help" ]] && help_and_exit
  message "Initalizing..."
  # set shell variables inside chroot, this should make this portable
  source /etc/profile
  if [ -f "${local_config}" ];then
    message "parsing ${local_config}"
    parse_environment "${local_config}"
   else
    warn "${local_config} does not exist, this should be auto-generated by gen_cloud_template.sh"
  fi
  
  dpkg-reconfigure --frontend=noninteractive ${BOOTLOADER}
  case ${BOOTLOADER} in
   *extlinux*)
    install_extlinux
    if [ ${?} -ne 0 ];then
      exit_code+=1
      warn "extlinux install failed"
    fi
    ;;
   *syslinux*)
    warn "Use extlinux for Debian instead of syslinux. Bootloader not configured"
    exit_code+=1
    ;;
   *)
    warn "Bootloader ${BOOTLOADER} is unsupported, NO INSTALLED BOOTLOADER CONFIGURED!"
    exit_code+=1
    ;;
  esac

  # now run hooks
  local item_list="enable_services config_initramdisk config_misc run_user_script"
  for item in $item_list;do
    ${item}
    if [ $? -ne 0 ];then
      exit_code+=1
      warn "${item} failed"
    fi
  done
  
  message "Done!"
  [ $exit_code -ne 0 ] && exit_with_error 1 "${exit_code} errrors, check above output"
}

main "${@}"

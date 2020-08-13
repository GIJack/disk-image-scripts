#!/usr/bin/env bash
#
# Shrink-wrap an image to its smallest possible size. see help
# Only works with ext4 and only works with single partitioned images
# For use with mount_image.sh
# error codes 0:Success 1:Operations Fail 2:Abort 4:Invalid User Input

# Defaults #
LOOP_DEV=loop1
PART_N=1
MOUNT_POINT="${HOME}/mnt"
ROOT_METHOD="sudo"
# /Defaults #

help_and_exit(){
  cat 1>&2 << EOF
shrinkwrap_image.sh:

"Shrink Wrap" a system image for export. Reduce an disk image file to
its smallest possible size.

WARNING: This tool makes the assumption:
1. There is one partition
2. The partition is ext4
3. It is a raw disk image

USAGE: shrinkwrap_image.sh <file.img>

EOF
  exit 4
}
message(){
  echo "shrinkwrap_image.sh: ${@}"
}

submsg(){
  echo "[+]	${@}"
}

warn(){
  echo 1>&2 "shrinkwrap_image.sh: WARN: ${@}"
}

exit_with_error(){
  echo 1>&2 "shrinkwrap_image.sh: ERROR: ${2}"
  exit ${1}
}

as_root(){
  # execute a command as root.
  case $ROOT_METHOD in
   sudo)
    sudo ${@}
    ;;
   pkexec)
    pkexec ${@}
    ;;
   uid)
    ${@}
    ;;
  esac
}

_setup-loop() {
  local -i local_exit=0
  local filename="${1}"
  submsg "Mounting ${filename} on /dev/${LOOP_DEV} on ${MOUNT_POINT}"
  as_root losetup -P ${LOOP_DEV} "${filename}" || local_exit+=1
  return ${local_exit}
}

_destroy-loop() {
  local -i local_exit=0
  submsg "Destroying /dev/${LOOP_DEV}"
  as_root losetup -d /dev/${LOOP_DEV} &> /dev/null || local_exit+=1
  return ${local_exit}
}

cleanup_abort_fail() {
  local message="${1}"
  as_root umount -f /dev/${LOOP_DEV}p${PART_N} &> /dev/null
  as_root losetup -D /dev/${LOOP_DEV}
  exit_with_error 2 "${message}"
}

_defrag() {
  local -i local_exit=0
  submsg "Defragment"
  as_root e2fsck -f /dev/${LOOP_DEV}p${PART_N} &> /dev/null #|| local_exit+=1
  as_root mount /dev/${LOOP_DEV}p${PART_N} "${MOUNT_POINT}" || local_exit+=1
  as_root e4defrag "${MOUNT_POINT}" &> /dev/null || local_exit+=1
  as_root umount /dev/${LOOP_DEV}p${PART_N} || local_exit+=1
  return ${local_exit}
}

_resize_part() {
  local -i local_exit=0
  local -i fs_size=0
  local -i fs_null_space=1048576 # space at the beginning of the drive before
                                 # the partition. 2048 sectors in bytes
  local -i part_end=0 # we need this in another function
  
  submsg "Shrinking Partition"
  ## Shrink the filesystem
  # Check first
  as_root e2fsck -fp /dev/${LOOP_DEV}p${PART_N}  &> /dev/null || local_exit+=1

  # Grab size reported directly fromr resize2fs
  fs_size=$( as_root resize2fs -M /dev/${LOOP_DEV}p${PART_N} 2> /dev/null | tail -2 | cut -d " " -f 7 )
  fs_size=$(( $fs_size * 4096 )) # convert 4k blocks to bytes
  disk_end=$(( $fs_size + $fs_null_space ))

  # Compute new end location for partition, and disk
  part_end=$(( ${fs_null_space} + ${fs_size} + 4096 ))
  disk_end=$(( ${part_end} + 512 ))
  # Resize partition. Stupid ugly hack that took all morning. GNU Parted
  # is a hot fucking mess. I am not sure whoever thought that this was
  # the best way of doing things or why the --script option doesn't
  # override all the confirm prompts
  # https://unix.stackexchange.com/questions/190317/gnu-parted-resizepart-in-script
  as_root parted ---pretend-input-tty /dev/${LOOP_DEV} &> /dev/null << EOF
resizepart
1
${part_end}B
Yes
EOF
  if [ ${?} -ne 0 ];then
    local_exit+=1
    warn "the nasty ugly parted hack shit itself, throwing error below"
  fi

  return ${local_exit}
}

_shrink_image() {
  local filename=${1}
  local -i filesize=${2}
  local -i local_exit=0

  submsg "Shrinking Image File"
  qemu-img resize -f raw --shrink ${filename} ${filesize} || local_exit+=1
  return ${local_exit}
}

main() {
  local -i exit_code=0
  local filename="${1}"
  [ -z "${filename}" ] && help_and_exit
  [ -f "${filename}" ] || exit_with_error 4 "${filename}, no such file!"

  local filesize=$(ls -sh "${filename}"| cut -d " " -f 1)
  local filesize_new=""
  declare -i disk_end=0
  
  message "Shrinking ${filename}(${filesize}) to its smallest possible size"
  as_root true || exit_with_error 4 "Could not authenticate, exiting..." # cache root password
  
  _setup-loop "${filename}" || exit_with_error 1 "Could not mount ${FILENAME}"
  trap "cleanup_abort_fail Interrupt Recived!" 1 2 3 9 15
  # This ensures all the data is in continous sectors, which allows us
  # to shrink the drive further
  _defrag
  if [ ${?} -ne 0 ];then
    warn "Defrag failed"
    exit_code+=1
  fi
  
  _resize_part || cleanup_abort_fail "Could not resize partition, you might need to clean up mount points locally"

  _shrink_image ${filename} ${disk_end}
  if [ ${?} -ne 0 ];then
    warn "Could not shrink image"
    exit_code+=1
  fi

  _destroy-loop
if [ ${?} -ne 0 ];then
    warn "Could not stop loop device /dev/${LOOP_DEV}, you should do this manually"
    exit_code+=1
fi

  # Final report
  filesize_new=$(ls -sh ${filename} | cut -d " " -f 1)
  if [ ${exit_code} -eq 0 ];then
    message "${filename} resized from ${filesize} to ${filesize_new}"
    exit 0
   else
    message "${filename} resized from ${filesize} to ${filesize_new}, however there where ${exit_code} errors. Review output above for more details"
    exit 1
  fi
  
}

main "${@}"
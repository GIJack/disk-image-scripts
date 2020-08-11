#!/usr/bin/env bash

COMMAND="${1}"
FILENAME="${2}"
LOOP_DEV=loop1
MOUNT_POINT="${HOME}/mnt"
ROOT_METHOD="sudo"

help_and_exit(){
  cat 1>&2 << EOF
mount_image.sh:

Mount and dismount qemu images

USAGE: mount_image.sh <command> <file.img>

Commands: mount umount ls

EOF
  exit 2
}
message(){
  echo "mount_image.sh: ${@}"
}

exit_with_error(){
  echo 1>&2 "mount_image: ERROR: ${2}"
  exit ${1}
}

as_root(){
  # execute a command as root.
  case $ROOT_METHOD in
   sudo)
    sudo ${@}
    ;;
   uid)
    ${@}
    ;;
  esac
}

_mount-img() {
  local -i local_exit=0
  message "Mounting ${FILENAME} on ${LOOP_DEV} on ${MOUNT_POINT}"
  as_root losetup -P ${LOOP_DEV} "${FILENAME}"
  local_exit+=${?}
  as_root mount /dev/${LOOP_DEV}p1 ${MOUNT_POINT}
  local_exit+=${?}
  return ${local_exit}
}

_umount-img() {
  local -i local_exit=0
  message "UnMounting ${mount_point} on ${loop_dev}"
  as_root umount ${MOUNT_POINT}
  local_exit+=${?}
  as_root losetup -d /dev/${LOOP_DEV}
  local_exit+=${?}
  return ${local_exit}
}

_list_mounts(){
  exit_with_error 4 "not implemented yet"
}

main() {
  case ${COMMAND} in
    mount)
      [ -z ${FILENAME} ] && help_and_exit
      _mount-img || exit_with_error 1 "Could not mount ${FILENAME}"
      ;;
    umount)
      _umount-img || exit_with_error 1 "Could Not unmount ${MOUNT_POINT}"
      ;;
    ls)
      list-mounts || exit_with_error 1 "Couldn't list mounts???"
      ;;
    *)
      help_and_exit
      ;;
  esac
}

main "${@}"

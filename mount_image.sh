#!/usr/bin/env bash
#
#
COMMAND="${1}"
FILENAME="${2}"
LOOP_DEV=$(losetup -f)
PART_N=1
MOUNT_POINT="${HOME}/mnt"
ROOT_METHOD="sudo"

help_and_exit(){
  cat 1>&2 << EOF
mount_image.sh:

Mount and dismount raw disk images. assumes a single parition in the
file. n is the number of the loop device, as shown in list. An image
needs to be a paritioned disk image

USAGE: mount_image.sh <command> [file.img|n]

Commands: mount umount list

    mount: mount_image mount <filename.img>
    
    umount: mount_image.sh umount <n>

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

as_root() {
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

_mount-img() {
  local -i local_exit=0
  message "Mounting ${FILENAME} on ${LOOP_DEV} on ${MOUNT_POINT}"

  as_root losetup -P ${LOOP_DEV} "${FILENAME}" || local_exit+=1
  as_root mount ${LOOP_DEV}p${PART_N} ${MOUNT_POINT} || local_exit+=1

  return ${local_exit}
}

_umount-img() {
  local -i local_exit=0
  LOOP_DEV=/dev/loop${1}

  message "UnMounting ${MOUNT_POINT} from ${LOOP_DEV}"

  as_root umount ${MOUNT_POINT} || local_exit+=1
  as_root losetup -d ${LOOP_DEV} || local_exit+=1

  return ${local_exit}
}

_list_mounts() {
  local -i local_exit=0
  local loop_names=( $(losetup -a |cut -d ":" -f 1) )
  local loop_imgs=( $(losetup -a |cut -d ":" -f 3) )

  local -i item=0
  local n=${#loop_names[@]}
  for ((i=0; $i < $n ; i+=1));do
    j=$((${#item}-1))
    loop_names[${i}]=${i:${j}:1}
  done
  
  message "Mounted Images:"
  local -i item=0
  local n=${#loop_imgs[@]}
  for ((i=0; $i < $n ; i+=1));do
    echo "${loop_names[$i]} : ${loop_imgs[$i]}"
  done
}

main() {
  case ${COMMAND} in
    mount)
      [ -z ${FILENAME} ] && help_and_exit
      _mount-img || exit_with_error 1 "Could not mount ${FILENAME}"
      ;;
    umount)
      [ -z ${FILENAME} ] && help_and_exit
      _umount-img ${FILENAME} || exit_with_error 1 "Could Not unmount ${MOUNT_POINT}"
      ;;
    list)
      _list_mounts || exit_with_error 1 "Couldn't list mounts???"
      ;;
    *)
      help_and_exit
      ;;
  esac
}

main "${@}"

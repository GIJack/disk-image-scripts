#!/usr/bin/env bash
#
# Mount a disk img(.img) See help below
#
# error codes 0:Success 1:Operations Fail 2:Abort 4:Invalid User Input
PART_N=1
MOUNT_POINT="${HOME}/mnt"
ROOT_METHOD="sudo"

help_and_exit(){
  cat 1>&2 << EOF
mount_image.sh:

Mount and dismount raw disk images. assumes a single parition in the
file. n is the number of the loop device, as shown in list. An image
needs to be a paritioned disk image.

Default mountpoint is $HOME/mnt. see -m option below

USAGE: mount_image.sh <-switches> [command] [file.img|n]

COMMANDS: mount umount list

	mount: mount_image.sh mount <filename.img>
    
	umount: mount_image.sh umount <n>
    
	list: list mounted images. gives Numbers <n> to use with umount
    
SWITCHES:

	-m, --mount-point	Specificy directory to use as mountpoint,
				default is $HOME/mnt

EOF
  exit 4
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
  local filename="${1}"
  local loop_dev=$(as_root losetup -f)
  message "Mounting ${filename} on ${loop_dev} on ${MOUNT_POINT}"
  [ -z "${MOUNT_POINT}" ] && exit_with_error 4 "No mountpoint specified with -m see --help"
  [ -d "${MOUNT_POINT}" ] || exit_with_error 4 "${MOUNT_POINT} is not a directory, exiting!"
  as_root losetup -P ${loop_dev} "${filename}" || local_exit+=1
  as_root mount ${loop_dev}p${PART_N} ${MOUNT_POINT} || local_exit+=1

  return ${local_exit}
}

_umount-img() {
  local -i local_exit=0
  index=${1}
  local loop_dev=/dev/loop${index}

  message "UnMounting ${MOUNT_POINT} from ${loop_dev}"

  as_root umount -Rf ${loop_dev}p${PART_N} || local_exit+=1
  as_root losetup -d ${loop_dev} || local_exit+=1

  return ${local_exit}
}

_list_mounts() {
  local -i local_exit=0
  local loop_names=( $(losetup -a |cut -d ":" -f 1) )
  local loop_imgs=( $(losetup -a |cut -d ":" -f 3) )

  local -i item=0
  local n=${#loop_names[@]}
  # reduce loop device names to numbers
  for ((i=0; $i < $n ; i+=1));do
    j=$(( ${#loop_names[$i]} - 1))
    loop_names[${i}]=${loop_names[${i}]:${j}:1}
  done
  
  message "Mounted Images:"
  local -i item=0
  local n=${#loop_imgs[@]}
  for ((i=0; $i < $n ; i+=1));do
    echo "${loop_names[$i]} : ${loop_imgs[$i]}"
  done
}

switch_checker() {
  PARMS=""
  while [ ! -z "${1}" ];do
   case "$1" in
    -\?|--help)
     help_and_exit
     ;;
    -m|--mount-point)
     MOUNT_POINT="${2}"
     shift
     ;;
    *)
     PARMS+="${1} "
     ;;
   esac
   shift
  done
}

main() {
  local command="${1}"
  case ${command} in
    mount)
      local filename="${2}"
      [ -z ${filename} ] && help_and_exit
      _mount-img "${filename}" || exit_with_error 1 "Could not mount ${filename}"
      ;;
    umount)
      local -i loop_index=${2}
      [ -z ${loop_index} ] && help_and_exit
      _umount-img ${loop_index} || exit_with_error 1 "Could Not unmount ${MOUNT_POINT}"
      ;;
    list)
      _list_mounts || exit_with_error 1 "Couldn't list mounts???"
      ;;
    *)
      help_and_exit
      ;;
  esac
}
switch_checker "${@}"
main ${PARMS}

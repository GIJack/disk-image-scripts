#!/usr/bin/env bash
# Initialize an .img file with a single partition and formated.

# Needs GNU Parted

# Defaults #
# Filesystem to use. At this time, only ext4 is supported
FS_TYPE="ext4"
# Image Size, in Megabytes
IMG_SIZE=20480 # 20GB
# bytestream to use for initial creation. Defaults to all zeros
FILL_SRC=/dev/zero

LOOP_DEV=loop1
PART_N=1
MOUNT_POINT="${HOME}/mnt"
ROOT_METHOD="sudo"
# /Defaults #

help_and_exit() {
  cat 1>&2 << EOF
init_image.sh:

Create an disk .img file, with a single parition and a file system. Creates a
file of an arbitrary size, formats it with the ext4 filesystem. Takes one
parameter, filename.

	USAGE:
	
	init_image [-s <size>] <filename.img>
	
	OPTIONS:
	
	-s,--size	Size of image, in Megabytes

EOF
  exit 4
}
message(){
  echo "init_image.sh: ${@}"
}

submsg(){
  echo "[+]	${@}"
}

exit_with_error(){
  echo 1>&2 "init_image.sh: ERROR: ${2}"
  exit ${1}
}

warn(){
  echo 1>&2 "init_image.sh: WARN: ${@}"
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

switch_checker() {
  while [ ! -z "$1" ];do
   case "$1" in
    --help|-\?)
     help_and_exit
     ;;
    -s|--size)
     IMG_SIZE="${2}"
     shift
     ;;
    *)
     PARMS+="${1}"
     ;;
   esac
   shift
  done
}

abort_cleanup() {
  rm "${OUTFILE}"
  as_root losetup -d /dev/${LOOP_DEV} &> /dev/null
  exit_with_error 2 "INTERRUPT: ABORT!"
}

_setup-loop() {
  local -i local_exit=0
  submsg "Setting up loop: ${OUT_FILE} on /dev/${LOOP_DEV} "
  as_root losetup -P ${LOOP_DEV} "${OUT_FILE}" || local_exit+=1
  return ${local_exit}
}

_destroy-loop() {
  local -i local_exit=0
  submsg "Destroying /dev/${LOOP_DEV}"
  as_root losetup -d /dev/${LOOP_DEV} &> /dev/null || local_exit+=1
  return ${local_exit}
}

_create_blank_file() {
  # Generate a blank file of arbitrary size
  local -i local_exit=0
  local blocksize="1024k" # 1 Megabyte
  
  submsg "Generating Blank file ${IMG_SIZE}M long"
  dd if="${FILL_SRC}" of="${OUT_FILE}" bs=${blocksize} count=${IMG_SIZE} status=progress || local_exit+=1
  
  return ${local_exit}
}

_partition() {
  # Create partition
  local -i local_exit=0
  local label="msdos"
  local -i offset=2048 #first 2048 sectors
  
  submsg "Partitioning image"
  as_root parted --script /dev/${LOOP_DEV} mklabel ${label} || local_exit+=1
  as_root parted --script /dev/${LOOP_DEV} mkpart primary ${FS_TYPE} ${offset}S -- -1 || local_exit+=1
  
  return ${local_exit}
}

_format() {
  # format with filesystem
  local -i local_exit=0
  as_root mkfs -t ${FS_TYPE} /dev/${LOOP_DEV}p${PART_N} &> /dev/null|| local_exit+=1
  
  return ${local_exit}
}

main() {
  OUT_FILE="${@}"
  local -i errors=0
  [ -z ${OUT_FILE} ] && help_and_exit
  trap "abort_cleanup" 1 2 3 9 15

  message "Making ${IMG_SIZE}M image file ${OUT_FILE}"
  as_root true # get root

  _create_blank_file || exit_with_error 1 "Could Not Generate Blank File, Exiting"
  
  _setup-loop || exit_with_error 1 "Could Not Set Up Loop Device, Exiting"
  
  _partition || exit_with_error 1 "Could Not Generate Paritions in ${OUTFILE}, Exiting"
  
  _format || exit_with_error 1 "Formatting Failed, Exiting"
  
  _destroy-loop
  if [ ${?} -ne 0 ];then
    "Couldn't remove loop device. Clean up mantually" 
    errors+=1
  fi
}

PARMS=""
switch_checker "${@}"
main "${PARMS}"

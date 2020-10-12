#!/usr/bin/env bash
#
# Generate a cloud template image using the rest of disk-image-scripts
# see --help for more information. As of now it only generates Arch
# Linux systems from Arch Linux. We hope to rectify that in the future.
# At least run on any GNU(assume coreutils) system.
#
# Exit codes 0-Success, 1-command failure, 2-invalid input, 4-help message

# Defaults #

PART_N=1
MOUNT_POINT="$(mktemp -d)"
ROOT_METHOD="sudo"
BASE_IMAGE="base-install.img"
TEMPLATE_INDEX="template.rc"
IMGSIZE=20480 # 20GB
BASE_PACKAGES="base cloud-init cloud-utils openssh mkinitcpio"
SCRIPT_BASE_DIR="/usr/share/disk-image-scripts/"

# /Defaults #

help_and_exit() {
  cat 1>&2 << EOF
gen_template_image.sh:

Generate an Cloud Template Image.(Based on Arch Linux), based on a
profile.


	USAGE:
	gen_template_image.sh [command] <arguments>

	COMMANDS:
	
	help			This message.

	init-template		Generate blank profile. rootoverlay/ directory
				and default template.rc. If no argument is
				given, \$PWD is used. Otherwise argument is
				directory path.
				
	init-image		Generate an install of Arch in an image in a
				file named 'base-install.img'. Takes an optional
				argument, a directory path. If none is specified
				then \$PWD is used. This image needs to be in
				profile path
				
	update-image		Update the packages of of Arch Image. Runs
				pacman -Syu.
				
	image-shell		Open a shell on the Arch Image. NOTE:
				rootoverlay is not applied. commands that
				require these files won't work.

	
	compile-template	Generates usable Cloud VM Template based on
				metadata, overlay. Filename will be based on
				metadata from template.rc

	PROFILE:
	Set directory and file structure with metadata and a root overlay
	applied over a base install of Arch Linux.
    
	==> FILES:
	    template.rc  - file with metadata. see man 5 template_rc for more
	    information
	
	    rootoverlay/ - directory with a root overlay. This gets applied on
	    top of base install. Will overwrite any file that exists.
	    
	    rootoverlay/etc/cloud/int.arch.local - base configuration script
	    with list of packages, system services and kernel modules loaded by
	    mkinitcpio.
EOF
  exit 4
}

message() {
  echo "gen_template_image.sh: ${@}"
}

submsg() {
  echo "==>	${@}"
}

exit_with_error() {
  echo 1>&2 "gen_template_image.sh: ERROR: ${2}"
  exit ${1}
}

warn() {
  echo 1>&2 "gen_template_image.sh: WARN: ${@}"
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
parse_environment(){
  # parse a key=pair shell enviroment file. NOTE all keys will be made UPPERCASE
  # variables. in parent script.
  local infile="${@}"
  local safe_config=$(mktemp)
  local key=""
  local value=""

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
    [ -z $value ] && continue

    # write sanitized values to temp file
    echo "${key}=${value}" >> ${safe_config}
  done

  #Now, we can import the cleaned config and then delete it.
  source ${safe_config}
  rm -f ${safe_config}
}

is_template(){
  # Check if directory is template. if no directory is specified use $PWD
  # returns 0 if True, 1 if False
  local target="${1}"
  [ -z $"{target}" ] && return 1
  # check to make sure nessecary files exist
  [ ! -d "${target}" ] && return 1
  [ ! -f "${target}/${TEMPLATE_INDEX}" ] && return 1
  [ ! -d "${target}/rootoverlay" ] && return 1

  # check config for bare min config
  parse_environment "${target}/template.rc"
  # Metadata
  [[ -z ${PROJECTNAME} || -z ${PROJECTVER} || -z ${PROJECTARCH} ]] && return 1
  # System
  [[ -z ${KERNEL} || -z ${BOOTLOADER} || -z ${SYSTEMSERVICES} ]] && return 1
  [[ -z ${EXTRAPACKAGES} || -z ${EXTRAINTMODULES} ]] && return 1
  
  # If nothing fails, check passes
  return 0
}

#--- Commands ---#
_init_template() {
  # Create new template.

  if is_template "${TARGET}";then
    exit_with_error 2 "${TARGET} is already a template, exiting..."
   elif [[ -f "${target}" || -c "${target}" || -b "${target}" || -p "${target}" ]];then
     exit_with_error 2 "${TARGET} exists as non-directory file or object, fail!"
   elif [ -d "${TARGET}" ];then
    warn "${TARGET} exists as a directory, but not a profile, initializing anyway"
  fi
  cp -ra "${SCRIPT_BASE_DIR}/default_template/*" "${TARGET}" || exit_with_error 1 "Couldn't copy files, template initialization failed!"
}

_init_image() {
  local target="${PWD}"
  local mount_point="$(mktemp -d)"
  local mount_dev=""
  local mount_target=""

  parse_environment "${target}/${TEMPLATE_INDEX}" || exit_with_error 1 "Could not parse ${TEMPLATE_INDEX}, fail"
  init_image.sh -s ${IMGSIZE} "${target}/${BASE_IMAGE}" || exit_with_error 1 "Image initalization threw a code, quitting."

  mount_image.sh mount -m "${mount_point}" "${target}/${BASE_IMAGE}" || exit_with_error 1 "Could not mount on ${mount_point}, quitting."
  mount_dev=$(grep "${mount_point}" /proc/mounts| cut -d " " -f 1)
  mount_target=${mount_dev: -1}

  pacstrap "${mount_point}"${KERNEL} ${BOOTLOADER} ${BASE_PACKAGES} ${EXTRAPACKAGES} || exit_with_error 1 "Base install failed. Please check output."
  mount_image umount ${mount_target} || warn "Unmount failed, please check"
  rmdir ${mount_point}
}

_update_image(){
  # Patch the base install, using pacman.
  _image_shell "pacman -Syu"
}

_image_shell(){
  # open a shell in a chroot in the installed image. Optionally run
  # command in said shell.
  local mount_point="$(mktemp -d)"
  local mount_dev=""
  local mount_target=""
  [ ! -z "${1}" ] && local command="${1};exit"

  [ ! -f "${TARGET}/${BASE_IMAGE}" ] || exit_with_error 1 "Base install cannot be found. perhaps you forgot to init-image?"

  # Set up mount and get unmount data
  mount_image.sh mount -m "${mount_point}" "${TARGET}/${BASE_IMAGE}" || exit_with_error 1 "Could not mount on ${mount_point}, quitting."
  mount_dev=$(grep "${mount_point}" /proc/mounts| cut -d " " -f 1)
  mount_target=${mount_dev: -1}

  # Run command
  if [ -z "${command}" ];then
    as_root arch-chroot "${mount_point}"
   else
    as_root arch-chroot "${mount_point}" "${command}"
  fi
  
  # Cleanup
  mount_image umount ${mount_target} || warn "Unmount failed, please check"
  rmdir ${mount_point}
}
#/--- Commands ---/#

main() {

  # Step one, resolve command and target
  TARGET="${PWD}"
  SCRIPT_CMD="${1}"
  [ ! -z "${2}" ] TARGET="${2}"

  # First parameter is subcommand
  case ${SCRIPT_CMD} in
   init-template)    
    _init_template
    ;;
   init-image)
    is_template ${TARGET} || exit_with_error 1 "${TARGET} is not a valid profile, quitting"
    _init_image
    ;;
   image-shell)
    is_template ${TARGET} || exit_with_error 1 "${TARGET} is not a valid profile, quitting"
    _image_shell
    ;;
   compile-template)
    exit_with_error 2 "Work in progress"
    ;;
   *)
    help_and_exit
    ;;
  esac

  
}

main "${@}"

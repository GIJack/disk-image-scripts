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
ROOT_METHOD="sudo"
BASE_IMAGE="base-install.img"
TEMPLATE_INDEX="template.rc"
IMGSIZE=20480 # 20GB
BASE_PACKAGES="base cloud-init cloud-guest-utils openssh mkinitcpio"
SCRIPT_BASE_DIR="/usr/share/disk-image-scripts"
PACKAGE_LIST_FILE="addedpacks"
COMPRESS_IMAGE="Y"
TIMEZONE="UTC"
# /Defaults #

BOLD="$(tput bold)"
NOCOLOR="$(tput sgr0)"

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
	    
	    rootoverlay/etc/cloud/int.arch.conf - base configuration script
	    with list of packages, system services and kernel modules loaded by
	    mkinitcpio.
EOF
  exit 4
}

message() {
  echo "gen_template_image.sh: ${@}"
}

submsg() {
  echo "===>	${@}"
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
    [ -z "${key}" ] && continue
    [ -z "${value}" ] && continue

    # write sanitized values to temp file
    echo "${key}=${value}" >> ${safe_config}
  done

  #Now, we can import the cleaned config and then delete it.
  source ${safe_config}
  rm -f ${safe_config}
}

parse_package_file() {
   # inputs a filename with a list of packages, one per line, # comment
   # no space
   local in_file="${1}"
   
   packages="$(cut -d '#' -f 1 < ${in_file})"
   echo ${packages}
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
  [[ -z ${KERNEL} || -z ${BOOTLOADER} ]] && return 1
  
  # If nothing fails, check passes
  return 0
}

#--- Commands ---#
_init_template() {
  # Create new template.
  message "Initializing cloud image template at ${TARGET}"
  if is_template "${TARGET}";then
    exit_with_error 2 "${TARGET} is already a template, exiting..."
   elif [[ -f "${target}" || -c "${target}" || -b "${target}" || -p "${target}" ]];then
     exit_with_error 2 "${TARGET} exists as non-directory file or object, fail!"
   elif [ -d "${TARGET}" ];then
    warn "${TARGET} exists as a directory, but not a profile, initializing anyway"
   else
    mkdir "${TARGET}"
  fi
  cp -ra "${SCRIPT_BASE_DIR}/default_template/"* "${TARGET}" || exit_with_error 1 "Couldn't copy files, template initialization failed!"
}

_init_image() {
  # generate the base image. download and install all packages into .img file
  local mount_point="$(mktemp -d)"
  local mount_dev=""
  local mount_target=""
  local packages_from_file=""
  [ -f ${PACKAGE_LIST_FILE} ] && packages_from_file=$( parse_package_file "${TARGET}/${PACKAGE_LIST_FILE}" )

  message "Performing Initial Install"
  parse_environment "${TARGET}/${TEMPLATE_INDEX}" || exit_with_error 1 "Could not parse ${TEMPLATE_INDEX}, fail"

  # If install exists, delete it first
  [ -f "${TARGET}/${BASE_IMAGE}" ] && rm -f "${TARGET}/${BASE_IMAGE}"
  init_image.sh -s ${IMGSIZE} "${TARGET}/${BASE_IMAGE}" || exit_with_error 1 "Image initalization threw a code, quitting."

  mount_image.sh mount -m "${mount_point}" "${TARGET}/${BASE_IMAGE}" || exit_with_error 1 "Could not mount on ${mount_point}, quitting."
  mount_dev=$(grep "${mount_point}" /proc/mounts| cut -d " " -f 1)
  mount_target=${mount_dev: -3:1}

  as_root pacstrap "${mount_point}" ${KERNEL} ${BOOTLOADER} ${BASE_PACKAGES} ${EXTRAPACKAGES} ${packages_from_file} || exit_with_error 1 "Base install failed. Please check output."

  mount_image.sh umount ${mount_target} || warn "Unmount failed, please check"
  rmdir "${mount_point}"
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
  local command=""
  [ ! -z "${1}" ] && command="${1}"

  [ ! -f "${TARGET}/${BASE_IMAGE}" ] && exit_with_error 1 "Base install cannot be found. perhaps you forgot to init-image?"
  
  # Set up mount and get unmount data
  mount_image.sh mount -m "${mount_point}" "${TARGET}/${BASE_IMAGE}" || exit_with_error 1 "Could not mount on ${mount_point}, quitting."
  mount_dev=$(grep "${mount_point}" /proc/mounts| cut -d " " -f 1)
  mount_target=${mount_dev: -3:1}

  # Run command
  if [ -z "${command}" ];then
    message "Opening shell in base install"
    as_root arch-chroot "${mount_point}"
   else
    message "Running ${command} in base install"
    as_root arch-chroot "${mount_point}" "${command}"
  fi
  
  # Cleanup
  mount_image.sh umount ${mount_target} || warn "Unmount failed, please check"
  rmdir ${mount_point}
}

_compile_template(){
  ## Put everything together into a completed template
  # We can update this later with a better name from metadata
  local mount_point=""
  local mount_dev=""
  local mount_target=""
  local outfile_generic="generic_arch_template.img"
  local outfile_name=""
  # first, read the environment file
  parse_environment "${TARGET}/${TEMPLATE_INDEX}" || exit_with_error 1 "Could not parse ${TEMPLATE_INDEX}, fail"

  ## Generate output file name
  # Generate Slug from project name.
  if [[ "${PROJECTNAME}" != "Unknown Arch Project" || "${PROJECTNAME}" != "None" || "${PROJECTNAME}" != "Unknown" || "${PROJECTNAME}" != "" ]];then
    PROJECT_SLUG="${PROJECTNAME,,}"
    PROJECT_SLUG="${PROJECT_SLUG// /}"
    PROJECT_SLUG="$(tr -cd "[:alnum:]" <<< $PROJECT_SLUG)"
    outfile_name="${PROJECT_SLUG}_"
    # Add OS archecture
    [[ ! -z ${PROJECTARCH} && ${PROJECTARCH} != "any" ]] && outfile_name+="${PROJECTARCH}_"
    # Project Version
    if [[ ! -z ${PROJECTVER} && ${PROJECTVER} -ne 0 && ${PROJECTVER} -eq ${PROJECTVER} ]];then
      outfile_name+="${PROJECTVER}_"
     else
      # Datestamp. If there is no version, use a datestamp, ArchLinux style
      outfile_name+="$(date +%Y%m%d)_"
    fi
    # removing trailing "_"
    [ ${outfile_name: -1} == "_" ] && outfile_name=${outfile_name:0:-1}
    # add .img suffix
    outfile_name+=".img"
   else
    outfile_name="${outfile_generic}"
  fi

  ## Generate final init.arch.local
  touch "${TARGET}/init.arch.conf" || exit_with_error 1 "Could not write to target, please check permissions."
  cat > "${TARGET}/init.arch.conf" << EOF
KERNEL="${KERNEL}"
BOOTLOADER="${BOOTLOADER}"
SYSTEMSERVICES="${SYSTEMSERVICES}"
EXTRAPACKAGES="${EXTRAPACKAGES}"
EXTRAINTMODULES="${EXTRAINITMODULES}"
TIMEZONE="${TIMEZONE}"
EOF

  ## Start the work
  message "Compiling template: ${outfile_name}"
  as_root true # get root with sudo
  # Make output file
  submsg "Copying base image to output image"
  cp "${TARGET}/${BASE_IMAGE}" "${TARGET}/${outfile_name}" || exit_with_error 1 "couldn't make output file, check available disk space"
  # Set up mount and get unmount data
  mount_point="$(mktemp -d)"
  mount_image.sh mount -m "${mount_point}" "${TARGET}/${outfile_name}" || exit_with_error 1 "Could not mount on ${mount_point}, quitting."
  mount_dev=$(grep "${mount_point}" /proc/mounts| cut -d " " -f 1)
  mount_target=${mount_dev: -3:1}

  # copy template
  submsg "Copying Overlay..."
  if [ -d "${TARGET}"/rootoverlay/ ];then
    as_root cp -r "${TARGET}"/rootoverlay/* "${mount_point}/" || warn "Copying root template threw a code, check it"
  fi
  as_root cp "${SCRIPT_BASE_DIR}/init.arch.sh" "${mount_point}" || warn "Could not copy initialization script to chroot!"
  as_root cp "${TARGET}/init.arch.conf" "${mount_point}" || exit_with_error 1 "Could not copy initialization config to chroot!"

  # initialize with script
  submsg "Running Initalization Script..."
  as_root arch-chroot "${mount_point}" "bash /init.arch.sh" || warn "Initialization failed!"
  
  # Cleanup
  submsg "Cleanup"
  as_root rm -f "${mount_point}/init.arch.sh"
  as_root rm -f "${mount_point}/init.arch.conf"
  mount_image.sh umount ${mount_target} || warn "Unmount failed, please check"
  rmdir "${mount_point}" || warn "Could not delete temporary mountpoint directory"
  rm -f "${TARGET}/init.arch.conf"

  # Shrinkwrap
  
  if [ ${COMPRESSIMAGE} == "Y" ];then
    submsg "Shrinkwrapping..."
    if [ -z "${COMPRESS_OPTS}" ];then
       shrinkwrap_image.sh  "${TARGET}/${outfile_name}" || warn "Shrinkwrap threw a code"
      else
       shrinkwrap_image.sh "${TARGET}/${outfile_name}" || warn "Shrinkwrap threw a code"
    fi
    
    submsg "Re-Initializing Syslinux"
    mount_point="$(mktemp -d)"
    mount_image.sh mount -m "${mount_point}" "${TARGET}/${outfile_name}" || exit_with_error 1 "Could not mount on ${mount_point}, quitting."
    mount_dev=$(grep "${mount_point}" /proc/mounts| cut -d " " -f 1)
    mount_target=${mount_dev: -3:1}
    as_root arch-chroot "${mount_point}" "syslinux-install_update -i -a -m" || warn "syslinux re-initialization failed"

    #Cleanup again
    mount_image.sh umount ${mount_target} || warn "Unmount failed, please check"
    rmdir "${mount_point}" || warn "Could not delete temporary mountpoint directory"

    # compressing final image
    submsg "Compressing Image"
    gzip ${COMPRESSOPTS} "${TARGET}/${outfile_name}"
  fi
  submsg "Done!"
}

#/--- Commands ---/#

main() {

  # Step one, resolve command and target
  TARGET="${PWD}"
  SCRIPT_CMD="${1}"
  [ ! -z "${2}" ] && TARGET="${2}"

  # Step two, run subcommand
  # First parameter is subcommand
  case ${SCRIPT_CMD} in
   init-template)    
    _init_template
    ;;
   init-image)
    is_template "${TARGET}" || exit_with_error 1 "${TARGET} is not a valid profile, quitting"
    _init_image
    ;;
   update-image)
    is_template "${TARGET}" || exit_with_error 1 "${TARGET} is not a valid profile, quitting"
    _update_image
    ;;
   image-shell)
    is_template "${TARGET}" || exit_with_error 1 "${TARGET} is not a valid profile, quitting"
    _image_shell "${@:3}"
    ;;
   compile-template)
    is_template "${TARGET}" || exit_with_error 1 "${TARGET} is not a valid profile, quitting"
    _compile_template
    ;;
   *)
    help_and_exit
    ;;
  esac

  exit 0
}

main "${@}"

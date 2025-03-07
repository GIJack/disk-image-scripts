#!/usr/bin/env bash
#
# Generate a cloud template image using the rest of disk-image-scripts
# see --help for more information. As of now it only generates Arch
# Linux systems from Arch Linux. We hope to rectify that in the future.
# At least run on any GNU(assume coreutils) system.
#
# Exit codes 0-Success, 1-operational error, 2-invalid input, 4-help message

# Defaults #

PART_N=1
ROOT_METHOD="sudo"
BASE_IMAGE="base-install.img"
TEMPLATE_INDEX="template.rc"
IMGSIZE=20480 # 20GB
ARCH_BASE_PACKAGES="base cloud-init cloud-guest-utils openssh mkinitcpio"
DEB_BASE_PACKAGES="cloud-init cloud-initramfs-growroot cloud-guest-utils openssh-server initramfs-tools locales-all"
# redhat is wierd. groups and packages are installed seperately
REDHAT_BASE_PACKAGES="openssh-server cloud-init"
REDHAT_BASE_GROUPS="Base"
BASE_SYSTEM_SERVICES="sshd cloud-init-local cloud-init-main cloud-config cloud-final"
BASE_INITRAMDISK_MODULES="virtio virtio_pci virtio_blk virtio_net virtio_ring"
SCRIPT_BASE_DIR="/usr/share/disk-image-scripts"
PACKAGE_LIST_FILE="addedpacks"
COMPRESS_IMAGE="Y"
TIMEZONE="UTC"
VALID_OS_TYPES="arch debian centos redhat rocky oracle ubuntu"
DEBMIRROR="http://deb.debian.org/debian/"
DEBDISTRO="stable"
# /Defaults #

BOLD="$(tput bold)"
NOCOLOR="$(tput sgr0)"

help_and_exit() {
  cat 1>&2 << EOF
gen_template_image.sh:

Generate an Cloud Template Image based on Arch Linux, using a profile


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
    
	==> TEMPLATE FILES:
		template.rc  - Index file with configuration and metadata. see
        man 5 template_rc for more information
	
		addedpacks   - List of system packages to install with pacman.
        This is in addition to packages listed in template.rc. one
        package per line, # is comment character. For large curated list
        of system packages.

        	init_image.sh - initialization script that runs with the 
        compile-template command on the output image. This is for anything that
        can't neatly be handled by a file or package,
        
		rootoverlay/ - Directory with a root overlay. This gets applied
        on top of base install. Will overwrite any file that exists.

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
  
  # Proccess defaults. If there is no CPU archecture set, then use whatever local machine is using
  [[ ${PROJECTARCH} == "any"  || -z ${PROJECTARCH} ]] && PROJECTARCH=$(uname -m)

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
  [[ -z ${KERNEL} || -z ${BOOTLOADER} || -z ${OSTYPE} ]] && return 1
  
  # check if OSTYPE= is supported
  [[ "${VALID_OS_TYPES}" = *${OSTYPE}* ]] || return 1
  
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
  [ "${PROJECTARCH}" == "any" ] && PROJECTARCH=$(uname -m) # if "Any" is used for archecture, use whatever the running kernel is compiled for
  [ -f ${PACKAGE_LIST_FILE} ] && packages_from_file=$( parse_package_file "${TARGET}/${PACKAGE_LIST_FILE}" )

  message "Performing Initial Install"

  # If install exists, delete it first
  [ -f "${TARGET}/${BASE_IMAGE}" ] && rm -f "${TARGET}/${BASE_IMAGE}"
  init_image.sh -s ${IMGSIZE} "${TARGET}/${BASE_IMAGE}" || exit_with_error 1 "Image initalization threw a code, quitting."

  mount_image.sh mount -m "${mount_point}" "${TARGET}/${BASE_IMAGE}" || exit_with_error 1 "Could not mount on ${mount_point}, quitting."
  mount_dev=$(grep "${mount_point}" /proc/mounts| cut -d " " -f 1)
  mount_target=${mount_dev: -3:1}

  case ${OSTYPE} in
   arch)
    # check if pacstrap is installed
    which pacstrap &> /dev/null || exit_with_error 2 "pacstrap is not installed, may not initialize Debian based environments"
    as_root pacstrap "${mount_point}" ${KERNEL} ${BOOTLOADER} ${ARCH_BASE_PACKAGES} ${EXTRAPACKAGES} ${packages_from_file} || exit_with_error 1 "Base Arch Linux install failed. Please check output."
    ;;
   debian|ubuntu)
    [ "${PROJECTARCH}" == "x86_64" ] && PROJECTARCH="amd64" # Arch uses x86_64, the same output as uname -m. Debian calls this amd64. Debian substitution for "any" to work.
    # check if debootstrap is installed
    which debootstrap &> /dev/null || exit_with_error 2 "debootstrap is not installed, may not initialize Debian based environments"
    # debootstrap needs a comma seperated list of packages
    local deb_packages=$( tr ' ' ',' <<< " ${KERNEL} ${BOOTLOADER} ${DEB_BASE_PACKAGES} ${EXTRAPACKAGES} ${packages_from_file}" )    
    as_root debootstrap --arch=${PROJECTARCH} --include="${deb_packages}" "${DEBDISTRO}" "${mount_point}" "${DEBMIRROR}" || warn "Debian base install threw a code, however there is a known bug(878961). We implement a workarounnd" #|| exit_with_error 1 "Base Debian install failed. Please check output."
    # work around for debootstrap not being able to handle virtualpackages
    # Bug: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=878961
    as_root arch-chroot "${mount_point}" apt -y --fix-broken install || exit_with_error 1 "Workaround for bug 878961 failed"
    ;;
   redhat|centos|rocky|oracle)
     #TODO: Write Redhat support
     exit_with_error 10 "Redhat support is incomplete, will not run"
     # Here be dragons
     which yum &> /dev/null || exit_with_error 2 "yum is not installed, may not initialize Red Hat based environments"
     # May or may not have to use --config= and/or --releasever
     dnf --installroot="${mount_point}" --assumeyes groupinstall ${REDHAT_BASE_GROUPS}
     dnf --installroot="${mount_point}" --assumeyes install ${KERNEL} ${BOOTLOADER} ${REDHAT_BASE_PACKAGES} ${packages_from_file}
    ;;
   *)
    exit_with_error 2 "Unsupported OS type: ${OSTYPE}"
  esac
  mount_image.sh umount ${mount_target} || warn "Unmount failed, please check"
  rmdir "${mount_point}"
}

_update_image(){
  # Patch the base install, using pacman.
  case ${OSTYPE} in
   arch)
    _image_shell "pacman -Syu"
    ;;
   debian|ubuntu)
   # Nasty kludge that we can't get both to run in the same choort.
    _image_shell "apt update" "apt upgrade"
    ;;
   redhat|centos|rocky|oracle)
    _image_shell "yum update"
    ;;
   *)
    exit_with_error 2 "Unsupported OS type: ${OSTYPE}"
    ;;
  esac
}

_image_shell(){
  # open a shell in a chroot in the installed image. Optionally run
  # command in said shell.
  local mount_point="$(mktemp -d)"
  local mount_dev=""
  local mount_target=""
  local commands=""
  [ ! -z "${1}" ] && commands=("${@}")
  [ ! -f "${TARGET}/${BASE_IMAGE}" ] && exit_with_error 1 "Base install cannot be found. perhaps you forgot to init-image?"
  
  # Set up mount and get unmount data
  mount_image.sh mount -m "${mount_point}" "${TARGET}/${BASE_IMAGE}" || exit_with_error 1 "Could not mount on ${mount_point}, quitting."
  mount_dev=$(grep "${mount_point}" /proc/mounts| cut -d " " -f 1)
  mount_target=${mount_dev: -3:1}

  # Run command
  # Don't let the name fool you, arch-chroot also works on debian
  if [ -z "${commands}" ];then
    message "Opening shell in base install"
    as_root arch-chroot "${mount_point}" || warn "Shell failed!"
   else
    message "Running \"${commands[@]}\" in base install"
    for cmd in "${commands[@]}";do
      as_root arch-chroot "${mount_point}" "${cmd}"
    done
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
    # Add OS archecture. If Any or none is specified, get it from running kernel
    [ ${PROJECTARCH} == "any" -o ${PROJECTARCH} == "" ] && PROJECTARCH=$(uname -m)
    outfile_name+="${PROJECTARCH}_"
    # Project Version
    if [[ ! -z ${PROJECTVER} && ${PROJECTVER} != "0" ]];then
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

  ## Generate final init.local
  touch "${TARGET}/init.conf" || exit_with_error 1 "Could not write to target, please check permissions."
  cat > "${TARGET}/init.conf" << EOF
OSTYPE=${OSTYPE}
KERNEL="${KERNEL}"
BOOTLOADER="${BOOTLOADER}"
SYSTEMSERVICES="${BASE_SYSTEM_SERVICES} ${SYSTEMSERVICES}"
EXTRAPACKAGES="${EXTRAPACKAGES}"
EXTRAINTMODULES="${BASE_INITRAMDISK_MODULES} ${EXTRAINITMODULES}"
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

  # copy root overlay and image init scripts
  submsg "Copying Overlay..."
  if [ -d "${TARGET}/rootoverlay/" ];then
    as_root cp -r "${TARGET}"/rootoverlay/* "${mount_point}/" || warn "Could not copy root overlay. If rootoverlay/ is empty you can ignore this."
  fi
  if [ -f "${SCRIPT_BASE_DIR}/init.${OSTYPE}.sh" ];then
    as_root cp "${SCRIPT_BASE_DIR}/init.${OSTYPE}.sh" "${mount_point}" || warn "Could not copy initialization script to chroot!"
   else
    mount_image.sh umount ${mount_target} || warn "Unmount failed, please check"
    exit_with_error 1 "No initialization script for your OS Type: ${OSTYPE}. Image will not work"
  fi
  as_root cp "${TARGET}/init.conf" "${mount_point}" || warn 1 "Could not copy initialization config to chroot!"
  if [ -f "${TARGET}/init.local.sh" ];then
    as_root cp "${TARGET}/init.local.sh" "${mount_point}" || warn "Could not copy local initializtion script to chroot!"
  fi
  
  # OS Specific file copy
  case ${OSTYPE} in
   debian|ubuntu)
    as_root install -Dm 644 "${SCRIPT_BASE_DIR}/debian-syslinux.cfg" "${mount_point}/root/syslinux.cfg"
    ;;
   redhat|centos|rocky|oracle)
    warn "No RH specific code, yet..."
    ;;
  esac
  
  # initialize with script
  submsg "Running Initalization Script..."
  as_root arch-chroot "${mount_point}" "bash /init.${OSTYPE}.sh" || warn "Initialization failed!"
  
  # Cleanup
  submsg "Cleanup"
  as_root rm -f "${mount_point}/init.${OSTYPE}.sh"
  as_root rm -f "${mount_point}/init.conf"
  as_root rm -f "${mount_point}/init.${OSTYPE}.local.sh"
  mount_image.sh umount ${mount_target} || warn "Unmount failed, please check"
  rmdir "${mount_point}" || warn "Could not delete temporary mountpoint directory"
  rm -f "${TARGET}/init.conf"


  # Shrinkwrap
  submsg "Shrinkwrapping..."
  shrinkwrap_image.sh "${TARGET}/${outfile_name}" || warn "Shrinkwrap threw a code"
      
  submsg "Re-Initializing Bootloader"
  mount_point="$(mktemp -d)"
  mount_image.sh mount -m "${mount_point}" "${TARGET}/${outfile_name}" || exit_with_error 1 "Could not mount on ${mount_point}, quitting."
  mount_dev=$(grep "${mount_point}" /proc/mounts| cut -d " " -f 1)
  mount_target=${mount_dev: -3:1}
  
  #This is very kludgy. syslinux is the name of the package in Arch, extlinux in Debian, they are the same thing.
  # syslinux-install_update is an Arch specific script. Unknown how this will work with redhat and/or grub
  case ${BOOTLOADER} in
   *syslinux*)
    as_root arch-chroot "${mount_point}" "syslinux-install_update -u -a -m" || warn "syslinux re-initialization failed"
    ;;
   *extlinux*)
    as_root arch-chroot "${mount_point}" "extlinux -U /boot/syslinux" || warn "extlinux re-initialization failed"
    ;;
   *)
    warn "Bootloader unsupported, skipping.."
    ;;
  esac

  #Cleanup again
  mount_image.sh umount ${mount_target} || warn "Unmount failed, please check"
  rmdir "${mount_point}" || warn "Could not delete temporary mountpoint directory"

  # compressing final image
  if [ "${COMPRESSIMAGE}"  == "Y" ];then
    submsg "Compressing Image"
    gzip -f ${COMPRESSOPTS} "${TARGET}/${outfile_name}"
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
    is_template "${TARGET}" || exit_with_error 2 "${TARGET} is not a valid profile, quitting"
    parse_environment "${TARGET}/${TEMPLATE_INDEX}" || exit_with_error 1 "Could not parse ${TEMPLATE_INDEX}, fail"
    _init_image
    ;;
   update-image)
    is_template "${TARGET}" || exit_with_error 2 "${TARGET} is not a valid profile, quitting"
    parse_environment "${TARGET}/${TEMPLATE_INDEX}" || exit_with_error 1 "Could not parse ${TEMPLATE_INDEX}, fail"
    _update_image
    ;;
   image-shell)
    is_template "${TARGET}" || exit_with_error 2 "${TARGET} is not a valid profile, quitting"
    parse_environment "${TARGET}/${TEMPLATE_INDEX}" || exit_with_error 1 "Could not parse ${TEMPLATE_INDEX}, fail"
    _image_shell "${@:3}"
    ;;
   compile-template)
    is_template "${TARGET}" || exit_with_error 2 "${TARGET} is not a valid profile, quitting"
    parse_environment "${TARGET}/${TEMPLATE_INDEX}" || exit_with_error 1 "Could not parse ${TEMPLATE_INDEX}, fail"
    _compile_template
    ;;
   *)
    help_and_exit
    ;;
  esac

  exit 0
}

main "${@}"

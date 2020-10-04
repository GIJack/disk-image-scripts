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
# /Defaults #

help_and_exit() {
  cat 1>&2 << EOF
gen_template_image.sh:

Generate an Cloud Template Image.(Based on Arch Linux), based on a
profile. Needs cloud-init-extra package from AUR available in a custom repo.


	USAGE:
	gen_template_image.sh [command] <arguments>

	COMMANDS:

	init-template		Generate blank profile. rootoverlay/ directory
				and default template.rc. If no argument is
				given, \$PWD is used. Otherwise argument is
				directory path.
				
	init-base-image		Generate a base install of Arch in an image in
				a file named 'base-arch.img'. Takes an optional
				argument, a directory path. If none is specified
				then \$PWD is used. This image needs to be in
				profile path
				
	update-base-image	Runs pacman -Syu in chroot on base-image.
	
	
	
	compile-template	Generates usable Cloud VM Template based on
				metadata, overlay. Filename will be based on
				metadata from template.rc

	PROFILE:
	Set directory and file structure with metadata and a root overlay
	applied over a base install of Arch Linux.
    
	==> FILES:
	    template.rc  - file with metadata
	
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

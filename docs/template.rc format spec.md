template.rc file SPECIFICATION
==============================

VERSION: 0.x - provisional/experimental

This specification will describe template.rc as used by gen_template_image.rc
This information shall also be accessible in man 5 template_rc

template.rc is the metadata file for gen_template_image.sh. This is what
describes the template image that will be generated. There are two sections:
System metadata, used for keeping track of the project and as a label, and
system, which overrides /etc/cloud/init.arch.local is used in the generation
of the template.

There is also a magic number at the start of the file to identify this as its
own file type.


MAGIC NUMBER
------------
The first bytes 17 bytes of this type of file will be:
```
#@TEMPLATEPROFILE
```

FORMAT
------
The format of this file uses key=value pairs for data, with all the KEYS in
UPPERCASE. the comment character is #, of which all data is discarded afterwards
on the line. All text variables shall be quoted with either single\' or double
\" quotes. Numerical values shall all be intergers, and unquoted. formatting
shall otherwise be compatible with variables for GNU Bash.

METADATA
--------
The following keys are recognized as metadata:

OSTYPE			Name of Linux Distro. For use with cloud-init, and must
			use same format. As of now only "arch" is supported

FILEFORMAT		Interger with what version of this spec this is using.
			Relevant to OSTYPE.
Ver	Description
0	pre-release experimental

COMPRESS_IMAGE		Boolean. If we want to compress final output with gzip.
			"Y" compresses, everything else is a no.
			
COMPRESS_OPTS		Command line parameters to pass to gzip for use with
			COMPRESS_IMAGE. defaults to none

--> PROJECT

PROJECT_NAME		Your name for whatever this template is. the script will
			reduce this to PROJECT_SLUG in code, as a alphanumeric
			all lowercased version.

PROJECT_VERSION		Interger revision number of this project. If 0 is
			specified it will be ignored.

PROJECT_ARCH		CPU archecture of the project. What arch is needed to
			build the project from upstream Arch Linux. "any" will
			build with whatever the current system uses.

PROJECT_DESCRIPTION	Longwinded description of what this project is, what
			its used for, circumstances for its creation, or
			whatever other descriptive information about the project
			(OPTIONAL)

--> AUTHOR (OPTIONAL)

AUTHOR_NAME		Name/handle/nick/alias of the person who wrote this.

AUTHOR_EMAIL		Email address of the author.

AUTHOR_GPG_SIG		Signature of Author's GPG key. For used in contacting
			author. If you specify a key here, then AUTHOR_EMAIL
			needs to be filled in, and name on the key needs to
			match.
			
AUTHOR_CONTACT		Additional contact information for the author. This is a
			space seperated list of PROTOCOL:ADDRESS formatted
			ways to contact the author. For communication methods
			that are instanced or have seperate name spaces such as
			IRC. Three fields with PROTOCOL:INSTANCE:ADDRESS shall
			be used. For protocols that have INSTANCES built into
			the address use PROTOCOL:ADDRESS instead.
			
			Example: for IRC use:
			```
			IRC:<NETWORK>:<IRC ADDRESS|NICKNAME>
			```

SYSTEM
------
The following keys are used to describe and control system behavior and
configuration:

IMGSIZE			Size in Megabytes of initial system install. This needs
			to be big enough to accomidate base system install.
			However, the final image will be shrunk to smallest size
			before export.

FILESYSTEM		For future compatibility. Only EXT4 is supported and
			only EXT4 will be used

KERNEL			Name of Arch kernel package. Assumes linux based kernel
			with standard naming conventions with filenames. Kernel
			needs to be in system repos and pullable with pacman.

BOOTLOADER		What bootloader to use. Should be name of Arch package
			in repo. So far, only syslinux is supported. grub
			support might be in the future.

SYSTEMSERVICES		Space seperated list of systemd services to enable

EXTRAPACKAGES		These packages will be installed on top of the base
			install. There is no need to specify kernel or
			bootloader, as these are already installed. It is
			recommended to add a text editor here as one is NOT
			in the default install
		

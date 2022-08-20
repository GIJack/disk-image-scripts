#!/usr/bin/bash
# User initialization script. These commands run in the chroot as it gets
# compiled.

message() {
  echo "Cloud Image Init: ${@}"
}
submsg(){
  echo "[+]	${@}"
}
warn(){
  echo 1>&2 "Cloud Image Init: WARN: ${@}"
}

exit_with_error(){
  echo 1>&2 "Cloud Image Init: ERROR: ${2}"
  exit ${1}
}

main() {
  # code goes here
  message "Running user run-once code for intializing template"
  exit 0
}

main "${@}"

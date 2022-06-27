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


main() {
  # code goes here
  exit 0
}

main "${@}"

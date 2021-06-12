#!/usr/bin/bash

_mount_image_completion() {
  local cur prev
  local output=""
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}

  case ${COMP_CWORD} in
    1)
      COMPREPLY=( $(compgen -W "mount umount list" -- ${cur}) )
      ;;
    2)
      case ${prev} in
        mount)
          output=($(ls *))
          COMPREPLY=($(compgen -W "${output[*]}" -- ${cur}))
          ;;
        umount)
          COMPREPLY=($(compgen -W "N" -- ${cur} ))
          ;;
      esac
      ;;
    *)
      COMPREPLY=()
      ;;
  esac

}

complete -F _mount_image_completion mount_image.sh


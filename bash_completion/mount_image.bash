#!/usr/bin/bash

_list_parts(){
  mount_image.sh list | sed "1d" | cut -d " " -f 1
}
_mount_image_completion() {
  local cur prev output umount_list
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
          umount_list="$(_list_parts)"
          COMPREPLY=($(compgen -W "${umount_list}" -- ${cur} ))
          ;;
      esac
      ;;
    *)
      COMPREPLY=()
      ;;
  esac

}

complete -F _mount_image_completion mount_image.sh


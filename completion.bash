#!/bin/bash

_t2c_complete() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    commands="init build1 build1_watch build2 build2_watch"

    COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )

    return 0
}

complete -F _t2c_complete t2c

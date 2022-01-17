#!/usr/bin/env bash
# shellcheck shell=bash

set -e
set -o errtrace

function usage() {
    cat <<-EOF >&2
usage: $(basename "$0") [-h] [shell-command] [-- argument-list]
               [-S socket-path] [-T features] [command [flags]]

Examples:
               $(basename "$0") ssh -- server1 server2
               $(basename "$0") docker exec -it %s sh -- container1 container2
EOF
}

function build_run_cmd() {
    local base_cmd=${1}
    local arg=${2}
    # shellcheck disable=SC2059
    [[ $base_cmd =~ %[\n]*s ]] && printf "$base_cmd" "$arg" || echo "$base_cmd$arg"
}

function build_tmux_cmd() {
    local tmux_cmd=$'tmux new-session \\; \\\n'
    local run_cmd=""
    local argc=1

    while local argv=$1 && shift; do
        argc=$(($# > 1 ? $# : 1))
        case "$argv" in
        -h | --help)
            usage
            exit 1
            ;;
        --)
            break
            ;;
        esac
        run_cmd+="$argv "
    done

    if [[ $argc -ge 2 ]]; then
        for _ in $(seq 2 $argc); do
            tmux_cmd+=$'  split-window -h \\; \\\n'
        done
        tmux_cmd+=$'  select-layout tiled \\; \\\n'
    fi

    for paneid in $(seq 1 $argc); do
        tmux_cmd+="  select-pane -t $paneid \\; send-keys '$(build_run_cmd "$run_cmd" "${!paneid}")' C-m \\; \\"$'\n'
    done
    tmux_cmd+=$'  select-pane -t 1 \\; \\\n  setw synchronize-panes on \\;'
    echo "$tmux_cmd"
}

function main() {
    local tmux_cmd=""

    if [ "$#" -eq 0 ]; then
        usage
        exit
    fi

    tmux_cmd="$(build_tmux_cmd "$@")"

    [[ "${DEBUG:-0}" -ne 0 ]] && echo "$(tput setaf 3)$tmux_cmd$(tput sgr0)" >&2

    eval "$tmux_cmd"
}

main "$@"

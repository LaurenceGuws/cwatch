#!/usr/bin/env bash
set -euo pipefail

profiles=(mk-1 mk-2 mk-3)

usage() {
  printf 'Usage: %s {up|down|rm}\n' "$0" >&2
}

run_all() {
  local action=$1
  local profile

  for profile in "${profiles[@]}"; do
    case "$action" in
      up)
        minikube start -p "$profile"
        ;;
      down)
        minikube stop -p "$profile"
        ;;
      rm)
        minikube delete -p "$profile"
        ;;
    esac
  done
}

case "${1-}" in
  up|down|rm)
    run_all "$1"
    ;;
  *)
    usage
    exit 1
    ;;
esac

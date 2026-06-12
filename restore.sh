#!/bin/bash
#
# Restores the ~/.vds directory from a tar archive file
# located in the script's working directory.

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/lib.sh"

readonly VDS_DIR="${HOME}/.vds"

usage() {
  err "Usage: $0 <backup.tar>"
  exit 1
}

restore_vds() {
  local archive="$1"

  if [[ ! -f "${archive}" ]]; then
    err "Error: archive not found: ${archive}"
    return 1
  fi

  if [[ -d "${VDS_DIR}" ]]; then
    warn "Existing ${VDS_DIR} will be replaced."
    rm -rf "${VDS_DIR}"
  fi

  tar xf "${archive}" -C "${HOME}"

  info "Restore complete: ${VDS_DIR}"
}

main() {
  if [[ $# -ne 1 ]]; then
    usage
  fi

  local archive="$1"
  info "Starting restore from ${archive}..."
  restore_vds "${archive}"
}

main "$@"

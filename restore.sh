#!/bin/bash
#
# Restores the ~/.vds directory from a zip archive file
# located in the script's working directory.

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/lib.sh"

readonly VDS_DIR="$HOME/.vds"

usage() {
  err "Usage: $0 <backup.zip>"
  exit 1
}

restore_vds() {
  local archive="$1"

  if [[ ! -f "${archive}" ]]; then
    err "Error: archive not found: ${archive}"
    return 1
  fi

  local tmpdir
  tmpdir="$(mktemp -d /tmp/vds-restore-XXXXXX)"

  unzip -q "${archive}" -d "${tmpdir}" || {
    err "Failed to extract archive."
    rm -rf "${tmpdir}"
    return 1
  }

  if [[ -d "${VDS_DIR}" ]]; then
    warn "Existing ${VDS_DIR} will be replaced."
    rm -rf "${VDS_DIR}"
  fi

  mv "${tmpdir}/.vds" "${VDS_DIR}"
  rm -rf "${tmpdir}"

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

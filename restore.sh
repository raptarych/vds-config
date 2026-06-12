#!/bin/bash
#
# Restores the ~/.vds directory by downloading a tar archive
# from the given URL and extracting it.

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/lib.sh"

readonly VDS_DIR="${HOME}/.vds"

usage() {
  err "Usage: $0 <url>"
  exit 1
}

restore_vds() {
  local url="$1"
  local tmpfile
  tmpfile="$(mktemp /tmp/vds-restore-XXXXXX.tar)"

  info "Downloading archive..."
  curl -sSf --connect-timeout 10 --max-time 300 -o "${tmpfile}" "${url}" || {
    err "Download failed."
    rm -f "${tmpfile}"
    return 1
  }

  if [[ ! -s "${tmpfile}" ]]; then
    err "Downloaded file is empty."
    rm -f "${tmpfile}"
    return 1
  fi

  if [[ -d "${VDS_DIR}" ]]; then
    warn "Existing ${VDS_DIR} will be replaced."
    rm -rf "${VDS_DIR}"
  fi

  tar xf "${tmpfile}" -C "${HOME}"
  rm -f "${tmpfile}"

  info "Restore complete: ${VDS_DIR}"
}

main() {
  if [[ $# -ne 1 ]]; then
    usage
  fi

  local url="$1"
  info "Starting restore from ${url}..."
  restore_vds "${url}"
}

main "$@"

#!/bin/bash
#
# Backs up the ~/.vds directory to a zip archive and uploads it
# to tmpfiles.org, printing the download URL to stdout.

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/lib.sh"

readonly VDS_DIR="$HOME/.vds"
readonly UPLOAD_URL='https://tmpfiles.org/api/v1/upload'
readonly EXPIRE_SECONDS=7200

backup_vds() {
  local tmpfile
  tmpfile="$(mktemp /tmp/vds-backup-XXXXXX.zip)"

  if [[ ! -d "${VDS_DIR}" ]]; then
    err "Error: ${VDS_DIR} does not exist."
    return 1
  fi

  zip -r -q "${tmpfile}" "${VDS_DIR}" >/dev/null
  info "Backup created: ${tmpfile}"

  local response
  response="$(curl -s -F "file=@${tmpfile}" \
       -F "expire=${EXPIRE_SECONDS}" \
       "${UPLOAD_URL}")" || {
    err "Upload failed."
    rm -f "${tmpfile}"
    return 1
  }

  rm -f "${tmpfile}"

  local url
  url="$(printf '%s' "${response}" | jq -r '.data.url')"

  if [[ -z "${url}" || "${url}" == "null" ]]; then
    err "Failed to parse upload response: ${response}"
    return 1
  fi

  printf '%s\n' "${url}"
}

main() {
  info "Starting backup of ${VDS_DIR}..."
  local url
  url="$(backup_vds)"
  info "Backup available at:"
  printf '%s\n' "${url}"
}

main "$@"

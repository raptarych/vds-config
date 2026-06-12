#!/bin/bash
#
# Backs up the ~/.vds directory to a zip archive and uploads it
# to tmpfiles.org, printing the download URL to stdout.

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/lib.sh"

readonly VDS_DIR="${HOME}/.vds"
readonly UPLOAD_URL='https://tmpfiles.org/api/v1/upload'
readonly EXPIRE_SECONDS=7200

ensure_dependencies() {
  if ! command -v zip >/dev/null 2>&1; then
    warn "zip not found, installing..."
    sudo apt-get update -qq && sudo apt-get install -y -qq zip
  fi
}

backup_vds() {
  local tmpdir
  tmpdir="$(mktemp -d /tmp/vds-backup-XXXXXX)"

  if [[ ! -d "${VDS_DIR}" ]]; then
    err "Error: ${VDS_DIR} does not exist."
    return 1
  fi

  tar cf "${tmpdir}/vds.tar" -C "${HOME}" .vds
  (cd "${tmpdir}" && zip -q "vds-backup.zip" vds.tar)
  local tmpfile="${tmpdir}/vds-backup.zip"
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
  ensure_dependencies
  info "Starting backup of ${VDS_DIR}..."
  local url
  url="$(backup_vds)"
  printf '%s\n' "${url}"
}

main "$@"

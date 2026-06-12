#!/bin/bash
#
# Backs up the ~/.vds directory to a tar archive and serves it
# via a temporary nginx docker container.

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/lib.sh"

readonly VDS_DIR="${HOME}/.vds"
readonly SERV_PORT=9876
readonly SERV_CONTAINER="vds-backup-server"

cleanup() {
  rm -rf "${backup_tmpdir:-}"
}
trap cleanup EXIT

backup_vds() {
  if [[ ! -d "${VDS_DIR}" ]]; then
    err "Error: ${VDS_DIR} does not exist."
    return 1
  fi

  local backup_tmpdir
  backup_tmpdir="$(mktemp -d /tmp/vds-backup-XXXXXX)"
  local tarfile="${backup_tmpdir}/vds-backup.tar"

  tar cf "${tarfile}" -C "${HOME}" .vds
  info "Backup created: ${tarfile}"

  docker rm -f "${SERV_CONTAINER}" >/dev/null 2>&1 || true

  docker run -d \
    --name "${SERV_CONTAINER}" \
    -p "${SERV_PORT}:80" \
    -v "${backup_tmpdir}:/usr/share/nginx/html:ro" \
    --read-only \
    --tmpfs /var/cache/nginx:size=1M \
    --tmpfs /var/run:size=1M \
    --tmpfs /var/log/nginx:size=1M \
    nginx:alpine-slim

  local ext_ip
  ext_ip="$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 api.ipify.org 2>/dev/null)"

  if [[ -z "${ext_ip}" ]]; then
    err "Could not determine external IP."
    return 1
  fi

  (sleep 3600 && docker rm -f "${SERV_CONTAINER}" >/dev/null 2>&1) &
  disown

  local download_url="http://${ext_ip}:${SERV_PORT}/vds-backup.tar"
  printf '\n'
  info "Backup is being served at:"
  printf '%s\n' "${download_url}"
  printf '\n'
  warn "Container will be removed automatically in 1 hour."
  printf '\n'
  info "Use on target server:"
  printf '  bash restore.sh %s\n' "${download_url}"
}

main() {
  info "Starting backup of ${VDS_DIR}..."
  backup_vds
}

main "$@"

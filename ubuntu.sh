#!/bin/bash
#
# Ubuntu 24.04 VPS configuration script.
# Sets up Docker, WireGuard, and Telegram MTProto proxy.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

# Constants
readonly FAKE_DOMAIN='gosuslugi.ru'
PORT='484'
readonly CONFIG_DIR='/home/.vds'


#######################################
# Detect external IPv4 address.
# Outputs:
#   External IP address or exits on failure.
#######################################
get_external_ip() {
  local ip
  ip="$(curl -4 -s ifconfig.me)" || {
    err "Failed to detect external IP"
    exit 1
  }

  if [[ -z "${ip}" ]]; then
    err "Empty EXTERNAL_IP response"
    exit 1
  fi

  printf "%s" "${ip}"
}


#######################################
# Register Docker repository
#######################################
register_docker_repository() {
  if cat /etc/apt/sources.list.d/docker.sources &>/dev/null;  then
    return
  fi

  # Add Docker's official GPG key:
  sudo apt update
  sudo apt install ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources:
  sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  sudo apt update
}


#######################################
# Install Docker if not present.
#######################################
install_docker() {
  if command -v docker &>/dev/null; then
    warn "Docker already installed, skipping"
    return
  fi

  local docker_script
  docker_script="$(mktemp)"
  curl -fsSL https://get.docker.com -o "${docker_script}"
  sudo sh "${docker_script}"
  rm -f "${docker_script}"
}


#######################################
# Install Docker Compose standalone if not present.
#######################################
install_docker_compose() {
  if docker compose version &>/dev/null; then
    warn "Docker Compose already installed, skipping"
    return
  fi

  warn "Installing Docker Compose"
  register_docker_repository
  sudo apt install docker-compose-plugin
}


#######################################
# Create required directories.
#######################################
create_directories() {
  mkdir -p "${CONFIG_DIR}"
  mkdir -p "${CONFIG_DIR}/proxy-config"
  mkdir -p "${CONFIG_DIR}/wg-easy-15"
}


#######################################
# Generate Telegram proxy secret with Fake TLS.
# Globals:
#   FAKE_DOMAIN
# Outputs:
#   Generated secret string.
#######################################
generate_proxy_secret() {
  local domain_hex domain_len needed random_hex

  printf "Generating Fake TLS secret... " >&2

  domain_hex="$(printf "%s" "${FAKE_DOMAIN}" | xxd -ps | tr -d '\n')"
  printf "\n  Domain hex: %s\n" "${domain_hex}" >&2

  domain_len="${#domain_hex}"
  needed=$((30 - domain_len))
  random_hex="$(openssl rand -hex 15 | cut -c1-"${needed}")"

  local secret="ee${domain_hex}${random_hex}"

  printf "  Random part: %s\n" "${random_hex}" >&2
  printf "  Secret: ${YELLOW}%s${NC}\n" "${secret}" >&2
  printf "  Length: %s chars\n" "${#secret}" >&2
  printf "%s" "${secret}"
}


#######################################
# Check if port is free.
# Arguments:
#   Port number to check.
#######################################
check_port() {
  local port="$1"

  printf "Checking port %s... " "${port}"
  if ss -tuln | grep -q ":${port} "; then
    err "Port ${port} is already in use"
    exit 1
  fi
  info "OK"
}


#######################################
# Write .env file with current configuration.
# Arguments:
#   external_ip
#   tg_proxy_secret
#######################################
write_env() {
  local external_ip="$1"
  local tg_proxy_secret="$2"

  cat > .env <<EOF
EXTERNAL_IP="${external_ip}"
PORT="${PORT}"
TG_PROXY_SECRET="${tg_proxy_secret}"
EOF
}


#######################################
# Stop old containers.
#######################################
stop_old_containers() {
  sudo docker compose --env-file .env down --remove-orphans || true
}


#######################################
# Start containers and verify they are running.
#######################################
start_containers() {
  printf "Starting docker compose... "
  sudo docker compose --env-file .env up -d

  sleep 3

  if sudo docker compose ps --format json | grep -q "wg-easy" \
    && sudo docker compose ps --format json | grep -q "mtproto-proxy"; then
    info "OK"
    printf "%s\n" "Configuration saved to .env"
    printf "%s\n" ""
    printf "%s\n" "Container logs:"
    sudo docker compose logs --tail 5
  else
    err "Container startup failed"
    sudo docker compose logs --tail 5
    exit 1
  fi
}


#######################################
# Print summary with connection links.
# Arguments:
#   external_ip
#   tg_proxy_secret
#######################################
print_summary() {
  local external_ip="$1"
  local tg_proxy_secret="$2"
  local link="tg://proxy?server=${external_ip}&port=${PORT}&secret=${tg_proxy_secret}"
  local link_http="https://t.me/proxy?server=${external_ip}&port=${PORT}&secret=${tg_proxy_secret}"

  printf "%s\n" "========================"
  info "Script completed successfully!"
  printf "%s\n" ""
  printf "%s\n" "Telegram proxy link (IPv4):"
  info "${link}"
  info "${link_http}"
  printf "%s\n" ""
  printf "%s\n" "WireGuard panel:"
  info "http://${external_ip}:51821/"
  printf "%s\n" "========================"
}


main() {
  local external_ip
  external_ip="$(get_external_ip)"
  print_info "Detected external IP of VPS" "${external_ip}"

  install_docker
  install_docker_compose

  if [[ -f .env ]]; then
    warn "Found existing .env file"
    source .env
  fi

  printf "%s\n" "Setting up MTProto proxy with Fake TLS"
  printf "%s\n" "--------------------------------------"
  printf "Using domain for FakeTLS: ${BLUE}%s${NC}\n" "${FAKE_DOMAIN}"

  local tg_proxy_secret
  if [[ -z "${TG_PROXY_SECRET:-}" ]]; then
    tg_proxy_secret="$(generate_proxy_secret)"
  else
    tg_proxy_secret="${TG_PROXY_SECRET}"
  fi

  write_env "${external_ip}" "${tg_proxy_secret}"
  create_directories
  stop_old_containers
  check_port "${PORT}"
  start_containers
  print_summary "${external_ip}" "${tg_proxy_secret}"
}

main "$@"
